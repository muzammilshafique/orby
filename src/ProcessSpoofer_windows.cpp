#include "ProcessSpoofer.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QCoreApplication>
#include <QDebug>

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

void ProcessSpoofer::startSpoofing(const QString &processName)
{
    if (m_isSpoofing) {
        stopSpoofing();
    }

    if (processName.isEmpty()) {
        emit errorOccurred("Process name cannot be empty.");
        return;
    }

    // Enforce .exe extension for Discord detection on Windows
    QString targetName = processName;
    if (!targetName.endsWith(".exe", Qt::CaseInsensitive)) {
        targetName += ".exe";
    }

    // Safety: strip any remaining path separators — we only want a filename
    targetName = QFileInfo(targetName).fileName();

    // Locate the compiled dummy.exe in the application directory
    QString dummySource = QCoreApplication::applicationDirPath() + "/dummy.exe";
    if (!QFile::exists(dummySource)) {
        emit errorOccurred("Could not find 'dummy.exe' in application directory.");
        return;
    }

    // Build the target path in a secure temp location
    QString tempDir = QDir::tempPath();
    m_tempBinaryPath = QDir(tempDir).filePath(targetName);

    // Remove any stale copy — retry with delays because Windows may still
    // hold a file lock briefly after process termination or antivirus scan.
    if (QFile::exists(m_tempBinaryPath)) {
        bool removed = false;
        std::wstring wpath = m_tempBinaryPath.toStdWString();
        for (int attempt = 0; attempt < 5; ++attempt) {
            if (DeleteFileW(wpath.c_str())) {
                removed = true;
                break;
            }
            Sleep(100);  // Wait for OS / AV to release the file
        }
        if (!removed && QFile::exists(m_tempBinaryPath)) {
            emit errorOccurred("Cannot remove stale file: " + m_tempBinaryPath
                               + " (error " + QString::number(GetLastError()) + ")."
                               + " An antivirus may be locking it.");
            return;
        }
    }

    // Copy the dummy to the temp location with the target game name
    if (!QFile::copy(dummySource, m_tempBinaryPath)) {
        emit errorOccurred("Failed to copy dummy executable to " + m_tempBinaryPath);
        return;
    }

    // Use Win32 CreateProcess directly instead of QProcess.
    // QProcess has issues launching GUI-subsystem (WinMain) executables
    // because it expects stdio channels that GUI apps don't provide,
    // causing waitForStarted() to timeout or the process to not launch.
    STARTUPINFOW si = {};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi = {};

    std::wstring exePath = m_tempBinaryPath.toStdWString();
    std::wstring workDir = tempDir.toStdWString();

    // CreateProcessW needs a mutable command-line buffer
    std::wstring cmdLine = L"\"" + exePath + L"\"";
    std::vector<wchar_t> cmdBuf(cmdLine.begin(), cmdLine.end());
    cmdBuf.push_back(L'\0');

    BOOL ok = CreateProcessW(
        exePath.c_str(),    // lpApplicationName — full path to the renamed dummy
        cmdBuf.data(),      // lpCommandLine
        nullptr,            // lpProcessAttributes
        nullptr,            // lpThreadAttributes
        FALSE,              // bInheritHandles
        0,                  // dwCreationFlags
        nullptr,            // lpEnvironment
        workDir.c_str(),    // lpCurrentDirectory
        &si,                // lpStartupInfo
        &pi                 // lpProcessInformation
    );

    if (!ok) {
        DWORD err = GetLastError();
        emit errorOccurred(QString("Failed to start spoofed process (error %1).").arg(err));
        QFile::remove(m_tempBinaryPath);
        m_tempBinaryPath.clear();
        return;
    }

    // Store the process handle for cleanup, close the thread handle immediately
    m_processHandle = pi.hProcess;
    CloseHandle(pi.hThread);

    m_isSpoofing = true;
    m_currentProcessName = processName;
    emit isSpoofingChanged();
    emit currentProcessNameChanged();

    qDebug() << "[Orby] Spawned dummy as:" << targetName
             << "PID:" << pi.dwProcessId;
}

void ProcessSpoofer::stopSpoofing()
{
    // Re-entrancy guard — prevents double-cleanup from signal + explicit call
    if (m_stopping) return;
    m_stopping = true;

    if (m_processHandle != nullptr && m_processHandle != INVALID_HANDLE_VALUE) {
        // Terminate the dummy process
        TerminateProcess(m_processHandle, 0);
        WaitForSingleObject(m_processHandle, 2000);
        CloseHandle(m_processHandle);
        m_processHandle = nullptr;

        // Give Windows time to fully release the file handle on the exe
        Sleep(150);

        qDebug() << "[Orby] Terminated dummy process.";
    }

    // Clean up the temporary binary with retry logic
    if (!m_tempBinaryPath.isEmpty()) {
        std::wstring wpath = m_tempBinaryPath.toStdWString();
        for (int attempt = 0; attempt < 5; ++attempt) {
            if (DeleteFileW(wpath.c_str()) || !QFile::exists(m_tempBinaryPath))
                break;
            Sleep(100);
        }
        m_tempBinaryPath.clear();
    }

    if (m_isSpoofing) {
        m_isSpoofing = false;
        m_currentProcessName.clear();
        emit isSpoofingChanged();
        emit currentProcessNameChanged();
    }

    m_stopping = false;
}
