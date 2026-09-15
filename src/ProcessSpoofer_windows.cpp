#include "ProcessSpoofer.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QCoreApplication>
#include <QDebug>
#include <QTextStream>

#include <windows.h>

ProcessSpoofer::ProcessSpoofer(QObject *parent)
    : QObject(parent)
{
}

ProcessSpoofer::~ProcessSpoofer()
{
    stopAllSpoofing();
}

bool ProcessSpoofer::isSpoofing() const
{
    return m_isSpoofing;
}

QString ProcessSpoofer::currentProcessName() const
{
    return m_currentProcessName;
}

QStringList ProcessSpoofer::spoofedProcesses() const
{
    return m_spoofedProcesses.keys();
}

int ProcessSpoofer::spoofedCount() const
{
    return m_spoofedProcesses.size();
}

bool ProcessSpoofer::isSpoofingProcess(const QString &processName) const
{
    return m_spoofedProcesses.contains(processName);
}

// ---------------------------------------------------------------------------
//  Helpers
// ---------------------------------------------------------------------------

/// Sanitize a display name so it can be used as a Windows folder name.
static QString sanitizeFolderName(const QString &raw)
{
    QString s = raw;
    // Remove characters that are invalid in NTFS directory names
    for (QChar c : QStringLiteral("<>:\"/\\|?*"))
        s.remove(c);
    return s.trimmed();
}

/// Try to locate dummy.exe across multiple possible deployment and build paths.
static QString findDummySource()
{
    QString appDir = QCoreApplication::applicationDirPath();
    QStringList candidates = {
        appDir + "/dummy.exe",
        appDir + "/Release/dummy.exe",
        appDir + "/Debug/dummy.exe",
        appDir + "/../dummy.exe",
        appDir + "/../Release/dummy.exe"
    };

    for (const QString &path : candidates) {
        if (QFile::exists(path))
            return QDir::cleanPath(path);
    }
    return QString();
}

/// Try to delete a file with retry — Windows can briefly lock an exe after
/// process termination or during an antivirus scan.
static bool robustDelete(const QString &path, int attempts = 5, int delayMs = 100)
{
    std::wstring wpath = path.toStdWString();
    for (int i = 0; i < attempts; ++i) {
        if (DeleteFileW(wpath.c_str()))
            return true;
        if (!QFile::exists(path))
            return true;            // already gone
        Sleep(static_cast<DWORD>(delayMs));
    }
    return !QFile::exists(path);
}

// ---------------------------------------------------------------------------
//  Start
// ---------------------------------------------------------------------------

