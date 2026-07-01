#ifndef DISCORDAPI_H
#define DISCORDAPI_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QVariantList>

class DiscordApi : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList games READ games NOTIFY gamesChanged)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)

public:
    explicit DiscordApi(QObject *parent = nullptr);
    
    QVariantList games() const;
    bool isLoading() const;

public slots:
    void fetchGames();

signals:
    void gamesChanged();
    void isLoadingChanged();
    void errorOccurred(const QString &errorMsg);

private slots:
    void onReplyFinished();

private:
    QNetworkAccessManager m_networkManager;
    QNetworkReply *m_reply = nullptr;
    QVariantList m_games;
    bool m_isLoading = false;
};

#endif // DISCORDAPI_H
