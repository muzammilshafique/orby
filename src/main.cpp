#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "ProcessSpoofer.h"
#include "DiscordApi.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOrganizationName("orby");
    app.setOrganizationDomain("orby.org");
    app.setApplicationName("Orby");

    qmlRegisterType<ProcessSpoofer>("Orby", 1, 0, "ProcessSpoofer");
    qmlRegisterType<DiscordApi>("Orby", 1, 0, "DiscordApi");

    QQmlApplicationEngine engine;
    const QUrl url(QStringLiteral("qrc:/Orby/qml/Main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