void ProcessSpoofer::startSpoofing(const QString &processName,
                                   const QString &gameName,
                                   const QString &steamAppId,
                                   const QString &gameId)
{
    // If already spoofing this specific process, do nothing
    if (m_spoofedProcesses.contains(processName)) {
        return;
    }

    if (processName.isEmpty()) {
        emit errorOccurred("Process name cannot be empty.");
        return;
    }

    // ── Locate bundled dummy.exe ──
    QString dummySrc = findDummySource();
    if (dummySrc.isEmpty()) {
        emit errorOccurred("Could not find 'dummy.exe' in application directory or build output.");
        return;
    }

    // ── Parse target executable name and relative directory ──
    // Discord detects games by matching relative paths (e.g. "_retail_/wow-64.exe",
    // "left 4 dead 2/left4dead2.exe", "path of exile/pathofexile_x64steam.exe").
    // We preserve the relative directory hierarchy and isolate games by gameId.
    QString normPath = processName;
    normPath.replace('\\', '/');
    while (normPath.startsWith('/'))
        normPath.remove(0, 1);

    if (!normPath.endsWith(".exe", Qt::CaseInsensitive))
        normPath += ".exe";

    QFileInfo fi(normPath);
    QString targetExe = fi.fileName();
    QString relativeSubDir = fi.path();
    if (relativeSubDir == ".")
        relativeSubDir.clear();

    QString appDir = QCoreApplication::applicationDirPath();
    QString gamesRoot = appDir + "/games";

    // Isolate by gameId (Discord Application ID), or fallback to sanitized game name
    QString gameFolder;
    if (!gameId.isEmpty()) {
        gameFolder = gamesRoot + "/" + sanitizeFolderName(gameId);
    } else if (!steamAppId.isEmpty()) {
        gameFolder = gamesRoot + "/" + sanitizeFolderName(steamAppId);
    } else {
        gameFolder = gamesRoot + "/" + sanitizeFolderName(
            gameName.isEmpty() ? fi.completeBaseName() : gameName);
    }

    QString exeDir = relativeSubDir.isEmpty() ? gameFolder : (gameFolder + "/" + relativeSubDir);

    if (!QDir().mkpath(exeDir)) {
        emit errorOccurred("Failed to create directory: " + exeDir);
        return;
    }

    QString tempBinaryPath = exeDir + "/" + targetExe;

    // ── Reusable binary check ──
    // Avoid re-copying or deleting if the dummy binary already exists with matching size.
    // This avoids Windows Defender / antivirus file locking errors on re-launch.
    bool needCopy = true;
    if (QFile::exists(tempBinaryPath)) {
        QFileInfo srcInfo(dummySrc);
        QFileInfo dstInfo(tempBinaryPath);
        if (dstInfo.size() == srcInfo.size() && dstInfo.size() > 0) {
            needCopy = false;
        } else {
            robustDelete(tempBinaryPath, 5, 100);
        }
    }

    if (needCopy) {
        if (!QFile::copy(dummySrc, tempBinaryPath)) {
            // Win32 CopyFileW fallback
            std::wstring wSrc = QDir::toNativeSeparators(dummySrc).toStdWString();
            std::wstring wDst = QDir::toNativeSeparators(tempBinaryPath).toStdWString();
            if (!CopyFileW(wSrc.c_str(), wDst.c_str(), FALSE)) {
                emit errorOccurred("Failed to copy dummy executable to " + tempBinaryPath
                                   + " (error " + QString::number(GetLastError()) + ")");
                return;
            }
        }
    }

    // ── Launch the renamed executable via CreateProcessW ──
    STARTUPINFOW si = {};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi = {};

    std::wstring wExe = QDir::toNativeSeparators(tempBinaryPath).toStdWString();
    std::wstring wDir = QDir::toNativeSeparators(exeDir).toStdWString();
    std::wstring wGameName = (gameName.isEmpty() ? QFileInfo(targetExe).completeBaseName() : gameName).toStdWString();

    // Pass --title "<Game Name>" so dummy.exe displays the game name in its window & tray
    std::wstring wCmd = L"\"" + wExe + L"\" --title \"" + wGameName + L"\"";

    std::vector<wchar_t> cmdBuf(wCmd.begin(), wCmd.end());
    cmdBuf.push_back(L'\0');

    BOOL ok = CreateProcessW(
        wExe.c_str(),       // lpApplicationName
        cmdBuf.data(),      // lpCommandLine  (mutable)
        nullptr, nullptr,   // security attrs
        FALSE,              // bInheritHandles
        0,                  // dwCreationFlags
        nullptr,            // lpEnvironment
        wDir.c_str(),       // lpCurrentDirectory
        &si, &pi
    );

    if (!ok) {
        DWORD err = GetLastError();
        emit errorOccurred(
            QString("Failed to start spoofed process (error %1).").arg(err));
        return;
    }

    CloseHandle(pi.hThread);

    // ── Store in map ──
    SpoofEntry entry;
    entry.processHandle = pi.hProcess;
    entry.processId = pi.dwProcessId;
    entry.tempBinaryPath = tempBinaryPath;
    entry.exeDir = exeDir;
    entry.gameFolder = gameFolder;
    m_spoofedProcesses.insert(processName, entry);

    // Keep legacy fields in sync (point to last started)
    m_processHandle = pi.hProcess;
    m_tempBinaryPath = tempBinaryPath;

    refreshSpoofingState();

    qDebug() << "[Orby] Spawned dummy as:" << targetExe
             << "PID:" << pi.dwProcessId
             << "Game:" << gameName
             << "(total active:" << m_spoofedProcesses.size() << ")";
}

