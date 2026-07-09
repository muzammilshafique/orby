#include "ProcessSpoofer.h"
#include <QDebug>
#include <sys/prctl.h>
#include <sys/types.h>
#include <signal.h>
#include <unistd.h>
#include <sys/wait.h>

ProcessSpoofer::ProcessSpoofer(QObject *parent)
    : QObject(parent), m_isSpoofing(false), m_spoofedPid(0)
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

    pid_t pid = fork();
    if (pid == -1) {
        emit errorOccurred("Failed to fork child process.");
        return;
    } else if (pid == 0) {
        // Child process
        // prctl PR_SET_NAME accepts up to 15 characters
        QByteArray nameBytes = processName.toUtf8();
        if (nameBytes.length() > 15) {
            nameBytes.truncate(15);
        }
        
        prctl(PR_SET_NAME, nameBytes.constData(), 0, 0, 0);

        // Keep the process alive indefinitely with minimal resource usage
        while (true) {
            sleep(60);
        }
        _exit(0);
    } else {
        // Parent process
        m_spoofedPid = pid;
        m_isSpoofing = true;
        m_currentProcessName = processName;
        emit isSpoofingChanged();
        emit currentProcessNameChanged();
    }
}

void ProcessSpoofer::stopSpoofing()
{
    if (m_spoofedPid > 0) {
        kill(m_spoofedPid, SIGKILL);
        waitpid(m_spoofedPid, nullptr, 0);
        m_spoofedPid = 0;
    }

    if (m_isSpoofing) {
        m_isSpoofing = false;
        m_currentProcessName.clear();
        emit isSpoofingChanged();
        emit currentProcessNameChanged();
    }
}
