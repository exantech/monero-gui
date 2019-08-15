#pragma once

#include <map>

#include <QObject>
#include <QNetworkAccessManager>

class HttpClient;

class HttpClientFactory: public QObject {
    Q_OBJECT
public:
    explicit HttpClientFactory(QObject* parent = nullptr);
    Q_INVOKABLE HttpClient* createHttpClient();
};

class HttpClient: public QObject {
    Q_OBJECT
public:
    explicit HttpClient(QObject* parent = nullptr);

    Q_INVOKABLE void setMethod(const QString& method);
    Q_INVOKABLE void setUrl(const QString& url);
    Q_INVOKABLE void setRequestHeader(const QString& key, const QString& value);
    Q_INVOKABLE void setData(const QString& data);
    Q_INVOKABLE void send();

signals:
    void onError(int statusCode, QString errorString);
    void onSuccess(int statusCode, QString message);

private slots:
    void requestFinished(QNetworkReply *reply);

private:
    QNetworkAccessManager* manager_;
    QString url_;
    QString method_;
    QString data_;
    std::map<QString, QString> headers_;
};
