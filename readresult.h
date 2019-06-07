#ifndef READRESULT_H
#define READRESULT_H

#include <QObject>

class ReadResult: public QObject {
    Q_OBJECT
    Q_PROPERTY(bool error READ getError)
    Q_PROPERTY(QString errorString READ getErrorString)
    Q_PROPERTY(QString result READ getResult)

public:
    bool getError() const;
    QString getErrorString() const;
    QString getResult() const;

    bool error = false;
    QString errorString;
    QString result;
};

#endif // READRESULT_H
