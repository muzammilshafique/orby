#include "DiscordApi.h"
#include "ProcessSpoofer.h"
#include "TrayManager.h"

#include <QApplication>
#include <QFontDatabase>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

int main(int argc, char *argv[]) {
  QApplication app(argc, argv);
  QQuickStyle::setStyle("Basic");
  app.setOrganizationName("orby");
  app.setOrganizationDomain("orby.org");
  app.setApplicationName("Orby");
  app.setDesktopFileName(QStringLiteral("orby"));
  app.setWindowIcon(QIcon(":/icons/orby.png"));

  // Load bundled Google Sans and Material Symbols fonts
  QFontDatabase::addApplicationFont(":/fonts/GoogleSansFlex.ttf");
  QFontDatabase::addApplicationFont(":/fonts/MaterialSymbolsRounded.ttf");

  QFont defaultFont("Google Sans Flex", 10);
  app.setFont(defaultFont);

  // Keep application running in tray when the window is closed
  app.setQuitOnLastWindowClosed(false);

  qmlRegisterType<ProcessSpoofer>("Orby", 1, 0, "ProcessSpoofer");
  qmlRegisterType<DiscordApi>("Orby", 1, 0, "DiscordApi");

  TrayManager trayManager;

  QQmlApplicationEngine engine;
  engine.rootContext()->setContextProperty("trayManager", &trayManager);

  const QUrl url(QStringLiteral("qrc:/Orby/qml/Main.qml"));
  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
      []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
  engine.load(url);

  return app.exec();
}
