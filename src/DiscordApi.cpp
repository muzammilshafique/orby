#include "DiscordApi.h"
#include <QNetworkRequest>
#include <QUrl>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QVariantMap>
#include <QSysInfo>

DiscordApi::DiscordApi(QObject *parent) : QObject(parent)
{
}

QVariantList DiscordApi::games() const
{
    return m_games;
}

bool DiscordApi::isLoading() const
{
    return m_isLoading;
}

void DiscordApi::fetchGames()
{
    if (m_isLoading) {
        return;
    }

    m_isLoading = true;
    emit isLoadingChanged();

    QUrl url("https://discord.com/api/v9/applications/detectable");
    QNetworkRequest request(url);
#if defined(Q_OS_WIN)
    request.setHeader(QNetworkRequest::UserAgentHeader, "Orby/1.0 (Windows)");
#elif defined(Q_OS_LINUX)
    request.setHeader(QNetworkRequest::UserAgentHeader, "Orby/1.0 (Linux)");
#elif defined(Q_OS_MAC)
    request.setHeader(QNetworkRequest::UserAgentHeader, "Orby/1.0 (macOS)");
#else
    request.setHeader(QNetworkRequest::UserAgentHeader, "Orby/1.0");
#endif
    
    m_reply = m_networkManager.get(request);
    connect(m_reply, &QNetworkReply::finished, this, &DiscordApi::onReplyFinished);
}

static bool isValidExecutableName(const QString &name)
{
    if (name.isEmpty())
        return false;
    for (QChar c : QStringLiteral("<>:\"|?*")) {
        if (name.contains(c))
            return false;
    }
    return true;
}

void DiscordApi::onReplyFinished()
{
    if (!m_reply) return;

    m_isLoading = false;
    emit isLoadingChanged();

    if (m_reply->error() != QNetworkReply::NoError) {
        emit errorOccurred(m_reply->errorString());
        m_reply->deleteLater();
        m_reply = nullptr;
        return;
    }

    QByteArray data = m_reply->readAll();
    m_reply->deleteLater();
    m_reply = nullptr;

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);

    if (parseError.error != QJsonParseError::NoError) {
        emit errorOccurred("Failed to parse JSON: " + parseError.errorString());
        return;
    }

    if (!doc.isArray()) {
        emit errorOccurred("Invalid JSON format: expected an array.");
        return;
    }

    QVariantList newGames;
    QJsonArray array = doc.array();

    for (const QJsonValue &val : array) {
        QJsonObject obj = val.toObject();
        QString name = obj["name"].toString();

        QJsonArray execs = obj["executables"].toArray();
        QStringList win32Execs;
        QStringList allValidExecs;

        for (const QJsonValue &e : execs) {
            QJsonObject execObj = e.toObject();
            QString execOs = execObj["os"].toString();
            QString execName = execObj["name"].toString().trimmed();

            // Normalize path separators
            execName.replace('\\', '/');

            // Strip leading '>' if present (Discord internal argument matching flag)
            if (execName.startsWith('>'))
                execName.remove(0, 1);

            // Strip leading slashes
            while (execName.startsWith('/'))
                execName.remove(0, 1);

            if (!isValidExecutableName(execName))
                continue;

            if (execOs == QStringLiteral("win32")) {
                if (!win32Execs.contains(execName))
                    win32Execs.append(execName);
            }
            if (!allValidExecs.contains(execName))
                allValidExecs.append(execName);
        }

#ifdef Q_OS_WIN
        QStringList executableNames = !win32Execs.isEmpty() ? win32Execs : allValidExecs;
#else
        QStringList executableNames = allValidExecs;
#endif

        if (name.isEmpty() || executableNames.isEmpty()) {
            continue;
        }

        // Extract Steam App ID from third-party SKUs (for Steam spoofing)
        QString steamAppId;
        QJsonArray skus = obj["third_party_skus"].toArray();
        for (const QJsonValue &sku : skus) {
            QJsonObject skuObj = sku.toObject();
            if (skuObj["distributor"].toString() == "steam") {
                QString id = skuObj["id"].toString();
                if (!id.isEmpty()) {
                    steamAppId = id;
                    break;
                }
            }
        }

        QVariantMap gameMap;
        gameMap["name"] = name;
        gameMap["executables"] = executableNames;
        gameMap["primaryExecutable"] = executableNames.first();
        gameMap["id"] = obj["id"].toString();
        gameMap["steamAppId"] = steamAppId;

        newGames.append(gameMap);
    }

    m_games = newGames;
    emit gamesChanged();
}
