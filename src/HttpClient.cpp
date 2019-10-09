#include "HttpClient.h"
#include "QNetworkReply"
#include "QAbstractNetworkCache"

HttpClientFactory::HttpClientFactory(QObject* parent): QObject(parent) { }

HttpClient* HttpClientFactory::createHttpClient() {
    return new HttpClient(this);
}

HttpClient::HttpClient(QObject* parent): QObject(parent), manager_(new QNetworkAccessManager(this)) {
    connect(manager_, SIGNAL(finished(QNetworkReply *)), SLOT(requestFinished(QNetworkReply *)));
}

void HttpClient::setMethod(const QString& method) {
    method_ = method;
}

void HttpClient::setUrl(const QString& url) {
    url_ = url;
}

void HttpClient::setRequestHeader(const QString& key, const QString& value) {
    headers_[key] = value;
}

void HttpClient::setData(const QString& data) {
    data_ = data;
}

void HttpClient::send() {
    try {
        if (!method_.length()) {
            emit onError(0, "method not set");
            return;
        }

        if (!url_.length()) {
            emit onError(0, "url not set");
            return;
        }

        auto req = QNetworkRequest(QUrl(url_));
        req.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);

        for (const auto& kv: headers_) {
            QByteArray key;
            key.append(kv.first);

            QByteArray val;
            val.append(kv.second);
            req.setRawHeader(key, val);
        }

        if (method_ == "GET") {
            manager_->get(req);
        } else if (method_ == "POST") {
            if (data_.length()) {
                req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
                QByteArray d;
                d.append(data_);
                manager_->post(req, d);
            } else {
                manager_->sendCustomRequest(req, QByteArray("POST"));
            }
        } else if (method_ == "PUT") {
            QByteArray d;
            d.append(data_);
            manager_->put(req, d);
        } else if (method_ == "HEAD") {
            manager_->head(req);
        } else {
            emit onError(0, "unknown verb given");
            return;
        }
    } catch (const std::exception& e) {
        emit onError(0, "failed to send request: " + QString::fromStdString(e.what()));
    }
}

void HttpClient::requestFinished(QNetworkReply *reply) {
    if (reply->error() == QNetworkReply::NoError) {
        QVariant statusCode = reply->attribute( QNetworkRequest::HttpStatusCodeAttribute );
        if (!statusCode.isValid()) {
            qCritical() << "failed to fetch response's status code";
            onError(0, "failed to fetch response's status code");
            return;
        }

        int status = statusCode.toInt();
        QString data = QString::fromUtf8(reply->readAll());
        if (status >= 200 && status < 300) {
            emit onSuccess(status, data);
            return;
        }

        emit onError(status, data);
    } else {
        QVariant statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute);
        if (!statusCode.isValid()) {
            qCritical() << "failed to fetch response's status code, error: " << reply->errorString();
            onError(0, reply->errorString());
            return;
        }

        int status = statusCode.toInt();
        if (status == 301 || status == 302 || status == 307 || status == 308) {
            QVariant location = reply->attribute(QNetworkRequest::RedirectionTargetAttribute);
            if (!location.isValid()) {
                qCritical() << "Server responded with redirect to wrong url";
                onError(0, "Server responded with redirect to wrong url");
                return;
            }

            auto url = QUrl(url_).resolved(location.toUrl());
            qWarning() << "redirecting to " << url;
            setUrl(url.toString());
            send();
            return;
        }

        QString data = QString::fromUtf8(reply->readAll());
        emit onError(status, data);
    }

    reply->deleteLater();
}
