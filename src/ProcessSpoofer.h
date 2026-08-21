#ifndef PROCESSSPOOFER_H
#define PROCESSSPOOFER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QMap>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

#ifdef Q_OS_LINUX
#include <sys/types.h>  // pid_t
#endif

class ProcessSpoofer : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isSpoofing READ isSpoofing NOTIFY isSpoofingChanged)
    Q_PROPERTY(QString currentProcessName READ currentProcessName NOTIFY currentProcessNameChanged)
    Q_PROPERTY(QStringList spoofedProcesses READ spoofedProcesses NOTIFY spoofedProcessesChanged)
    Q_PROPERTY(int spoofedCount READ spoofedCount NOTIFY spoofedProcessesChanged)

public:
    explicit ProcessSpoofer(QObject *parent = nullptr);
    ~ProcessSpoofer();

    bool isSpoofing() const;
    QString currentProcessName() const;
    QStringList spoofedProcesses() const;
    int spoofedCount() const;
    Q_INVOKABLE bool isSpoofingProcess(const QString &processName) const;

public slots:
    void startSpoofing(const QString &processName,
                       const QString &gameName = QString(),
                       const QString &steamAppId = QString());
    void stopSpoofing();             // stops the first / legacy single process
    void stopSpoofingProcess(const QString &processName);
    void stopAllSpoofing();

signals:
    void isSpoofingChanged();
    void currentProcessNameChanged();
    void spoofedProcessesChanged();
    void errorOccurred(const QString &errorMsg);

private:
    bool m_isSpoofing = false;
    bool m_stopping = false;  // Re-entrancy guard
    QString m_currentProcessName;

#ifdef Q_OS_WIN
    HANDLE m_processHandle = nullptr;
    QString m_tempBinaryPath;
    QString m_manifestPath;  // Steam ACF manifest for cleanup
#endif

#ifdef Q_OS_LINUX
    // Legacy single-process fields (kept for backward compat)
    pid_t m_childPid = -1;
    QString m_tempBinaryPath;

    // Multi-process tracking
    struct SpoofEntry {
        pid_t pid = -1;
        QString tempBinaryPath;
    };
    QMap<QString, SpoofEntry> m_spoofedProcesses;

    void killAndCleanEntry(SpoofEntry &entry);
    void refreshSpoofingState();
#endif
};

#endif // PROCESSSPOOFER_H
