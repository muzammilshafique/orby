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
    stopSpoofing();
}

bool ProcessSpoofer::isSpoofing() const
{
    return m_isSpoofing;
}

QString ProcessSpoofer::currentProcessName() const
{
    return m_currentProcessName;
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
    if (m_isSpoofing) {
        stopSpoofing();
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

    m_tempBinaryPath = exeDir + "/" + targetExe;

    // ── Remove stale copy ──
    if (QFile::exists(m_tempBinaryPath)) {
        if (!robustDelete(m_tempBinaryPath)) {
            emit errorOccurred("Cannot remove stale file: " + m_tempBinaryPath
                               + " (error " + QString::number(GetLastError()) + ")."
                               + " An antivirus may be locking it.");
            return;
        }
    }

    // ── Copy dummy → renamed game exe ──
    if (!QFile::copy(dummySrc, m_tempBinaryPath)) {
        emit errorOccurred("Failed to copy dummy executable to " + m_tempBinaryPath);
        return;
    }

    // ── Generate Steam ACF manifest (optional) ──
    if (isSteam) {
        QString safeName = sanitizeFolderName(
            gameName.isEmpty() ? QFileInfo(targetExe).completeBaseName() : gameName);
        m_manifestPath = gamesRoot + "/steamapps/appmanifest_" + steamAppId + ".acf";

        QFile acf(m_manifestPath);
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
            qDebug() << "[Orby] Generated ACF manifest:" << m_manifestPath;
        }
    }

    // ── Launch the renamed executable via CreateProcessW ──
    // CreateProcessW is used instead of QProcess because QProcess relies
    // on stdio pipes that GUI-subsystem (WinMain) executables never create,
    // causing waitForStarted() to timeout.
    STARTUPINFOW si = {};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi = {};

    std::wstring wExe  = m_tempBinaryPath.toStdWString();
    std::wstring wDir  = QString(exeDir).toStdWString();
    std::wstring wCmd  = L"\"" + wExe + L"\"";

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
        QFile::remove(m_tempBinaryPath);
        m_tempBinaryPath.clear();
        return;
    }

    m_processHandle = pi.hProcess;
    CloseHandle(pi.hThread);

    m_isSpoofing = true;
    m_currentProcessName = processName;
    emit isSpoofingChanged();
    emit currentProcessNameChanged();

    qDebug() << "[Orby] Spawned dummy as:" << targetExe
             << "PID:" << pi.dwProcessId
             << (isSteam ? "(Steam AppID: " + steamAppId + ")" : QString());
}

// ---------------------------------------------------------------------------
//  Stop
// ---------------------------------------------------------------------------

void ProcessSpoofer::stopSpoofing()
{
    if (m_stopping) return;
    m_stopping = true;

    // ── Terminate the dummy process ──
    if (m_processHandle != nullptr && m_processHandle != INVALID_HANDLE_VALUE) {
        TerminateProcess(m_processHandle, 0);
        WaitForSingleObject(m_processHandle, 2000);
        CloseHandle(m_processHandle);
        m_processHandle = nullptr;

        // Give Windows time to fully release the file handle
        Sleep(150);
        qDebug() << "[Orby] Terminated dummy process.";
    }

    // ── Delete the renamed executable ──
    if (!m_tempBinaryPath.isEmpty()) {
        robustDelete(m_tempBinaryPath);

        // Remove empty parent directories up to (not including) games/
        QString gamesRoot = QCoreApplication::applicationDirPath() + "/games";
        QDir dir = QFileInfo(m_tempBinaryPath).dir();
        while (dir.absolutePath() != gamesRoot
               && dir.absolutePath().startsWith(gamesRoot)) {
            QString p = dir.absolutePath();
            if (!QDir().rmdir(p))    // only removes if empty
                break;
            dir.cdUp();
        }

        m_tempBinaryPath.clear();
    }

    // ── Delete the ACF manifest ──
    if (!m_manifestPath.isEmpty()) {
        QFile::remove(m_manifestPath);
        m_manifestPath.clear();
    }

    // ── Update state ──
    if (m_isSpoofing) {
        m_isSpoofing = false;
        m_currentProcessName.clear();
        emit isSpoofingChanged();
        emit currentProcessNameChanged();
    }

    m_stopping = false;
}
