#ifndef PROCESSSPOOFER_H
#define PROCESSSPOOFER_H

#include <QObject>
#include <QString>

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

public:
    explicit ProcessSpoofer(QObject *parent = nullptr);
    ~ProcessSpoofer();

    bool isSpoofing() const;
    QString currentProcessName() const;

public slots:
    void startSpoofing(const QString &processName,
                       const QString &gameName = QString(),
                       const QString &steamAppId = QString());
    void stopSpoofing();

signals:
    void isSpoofingChanged();
    void currentProcessNameChanged();
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
    pid_t m_childPid = -1;
    QString m_tempBinaryPath;
#endif
};

#endif // PROCESSSPOOFER_H
