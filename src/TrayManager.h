#ifndef TRAYMANAGER_H
#define TRAYMANAGER_H

#include <QObject>
#include <QSystemTrayIcon>
#include <QMenu>

class TrayManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool closeToTray READ closeToTray WRITE setCloseToTray NOTIFY closeToTrayChanged)
    Q_PROPERTY(bool isSystemTrayAvailable READ isSystemTrayAvailable CONSTANT)

public:
    explicit TrayManager(QObject *parent = nullptr);
    ~TrayManager();

    bool closeToTray() const;
    void setCloseToTray(bool enabled);

    bool isSystemTrayAvailable() const;

    Q_INVOKABLE void showTrayIcon();
    Q_INVOKABLE void hideTrayIcon();
    Q_INVOKABLE void notifyClosedToTray(const QString &activeGamesSummary = QString());
    Q_INVOKABLE void showMessage(const QString &title, const QString &message, int durationMs = 3000);
    Q_INVOKABLE void setTrayToolTip(const QString &tooltip);

signals:
    void showWindowRequested();
    void hideWindowRequested();
    void toggleWindowRequested();
    void closeToTrayChanged();

private slots:
    void onActivated(QSystemTrayIcon::ActivationReason reason);

private:
    QSystemTrayIcon *m_trayIcon = nullptr;
    QMenu *m_menu = nullptr;
    bool m_closeToTray = true;
    bool m_notifiedOnce = false;

    void setupMenu();
};

#endif // TRAYMANAGER_H
