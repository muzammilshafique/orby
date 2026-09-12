#include "TrayManager.h"

#include <QApplication>
#include <QIcon>
#include <QAction>
#include <QFont>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QStandardPaths>

TrayManager::TrayManager(QObject *parent)
    : QObject(parent)
{
#ifdef Q_OS_LINUX
    // Ensure the icon is present in standard user icon path for notification daemons
    QString iconDir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/icons/hicolor/256x256/apps");
    QDir().mkpath(iconDir);
    QString userIconPath = iconDir + QStringLiteral("/orby.png");
    if (!QFile::exists(userIconPath)) {
        QFile::copy(QStringLiteral(":/icons/orby.png"), userIconPath);
    }
#endif

    if (QSystemTrayIcon::isSystemTrayAvailable()) {
        m_trayIcon = new QSystemTrayIcon(QIcon(QStringLiteral(":/icons/orby.png")), this);
        m_trayIcon->setToolTip(QStringLiteral("Orby — Discord Game Presence Spoofer"));

        setupMenu();

        connect(m_trayIcon, &QSystemTrayIcon::activated,
                this, &TrayManager::onActivated);

        m_trayIcon->show();
    } else {
        qWarning() << "[Orby] System tray is not available on this system.";
    }
}

TrayManager::~TrayManager()
{
    if (m_trayIcon) {
        m_trayIcon->hide();
    }
}

bool TrayManager::closeToTray() const
{
    return m_closeToTray;
}

void TrayManager::setCloseToTray(bool enabled)
{
    if (m_closeToTray != enabled) {
        m_closeToTray = enabled;
        emit closeToTrayChanged();
    }
}

bool TrayManager::isSystemTrayAvailable() const
{
    return QSystemTrayIcon::isSystemTrayAvailable();
}

void TrayManager::showTrayIcon()
{
    if (m_trayIcon && !m_trayIcon->isVisible()) {
        m_trayIcon->show();
    }
}

void TrayManager::hideTrayIcon()
{
    if (m_trayIcon && m_trayIcon->isVisible()) {
        m_trayIcon->hide();
    }
}

void TrayManager::setupMenu()
{
    if (!m_trayIcon) return;

    m_menu = new QMenu();

    QAction *openAction = m_menu->addAction(QStringLiteral("Open Orby"));
    QFont boldFont = openAction->font();
    boldFont.setBold(true);
    openAction->setFont(boldFont);
    connect(openAction, &QAction::triggered, this, &TrayManager::showWindowRequested);

    QAction *hideAction = m_menu->addAction(QStringLiteral("Hide to Tray"));
    connect(hideAction, &QAction::triggered, this, &TrayManager::hideWindowRequested);

    m_menu->addSeparator();

    QAction *quitAction = m_menu->addAction(QStringLiteral("Quit Orby"));
    connect(quitAction, &QAction::triggered, qApp, &QCoreApplication::quit);

    m_trayIcon->setContextMenu(m_menu);
}

void TrayManager::onActivated(QSystemTrayIcon::ActivationReason reason)
{
    switch (reason) {
    case QSystemTrayIcon::Trigger:
    case QSystemTrayIcon::DoubleClick:
        emit toggleWindowRequested();
        break;
    default:
        break;
    }
}

void TrayManager::notifyClosedToTray(const QString &activeGamesSummary)
{
    if (m_trayIcon && m_trayIcon->isVisible()) {
        QString title = QStringLiteral("Orby — Spoofing Active");
        QString message;
        if (!activeGamesSummary.trimmed().isEmpty()) {
            message = QStringLiteral("Currently spoofing: %1\nRunning in system tray. Click icon to open.").arg(activeGamesSummary);
        } else {
            message = QStringLiteral("Presence spoofing is active in background.\nClick tray icon to reopen Orby.");
        }

        const QIcon icon = (m_trayIcon && !m_trayIcon->icon().isNull()) 
            ? m_trayIcon->icon() 
            : QIcon(QStringLiteral(":/icons/orby.png"));

        m_trayIcon->showMessage(title, message, icon, 4000);
    }
}

void TrayManager::showMessage(const QString &title, const QString &message, int durationMs)
{
    if (m_trayIcon && m_trayIcon->isVisible()) {
        const QIcon icon = (m_trayIcon && !m_trayIcon->icon().isNull()) 
            ? m_trayIcon->icon() 
            : QIcon(QStringLiteral(":/icons/orby.png"));
        m_trayIcon->showMessage(title, message, icon, durationMs);
    }
}

void TrayManager::setTrayToolTip(const QString &tooltip)
{
    if (m_trayIcon) {
        m_trayIcon->setToolTip(tooltip.isEmpty() 
            ? QStringLiteral("Orby — Discord Game Presence Spoofer") 
            : tooltip);
    }
}
