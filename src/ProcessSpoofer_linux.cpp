#include "ProcessSpoofer.h"

#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QDebug>
#include <QFileInfo>

#include <unistd.h>
#include <signal.h>
#include <sys/wait.h>
#include <cerrno>
#include <cstring>
#include <cstdio>

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

    // Find the system sleep binary — small, universally available, does nothing
    QString sleepPath = QStandardPaths::findExecutable("sleep");
    if (sleepPath.isEmpty()) {
        emit errorOccurred("Could not find 'sleep' executable on system.");
        return;
    }

    // Build the target path in /tmp with the game's executable name.
    // Discord reads /proc/<pid>/exe to detect the running game,
    // so the filename on disk must match the expected executable name.
    QString tempDir = QDir::tempPath();
    m_tempBinaryPath = QDir(tempDir).filePath(processName);

    // Create parent subdirectories if processName contains path separators
    QFileInfo fileInfo(m_tempBinaryPath);
    QDir dir = fileInfo.dir();
    if (!dir.exists()) {
        dir.mkpath(".");
    }

    // Remove stale copy if any
    if (QFile::exists(m_tempBinaryPath)) {
        QFile::remove(m_tempBinaryPath);
    }

    // Copy sleep binary to temp path with the target game name
    if (!QFile::copy(sleepPath, m_tempBinaryPath)) {
        emit errorOccurred("Failed to copy executable to " + m_tempBinaryPath);
        return;
    }

    // Ensure it is executable
    QFile::setPermissions(m_tempBinaryPath,
        QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner |
        QFileDevice::ReadUser  | QFileDevice::ExeUser);

    // Fork a child that exec's the renamed binary.
    // Using raw fork+execl instead of QProcess to avoid pulling in QProcess
    // on Linux and to keep the child as lightweight as possible.
    QByteArray pathBytes = m_tempBinaryPath.toUtf8();

    pid_t pid = fork();

    if (pid < 0) {
        emit errorOccurred(QString("fork() failed: %1").arg(strerror(errno)));
        QFile::remove(m_tempBinaryPath);
        m_tempBinaryPath.clear();
        return;
    }

    if (pid == 0) {
        // ── Child process ──
        // exec the renamed sleep binary with a very long duration.
        // execl replaces this process image entirely, so /proc/<pid>/exe
        // will point to m_tempBinaryPath (the game-named binary).
        execl(pathBytes.constData(), pathBytes.constData(), "31536000", nullptr);

        // If execl returns, it failed
        _exit(1);
    }

    // ── Parent process ──
    m_childPid = pid;
    m_isSpoofing = true;
    m_currentProcessName = processName;
    emit isSpoofingChanged();
    emit currentProcessNameChanged();

    qDebug() << "[Orby] Spawned spoofed child PID:" << m_childPid
             << "as" << processName;
}

void ProcessSpoofer::stopSpoofing()
{
    // Re-entrancy guard
    if (m_stopping) return;
    m_stopping = true;

    if (m_childPid > 0) {
        // Try graceful SIGTERM first
        if (kill(m_childPid, SIGTERM) == 0) {
            int status = 0;
            pid_t result = waitpid(m_childPid, &status, WNOHANG);

            if (result == 0) {
                // Child hasn't exited yet — give it 100ms then force kill
                usleep(100000);
                result = waitpid(m_childPid, &status, WNOHANG);

                if (result == 0) {
                    kill(m_childPid, SIGKILL);
                    waitpid(m_childPid, &status, 0);  // Blocking reap
                }
            }
        }

        qDebug() << "[Orby] Terminated child PID:" << m_childPid;
        m_childPid = -1;
    }

    // Clean up the temporary binary
    if (!m_tempBinaryPath.isEmpty() && QFile::exists(m_tempBinaryPath)) {
        QFile::remove(m_tempBinaryPath);
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
