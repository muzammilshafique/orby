#include "ProcessSpoofer.h"
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QDebug>
#include <QFileInfo>

ProcessSpoofer::ProcessSpoofer(QObject *parent)
    : QObject(parent), m_isSpoofing(false)
{
    connect(&m_process, &QProcess::stateChanged, this, [this](QProcess::ProcessState state) {
        if (state == QProcess::NotRunning && m_isSpoofing) {
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

    // Find the system sleep binary
    QString sleepPath = QStandardPaths::findExecutable("sleep");
    if (sleepPath.isEmpty()) {
        emit errorOccurred("Could not find 'sleep' executable on system.");
        return;
    }

    QString tempDir = QDir::tempPath();
    m_tempBinaryPath = QDir(tempDir).filePath(processName);

    // Remove existing file if any
    if (QFile::exists(m_tempBinaryPath)) {
        QFile::remove(m_tempBinaryPath);
    }

    // Copy sleep binary to the temporary path with the target name
    if (!QFile::copy(sleepPath, m_tempBinaryPath)) {
        emit errorOccurred("Failed to copy executable to " + m_tempBinaryPath);
        return;
    }

    // Ensure it is executable
    QFile::setPermissions(m_tempBinaryPath, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner | QFileDevice::ReadUser | QFileDevice::ExeUser);

    // Start the process
    m_process.setProgram(m_tempBinaryPath);
    m_process.setArguments(QStringList() << "31536000"); // Sleep for 1 year
    m_process.start();

    if (!m_process.waitForStarted()) {
        emit errorOccurred("Failed to start spoofed process.");
        QFile::remove(m_tempBinaryPath);
        return;
    }

    m_isSpoofing = true;
    m_currentProcessName = processName;
    emit isSpoofingChanged();
    emit currentProcessNameChanged();
}

void ProcessSpoofer::stopSpoofing()
{
    if (m_process.state() != QProcess::NotRunning) {
        m_process.terminate();
        if (!m_process.waitForFinished(1000)) {
            m_process.kill();
            m_process.waitForFinished(1000);
        }
    }

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
}
