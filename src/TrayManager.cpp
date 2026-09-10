#include "TrayManager.h"

#include <QApplication>
#include <QIcon>
#include <QAction>
#include <QFont>
#include <QDebug>

TrayManager::TrayManager(QObject *parent)
    : QObject(parent)
{
    if (QSystemTrayIcon::isSystemTrayAvailable()) {
        m_trayIcon = new QSystemTrayIcon(QIcon(":/icons/orby.png"), this);
        m_trayIcon->setToolTip(QStringLiteral("Orby - Discord Game Presence Spoofer"));

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

void TrayManager::notifyClosedToTray()
{
    if (m_trayIcon && m_trayIcon->isVisible()) {
        m_trayIcon->showMessage(
            QStringLiteral("Orby"),
            QStringLiteral("Orby is running in the system tray. Background game spoofing will continue.\nRight-click this icon to open or quit."),
            QSystemTrayIcon::Information,
            3500
        );
    }
}

void TrayManager::showMessage(const QString &title, const QString &message, int durationMs)
{
    if (m_trayIcon && m_trayIcon->isVisible()) {
        m_trayIcon->showMessage(title, message, QSystemTrayIcon::Information, durationMs);
    }
}
