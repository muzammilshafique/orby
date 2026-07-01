#include "DiscordApi.h"
#include <QNetworkRequest>
#include <QUrl>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QVariantMap>

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
    request.setHeader(QNetworkRequest::UserAgentHeader, "Orby/1.0 (Linux)");
    
    m_reply = m_networkManager.get(request);
    connect(m_reply, &QNetworkReply::finished, this, &DiscordApi::onReplyFinished);
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
        QStringList executableNames;
        for (const QJsonValue &e : execs) {
            executableNames.append(e.toObject()["name"].toString());
        }

        if (name.isEmpty() || executableNames.isEmpty()) {
            continue;
        }

        QVariantMap gameMap;
        gameMap["name"] = name;
        gameMap["executables"] = executableNames;
        // Use the first executable as the primary one
        gameMap["primaryExecutable"] = executableNames.first();
        gameMap["id"] = obj["id"].toString();
        
        newGames.append(gameMap);
    }

    m_games = newGames;
    emit gamesChanged();
}
