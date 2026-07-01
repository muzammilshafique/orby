#ifndef PROCESSSPOOFER_H
#define PROCESSSPOOFER_H

#include <QObject>
#include <QProcess>
#include <QString>

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
    void startSpoofing(const QString &processName);
    void stopSpoofing();

signals:
    void isSpoofingChanged();
    void currentProcessNameChanged();
    void errorOccurred(const QString &errorMsg);

private:
    QProcess m_process;
    bool m_isSpoofing;
    QString m_currentProcessName;
    QString m_tempBinaryPath;
};

#endif // PROCESSSPOOFER_H
