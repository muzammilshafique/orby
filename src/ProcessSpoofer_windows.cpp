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
                                   const QString &steamAppId)
{
    // If already spoofing this specific process, do nothing
    if (m_spoofedProcesses.contains(processName)) {
        return;
    }

    if (processName.isEmpty()) {
        emit errorOccurred("Process name cannot be empty.");
        return;
    }

    // ── Resolve target executable name ──
    QString targetExe = processName;
    if (!targetExe.endsWith(".exe", Qt::CaseInsensitive))
        targetExe += ".exe";
    targetExe = QFileInfo(targetExe).fileName();   // strip path separators

    // ── Locate bundled dummy.exe ──
    QString appDir  = QCoreApplication::applicationDirPath();
    QString dummySrc = appDir + "/dummy.exe";
    if (!QFile::exists(dummySrc)) {
        emit errorOccurred("Could not find 'dummy.exe' in application directory.");
        return;
    }

    // ── Build destination directory ──
    //  Steam game  → games/steamapps/common/<GameName>/<exe>
    //  Other       → games/<exe>
    QString gamesRoot = appDir + "/games";
    bool isSteam = !steamAppId.isEmpty();
    QString exeDir;

    if (isSteam) {
        QString safeName = sanitizeFolderName(
            gameName.isEmpty() ? QFileInfo(targetExe).completeBaseName() : gameName);
        exeDir = gamesRoot + "/steamapps/common/" + safeName;
    } else {
        exeDir = gamesRoot;
    }

    if (!QDir().mkpath(exeDir)) {
        emit errorOccurred("Failed to create directory: " + exeDir);
        return;
    }

    QString tempBinaryPath = exeDir + "/" + targetExe;

    // ── Remove stale copy ──
    if (QFile::exists(tempBinaryPath)) {
        if (!robustDelete(tempBinaryPath)) {
            emit errorOccurred("Cannot remove stale file: " + tempBinaryPath
                               + " (error " + QString::number(GetLastError()) + ")."
                               + " An antivirus may be locking it.");
            return;
        }
    }

    // ── Copy dummy → renamed game exe ──
    if (!QFile::copy(dummySrc, tempBinaryPath)) {
        emit errorOccurred("Failed to copy dummy executable to " + tempBinaryPath);
        return;
    }

    // ── Generate Steam ACF manifest (optional) ──
    QString manifestPath;
    if (isSteam) {
        QString safeName = sanitizeFolderName(
            gameName.isEmpty() ? QFileInfo(targetExe).completeBaseName() : gameName);
        manifestPath = gamesRoot + "/steamapps/appmanifest_" + steamAppId + ".acf";

        QFile acf(manifestPath);
        if (acf.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&acf);
            out << "\"AppState\"\n{\n"
                << "\t\"appid\"\t\t\"" << steamAppId << "\"\n"
                << "\t\"Universe\"\t\t\"1\"\n"
                << "\t\"name\"\t\t\"" << safeName << "\"\n"
                << "\t\"StateFlags\"\t\t\"4\"\n"
                << "\t\"installdir\"\t\t\"" << safeName << "\"\n"
                << "\t\"LastUpdated\"\t\t\"0\"\n"
                << "\t\"SizeOnDisk\"\t\t\"0\"\n"
                << "\t\"buildid\"\t\t\"0\"\n"
                << "}\n";
            acf.close();
            qDebug() << "[Orby] Generated ACF manifest:" << manifestPath;
        }
    }

    // ── Launch the renamed executable via CreateProcessW ──
    STARTUPINFOW si = {};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi = {};

    std::wstring wExe  = tempBinaryPath.toStdWString();
    std::wstring wDir  = QString(exeDir).toStdWString();
    std::wstring wGameName = gameName.toStdWString();

    // Pass the game name as the first argument so dummy.exe can use it as the window title
    std::wstring wCmd  = L"\"" + wExe + L"\" \"" + wGameName + L"\"";

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
        QFile::remove(tempBinaryPath);
        return;
    }

    CloseHandle(pi.hThread);

    // ── Store in map ──
    SpoofEntry entry;
    entry.processHandle = pi.hProcess;
    entry.tempBinaryPath = tempBinaryPath;
    entry.manifestPath = manifestPath;
    entry.exeDir = exeDir;
    m_spoofedProcesses.insert(processName, entry);

    // Keep legacy fields in sync (point to last started)
    m_processHandle = pi.hProcess;
    m_tempBinaryPath = tempBinaryPath;
    m_manifestPath = manifestPath;

    refreshSpoofingState();

    qDebug() << "[Orby] Spawned dummy as:" << targetExe
             << "PID:" << pi.dwProcessId
             << (isSteam ? "(Steam AppID: " + steamAppId + ")" : QString())
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
        WaitForSingleObject(entry.processHandle, 2000);
        CloseHandle(entry.processHandle);
        entry.processHandle = nullptr;

        // Give Windows time to fully release the file handle
        Sleep(150);
        qDebug() << "[Orby] Terminated dummy process.";
    }

    // ── Delete the renamed executable ──
    if (!entry.tempBinaryPath.isEmpty()) {
        robustDelete(entry.tempBinaryPath);

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

    // ── Delete the ACF manifest ──
    if (!entry.manifestPath.isEmpty()) {
        QFile::remove(entry.manifestPath);
        entry.manifestPath.clear();
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
