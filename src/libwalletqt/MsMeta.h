#pragma once

#include <QObject>

class MsMeta;

class MsMetaFactory: public QObject {
    Q_OBJECT
public:
    explicit MsMetaFactory(QObject* parent = nullptr);
    Q_INVOKABLE MsMeta* createMeta();
};

class MsMeta: public QObject {
    Q_OBJECT
    Q_PROPERTY(bool loaded READ isLoaded)
    Q_PROPERTY(QString state READ getState WRITE setState)
    Q_PROPERTY(quint32 signaturesRequired READ getSignaturesRequired WRITE setSignaturesRequired NOTIFY signaturesRequiredChanged)
    Q_PROPERTY(quint32 participantsCount READ getParticipantsCount WRITE setParticipantsCount NOTIFY participantsCountChanged)
    Q_PROPERTY(quint32 keysRounds READ getKeysRounds WRITE setKeysRounds)
    Q_PROPERTY(quint32 lastOutputsRevision READ getLastOutputsRevision WRITE setLastOutputsRevision)
    Q_PROPERTY(quint32 lastOutputsImported READ getLastOutputsImported WRITE setLastOutputsImported NOTIFY lastOuputsImportedChanged)
    Q_PROPERTY(QString path READ getPath WRITE setPath)

public:
    explicit MsMeta(QObject* parent = nullptr);

    Q_INVOKABLE bool save(QString path = "");
    Q_INVOKABLE bool load(QString path);

    Q_INVOKABLE bool isLoaded() const;

    Q_INVOKABLE void setPath(QString path);
    Q_INVOKABLE QString getPath() const;

    Q_INVOKABLE QString getState() const;
    Q_INVOKABLE void setState(const QString& s);

    Q_INVOKABLE quint32 getSignaturesRequired() const;
    Q_INVOKABLE void setSignaturesRequired(quint32 s);

    Q_INVOKABLE quint32 getParticipantsCount() const;
    Q_INVOKABLE void setParticipantsCount(quint32 p);

    Q_INVOKABLE quint32 getKeysRounds() const;
    Q_INVOKABLE void setKeysRounds(quint32 k);

    Q_INVOKABLE quint32 getLastOutputsRevision() const;
    Q_INVOKABLE void setLastOutputsRevision(quint32 l);

    Q_INVOKABLE quint32 getLastOutputsImported() const;
    Q_INVOKABLE void setLastOutputsImported(quint32 l);

signals:
    void lastOuputsImportedChanged() const;
    void signaturesRequiredChanged() const;
    void participantsCountChanged() const;

private:
    bool loaded;
    QString metaPath;
    QString state;
    quint32 signaturesRequired = 0;
    quint32 participantsCount = 0;
    quint32 keysRounds = 0;
    quint32 lastOutputsRevision = 0;
    quint32 lastOutputsImported = 0;
};