// ---------------------------------------------------------------------------
//  Kill & Clean a single entry
// ---------------------------------------------------------------------------

void ProcessSpoofer::killAndCleanEntry(SpoofEntry &entry)
{
    // ── Terminate the dummy process ──
    if (entry.processHandle != nullptr && entry.processHandle != INVALID_HANDLE_VALUE) {
        TerminateProcess(entry.processHandle, 0);
        WaitForSingleObject(entry.processHandle, 1500);
        CloseHandle(entry.processHandle);
        entry.processHandle = nullptr;
    }

    // Fallback termination by PID
    if (entry.processId > 0) {
        HANDLE hProc = OpenProcess(PROCESS_TERMINATE, FALSE, entry.processId);
        if (hProc) {
            TerminateProcess(hProc, 0);
            WaitForSingleObject(hProc, 500);
            CloseHandle(hProc);
        }
        entry.processId = 0;
    }

    // ── Clean up temporary binary if unlocked ──
    if (!entry.tempBinaryPath.isEmpty()) {
        robustDelete(entry.tempBinaryPath, 3, 50);

        // Remove empty parent directories up to (not including) games/
        QString gamesRoot = QCoreApplication::applicationDirPath() + "/games";
        QDir dir = QFileInfo(entry.tempBinaryPath).dir();
        while (dir.absolutePath() != gamesRoot
               && dir.absolutePath().startsWith(gamesRoot)) {
            QString p = dir.absolutePath();
            if (!QDir().rmdir(p))    // only removes if empty
                break;
            dir.cdUp();
        }

        entry.tempBinaryPath.clear();
    }
}

// ---------------------------------------------------------------------------
//  Refresh spoofing state after changes
// ---------------------------------------------------------------------------

void ProcessSpoofer::refreshSpoofingState()
{
    bool wasSpoofing = m_isSpoofing;
    QString oldName = m_currentProcessName;

    m_isSpoofing = !m_spoofedProcesses.isEmpty();

    if (m_spoofedProcesses.isEmpty()) {
        m_currentProcessName.clear();
        m_processHandle = nullptr;
        m_tempBinaryPath.clear();
        m_manifestPath.clear();
    } else {
        QStringList names = m_spoofedProcesses.keys();
        if (names.size() == 1) {
            m_currentProcessName = names.first();
        } else {
            m_currentProcessName =
                QString("%1 games active").arg(names.size());
        }
    }

    if (m_isSpoofing != wasSpoofing)
        emit isSpoofingChanged();
    if (m_currentProcessName != oldName)
        emit currentProcessNameChanged();
    emit spoofedProcessesChanged();
}

// ---------------------------------------------------------------------------
//  Stop a single process by name
// ---------------------------------------------------------------------------

void ProcessSpoofer::stopSpoofingProcess(const QString &processName)
{
    if (!m_spoofedProcesses.contains(processName))
        return;

    SpoofEntry entry = m_spoofedProcesses.take(processName);
    killAndCleanEntry(entry);

    refreshSpoofingState();
}

// ---------------------------------------------------------------------------
//  Legacy stop — now stops all
// ---------------------------------------------------------------------------

void ProcessSpoofer::stopSpoofing()
{
    stopAllSpoofing();
}

// ---------------------------------------------------------------------------
//  Stop all processes
// ---------------------------------------------------------------------------

void ProcessSpoofer::stopAllSpoofing()
{
    if (m_stopping) return;
    m_stopping = true;

    QStringList keys = m_spoofedProcesses.keys();
    for (const QString &name : keys) {
        SpoofEntry entry = m_spoofedProcesses.take(name);
        killAndCleanEntry(entry);
    }

    refreshSpoofingState();
    m_stopping = false;
}
