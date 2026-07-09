#include "ProcessSpoofer.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QCoreApplication>
#include <QDebug>

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

    // Dummy executable is built alongside the main executable on Windows
    QString dummySource = QCoreApplication::applicationDirPath() + "/dummy.exe";
    if (!QFile::exists(dummySource)) {
        emit errorOccurred("Could not find 'dummy.exe' in application directory.");
        return;
    }

    QString tempDir = QDir::tempPath();
    m_tempBinaryPath = QDir(tempDir).filePath(processName);

    // Create necessary parent subdirectories if the processName contains slashes
    QFileInfo fileInfo(m_tempBinaryPath);
    QDir dir = fileInfo.dir();
    if (!dir.exists()) {
        dir.mkpath(".");
    }

    if (QFile::exists(m_tempBinaryPath)) {
        QFile::remove(m_tempBinaryPath);
    }

    if (!QFile::copy(dummySource, m_tempBinaryPath)) {
        emit errorOccurred("Failed to copy dummy executable to " + m_tempBinaryPath);
        return;
    }

    m_process.setProgram(m_tempBinaryPath);
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
