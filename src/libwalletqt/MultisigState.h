#ifndef MULTISIGSTATE_H
#define MULTISIGSTATE_H

#include <QObject>

namespace Monero {
    class MultisigState;
}

class MultisigState: public QObject {
    Q_OBJECT
    Q_PROPERTY(bool multisig READ multisig NOTIFY multisigChanged)
    Q_PROPERTY(bool ready READ ready)
    Q_PROPERTY(quint32 signaturesRequired READ signaturesRequired)
    Q_PROPERTY(quint32 participantsCount READ participantsCount)

public:
    explicit MultisigState(const Monero::MultisigState& state, QObject* parent);

    bool multisig() const;
    bool ready() const;
    quint32 signaturesRequired() const;
    quint32 participantsCount() const;

signals:
    void multisigChanged() const;

private:
    bool isMultisig;
    bool isReady;
    quint32 threshold;
    quint32 total;
};

#endif // MULTISIGSTATE_H
