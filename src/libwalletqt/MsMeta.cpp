#include "MsMeta.h"

#include <sstream>

#include <QFile>
#include <QTextStream>
#include <QDebug>
#include <QJsonObject>
#include <QJsonDocument>
#include <QCryptographicHash>

#include "wallet/api/wallet2_api.h"
#include "common/base58.h"

bool writeFile(const QByteArray& data, const QString& filename) {
    QFile file(filename);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "failed to open " << filename << ": " << file.errorString();
        return false;
    }

    QTextStream stream(&file);
    stream << data;
    file.close();

    return true;
}

// throws!
QByteArray readFile(const QString& filename) {
    QFile file(filename);
    if (!file.open(QIODevice::ReadOnly)) {
        throw std::runtime_error(file.errorString().toStdString());
    }

    QByteArray res;
    QTextStream stream(&file);
    stream >> res;
    file.close();

    return res;
}

//throws!
quint32 getMandatoryUint32(const QJsonObject& obj, const QString& field) {
    if (!obj.contains(field) || !obj[field].isDouble()) {
        std::stringstream stream;
        stream << "\"" << field.toStdString() << "\" field is absent or not integer type";
        throw std::runtime_error(stream.str());
    }

    return obj[field].toInt();
}

std::string hashString(const std::string& str) {
    auto h = QCryptographicHash::hash(QByteArray(str.c_str()), QCryptographicHash::Sha3_256);
    return h.toHex().toStdString();
}

MsMetaFactory::MsMetaFactory(QObject* parent): QObject (parent) {
}

MsMeta* MsMetaFactory::createMeta() {
    return new MsMeta(this);
}

MsMeta::MsMeta(QObject* parent) : QObject(parent) {
}

bool MsMeta::save(const QString& password, const QString& path) {
    if (path.length()) {
        metaPath = path;
    }

    QJsonObject obj;
    obj.insert("state", state);
    obj.insert("mwsUrl", mwsUrl);
    obj.insert("signaturesRequired", static_cast<int>(signaturesRequired));
    obj.insert("participantsCount", static_cast<int>(participantsCount));
    obj.insert("keysRounds", static_cast<int>(keysRounds));
    obj.insert("lastOutputsRevision", static_cast<int>(lastOutputsRevision));
    obj.insert("lastOutputsImported", static_cast<int>(lastOutputsImported));

    std::string encodedSeed = tools::base58::encode(Monero::chachaEncrypt(personalSeed.toStdString(), hashString(password.toStdString())));
    obj.insert("personalSeed", QString::fromStdString(encodedSeed));

    QJsonDocument doc(obj);
    auto bytes = doc.toJson(QJsonDocument::Compact);
    return writeFile(bytes, metaPath);
}

bool MsMeta::load(const QString& password, const QString& path) {
    try {
        auto bytes = readFile(path);

        QJsonParseError err;
        auto doc = QJsonDocument::fromJson(bytes, &err);
        if (doc.isNull()) {
            qWarning() << "failed to parse json file " << path << ": " << err.errorString();
            return false;
        }

        auto obj = doc.object();
        if (!obj.contains("state") || !obj["state"].isString()) {
            qWarning() << "failed to parse json file " << path << ": " << " \"state\" field is absent or not string type";
            return false;
        }

        state = obj["state"].toString();
        mwsUrl = obj["mwsUrl"].toString();
        signaturesRequired = getMandatoryUint32(obj, "signaturesRequired");
        participantsCount = getMandatoryUint32(obj, "participantsCount");
        keysRounds = getMandatoryUint32(obj, "keysRounds");
        lastOutputsRevision = obj["lastOutputsRevision"].toInt(0);
        lastOutputsImported = obj["lastOutputsImported"].toInt(0);

        if (obj.contains("personalSeed")) {
            QString encodedSeed = obj["personalSeed"].toString();
            if (!encodedSeed.isEmpty()) {
                std::string decodedSeed;
                if (!tools::base58::decode(encodedSeed.toStdString(), decodedSeed)) {
                    qWarning() << "failed to decode seed in meta file: " << path;
                    return false;
                }

                personalSeed = QString::fromStdString(Monero::chachaDecrypt(decodedSeed, hashString(password.toStdString())));
            }
        }

        return true;
    } catch (const std::exception& ex) {
        qWarning() << "failed to parse json file " << path << ": " << ex.what();
    }

    return false;
}

bool MsMeta::isLoaded() const {
    return loaded;
}

void MsMeta::setPath(QString path) {
    metaPath = path;
}

QString MsMeta::getPath() const {
    return metaPath;
}

QString MsMeta::getState() const {
    return state;
}

quint32 MsMeta::getSignaturesRequired() const {
    return signaturesRequired;
}

quint32 MsMeta::getParticipantsCount() const {
    return participantsCount;
}

quint32 MsMeta::getKeysRounds() const {
    return keysRounds;
}

quint32 MsMeta::getLastOutputsRevision() const {
    return lastOutputsRevision;
}

void MsMeta::setState(const QString& s) {
    state = s;
}

QString MsMeta::getMwsUrl() const {
    return mwsUrl;
}

void MsMeta::setMwsUrl(const QString& url) {
    mwsUrl = url;
}

void MsMeta::setSignaturesRequired(quint32 s) {
    signaturesRequired = s;
}

void MsMeta::setParticipantsCount(quint32 p) {
    participantsCount = p;
}

void MsMeta::setKeysRounds(quint32 k) {
    keysRounds = k;
}

void MsMeta::setLastOutputsRevision(quint32 l) {
    lastOutputsRevision = l;
}

quint32 MsMeta::getLastOutputsImported() const {
    return lastOutputsImported;
}

void MsMeta::setLastOutputsImported(quint32 l) {
    lastOutputsImported = l;
}

void MsMeta::setPersonalSeed(const QString& s) {
    personalSeed = s;
}

QString MsMeta::getPersonalSeed() const {
    return personalSeed;
}
