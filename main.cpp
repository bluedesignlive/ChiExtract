#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include "archivemanager.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("ChiExtract");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("Chi");

    QQuickWindow::setDefaultAlphaBuffer(true);

    qmlRegisterType<ArchiveManager>(
        "ChiExtract.Backend", 1, 0, "ArchiveManager");
    qmlRegisterUncreatableType<ArchiveEntryModel>(
        "ChiExtract.Backend", 1, 0, "ArchiveEntryModel",
        "Access via ArchiveManager.contents");

    QQmlApplicationEngine engine;

    // Chi resolves as a system-installed module — no path needed
    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));
    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
