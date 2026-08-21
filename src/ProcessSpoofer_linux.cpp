#include "ProcessSpoofer.h"

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

#include <cerrno>
#include <cstdio>
#include <cstring>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>

ProcessSpoofer::ProcessSpoofer(QObject *parent) : QObject(parent) {}

ProcessSpoofer::~ProcessSpoofer() { stopAllSpoofing(); }

bool ProcessSpoofer::isSpoofing() const { return m_isSpoofing; }

QString ProcessSpoofer::currentProcessName() const {
  return m_currentProcessName;
}

QStringList ProcessSpoofer::spoofedProcesses() const {
  return m_spoofedProcesses.keys();
}

int ProcessSpoofer::spoofedCount() const {
  return m_spoofedProcesses.size();
}

bool ProcessSpoofer::isSpoofingProcess(const QString &processName) const {
  return m_spoofedProcesses.contains(processName);
}

void ProcessSpoofer::startSpoofing(const QString &processName,
                                   const QString &gameName,
                                   const QString &steamAppId) {
  Q_UNUSED(gameName)
  Q_UNUSED(steamAppId)

  // If already spoofing this specific process, do nothing
  if (m_spoofedProcesses.contains(processName)) {
    return;
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
  QString tempBinaryPath = QDir(tempDir).filePath(processName);

  // Create parent subdirectories if processName contains path separators
  QFileInfo fileInfo(tempBinaryPath);
  QDir dir = fileInfo.dir();
  if (!dir.exists()) {
    dir.mkpath(".");
  }

  // Remove stale copy if any
  if (QFile::exists(tempBinaryPath)) {
    QFile::remove(tempBinaryPath);
  }

  // Copy sleep binary to temp path with the target game name
  if (!QFile::copy(sleepPath, tempBinaryPath)) {
    emit errorOccurred("Failed to copy executable to " + tempBinaryPath);
    return;
  }

  // Ensure it is executable
  QFile::setPermissions(tempBinaryPath,
                        QFileDevice::ReadOwner | QFileDevice::WriteOwner |
                            QFileDevice::ExeOwner | QFileDevice::ReadUser |
                            QFileDevice::ExeUser);

  // Fork a child that exec's the renamed binary.
  // Using raw fork+execl instead of QProcess to avoid pulling in QProcess
  // on Linux and to keep the child as lightweight as possible.
  QByteArray pathBytes = tempBinaryPath.toUtf8();

  pid_t pid = fork();

  if (pid < 0) {
    emit errorOccurred(QString("fork() failed: %1").arg(strerror(errno)));
    QFile::remove(tempBinaryPath);
    return;
  }

  if (pid == 0) {
    // ── Child process ──
    // exec the renamed sleep binary with a very long duration.
    // execl replaces this process image entirely, so /proc/<pid>/exe
    // will point to tempBinaryPath (the game-named binary).
    execl(pathBytes.constData(), pathBytes.constData(), "31536000", nullptr);

    // If execl returns, it failed
    _exit(1);
  }

  // ── Parent process ──
  SpoofEntry entry;
  entry.pid = pid;
  entry.tempBinaryPath = tempBinaryPath;
  m_spoofedProcesses.insert(processName, entry);

  // Keep legacy fields in sync (point to last started)
  m_childPid = pid;
  m_tempBinaryPath = tempBinaryPath;

  refreshSpoofingState();

  qDebug() << "[Orby] Spawned spoofed child PID:" << pid << "as"
           << processName
           << "(total active:" << m_spoofedProcesses.size() << ")";
}

void ProcessSpoofer::killAndCleanEntry(SpoofEntry &entry) {
  if (entry.pid > 0) {
    // Try graceful SIGTERM first
    if (kill(entry.pid, SIGTERM) == 0) {
      int status = 0;
      pid_t result = waitpid(entry.pid, &status, WNOHANG);

      if (result == 0) {
        // Child hasn't exited yet — give it 100ms then force kill
        usleep(100000);
        result = waitpid(entry.pid, &status, WNOHANG);

        if (result == 0) {
          kill(entry.pid, SIGKILL);
          waitpid(entry.pid, &status, 0); // Blocking reap
        }
      }
    }
    qDebug() << "[Orby] Terminated child PID:" << entry.pid;
    entry.pid = -1;
  }

  // Clean up the temporary binary
  if (!entry.tempBinaryPath.isEmpty() &&
      QFile::exists(entry.tempBinaryPath)) {
    QFile::remove(entry.tempBinaryPath);
    entry.tempBinaryPath.clear();
  }
}

void ProcessSpoofer::refreshSpoofingState() {
  bool wasSpoofing = m_isSpoofing;
  QString oldName = m_currentProcessName;

  m_isSpoofing = !m_spoofedProcesses.isEmpty();

  // currentProcessName shows the last-started process (or first in map)
  if (m_spoofedProcesses.isEmpty()) {
    m_currentProcessName.clear();
    m_childPid = -1;
    m_tempBinaryPath.clear();
  } else {
    // Show comma-separated list if multiple, otherwise just the name
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

void ProcessSpoofer::stopSpoofingProcess(const QString &processName) {
  if (!m_spoofedProcesses.contains(processName))
    return;

  SpoofEntry entry = m_spoofedProcesses.take(processName);
  killAndCleanEntry(entry);

  refreshSpoofingState();
}

void ProcessSpoofer::stopSpoofing() { stopAllSpoofing(); }

void ProcessSpoofer::stopAllSpoofing() {
  // Re-entrancy guard
  if (m_stopping)
    return;
  m_stopping = true;

  QStringList keys = m_spoofedProcesses.keys();
  for (const QString &name : keys) {
    SpoofEntry entry = m_spoofedProcesses.take(name);
    killAndCleanEntry(entry);
  }

  refreshSpoofingState();
  m_stopping = false;
}
