#include "ProcessSpoofer.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QCoreApplication>
#include <QDebug>

ProcessSpoofer::ProcessSpoofer(QObject *parent)
    : QObject(parent)
{
    // Auto-cleanup when the dummy process exits (crash, manual kill, etc.)
    connect(&m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int exitCode, QProcess::ExitStatus status) {
        Q_UNUSED(exitCode)
        Q_UNUSED(status)
        if (m_isSpoofing) {
            qDebug() << "[Orby] Dummy process exited, cleaning up.";
            stopSpoofing();
        }
    });
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

    // Locate the compiled dummy.exe in the application directory
    QString dummySource = QCoreApplication::applicationDirPath() + "/dummy.exe";
    if (!QFile::exists(dummySource)) {
        emit errorOccurred("Could not find 'dummy.exe' in application directory.");
        return;
    }

    // Build the target path in a secure temp location
    QString tempDir = QDir::tempPath();
    m_tempBinaryPath = QDir(tempDir).filePath(targetName);

    // Create parent directories if the target name contains path separators
    QFileInfo fileInfo(m_tempBinaryPath);
    QDir dir = fileInfo.dir();
    if (!dir.exists()) {
        dir.mkpath(".");
    }

    // Remove any stale copy
    if (QFile::exists(m_tempBinaryPath)) {
        QFile::remove(m_tempBinaryPath);
    }

    // Copy the dummy to the temp location with the target game name
    if (!QFile::copy(dummySource, m_tempBinaryPath)) {
        emit errorOccurred("Failed to copy dummy executable to " + m_tempBinaryPath);
        return;
    }

    // Set working directory to temp to avoid path leaks
    m_process.setWorkingDirectory(tempDir);
    m_process.setProgram(m_tempBinaryPath);
    m_process.start();

    if (!m_process.waitForStarted(3000)) {
        emit errorOccurred("Failed to start spoofed process.");
        QFile::remove(m_tempBinaryPath);
        m_tempBinaryPath.clear();
        return;
    }

    m_isSpoofing = true;
    m_currentProcessName = processName;
    emit isSpoofingChanged();
    emit currentProcessNameChanged();

    qDebug() << "[Orby] Spawned dummy as:" << targetName
             << "PID:" << m_process.processId();
}

void ProcessSpoofer::stopSpoofing()
{
    // Re-entrancy guard — prevents double-cleanup from signal + explicit call
    if (m_stopping) return;
    m_stopping = true;

    if (m_process.state() != QProcess::NotRunning) {
        m_process.terminate();
        if (!m_process.waitForFinished(1500)) {
            m_process.kill();
            m_process.waitForFinished(1500);
        }
    }

    // Clean up the temporary binary
    if (!m_tempBinaryPath.isEmpty()) {
        if (QFile::exists(m_tempBinaryPath)) {
            QFile::remove(m_tempBinaryPath);
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
