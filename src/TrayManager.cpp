#include "TrayManager.h"

#include <QApplication>
#include <QIcon>
#include <QAction>
#include <QFont>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QStyleHints>
#include <QPalette>
#include <QPixmap>

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
        m_trayIcon = new QSystemTrayIcon(getThemedTrayIcon(), this);
        m_trayIcon->setToolTip(QStringLiteral("Orby — Discord Game Presence Spoofer"));

        setupMenu();
        setupThemeMonitoring();

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

        const QIcon notifIcon(QStringLiteral(":/icons/orby.png"));
        m_trayIcon->showMessage(title, message, notifIcon, 4000);
    }
}

void TrayManager::showMessage(const QString &title, const QString &message, int durationMs)
{
    if (m_trayIcon && m_trayIcon->isVisible()) {
        const QIcon notifIcon(QStringLiteral(":/icons/orby.png"));
        m_trayIcon->showMessage(title, message, notifIcon, durationMs);
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

void TrayManager::updateTrayIcon()
{
    if (m_trayIcon) {
        m_trayIcon->setIcon(getThemedTrayIcon());
    }
}

void TrayManager::setupThemeMonitoring()
{
#ifdef Q_OS_LINUX
    // Listen to Qt styleHints for color scheme changes (FreeDesktop portal / KDE / GNOME)
    if (QGuiApplication::styleHints()) {
        connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged,
                this, [this](Qt::ColorScheme scheme) {
                    qDebug() << "[Orby] System color scheme changed to:" << scheme;
                    updateTrayIcon();
                });
    }

    // Monitor application-wide palette and theme change events
    qApp->installEventFilter(this);
#endif
}

bool TrayManager::eventFilter(QObject *watched, QEvent *event)
{
#ifdef Q_OS_LINUX
    if (watched == qApp && (event->type() == QEvent::ApplicationPaletteChange || 
                            event->type() == QEvent::ThemeChange)) {
        updateTrayIcon();
    }
#endif
    return QObject::eventFilter(watched, event);
}

QIcon TrayManager::getThemedTrayIcon() const
{
#ifdef Q_OS_LINUX
    bool isDark = true;

    // 1. Query Qt style hints (connected via FreeDesktop portal / Wayland)
    if (QGuiApplication::styleHints()) {
        auto scheme = QGuiApplication::styleHints()->colorScheme();
        if (scheme == Qt::ColorScheme::Dark) {
            isDark = true;
        } else if (scheme == Qt::ColorScheme::Light) {
            isDark = false;
        } else {
            // Fallback: check window/panel brightness from palette
            QColor windowColor = QApplication::palette().color(QPalette::Window);
            isDark = (windowColor.lightness() < 128);
        }
    } else {
        QColor windowColor = QApplication::palette().color(QPalette::Window);
        isDark = (windowColor.lightness() < 128);
    }

    if (isDark) {
        // Dark theme: panel background is dark, show crisp white icon
        QIcon lightIcon(QStringLiteral(":/icons/orby-tray.svg"));
        if (!lightIcon.isNull()) {
            return lightIcon;
        }
    } else {
        // Light theme: panel background is light, show dark icon
        QIcon darkIcon(QStringLiteral(":/icons/orby-tray-dark.svg"));
        if (!darkIcon.isNull()) {
            return darkIcon;
        }

        // Dynamic recoloring fallback if SVG asset missing
        QFile file(QStringLiteral(":/icons/orby-tray.svg"));
        if (file.open(QIODevice::ReadOnly)) {
            QByteArray svgData = file.readAll();
            file.close();
            svgData.replace("fill:#ffffff", "fill:#1C1B1F");
            svgData.replace("fill:#FFFFFF", "fill:#1C1B1F");
            QPixmap pixmap;
            if (pixmap.loadFromData(svgData, "SVG")) {
                return QIcon(pixmap);
            }
        }
    }

    return QIcon(QStringLiteral(":/icons/orby-tray.svg"));
#else
    return QIcon(QStringLiteral(":/icons/orby.png"));
#endif
}
