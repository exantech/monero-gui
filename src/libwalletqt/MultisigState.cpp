#include "MultisigState.h"

#include "wallet/api/wallet2_api.h"

MultisigState::MultisigState(const Monero::MultisigState& state, QObject* parent): QObject(parent) {
    isMultisig = state.isMultisig;
    isReady = state.isReady;
    threshold = state.threshold;
    total = state.total;
}

bool MultisigState::multisig() const {
    return isMultisig;
}

bool MultisigState::ready() const {
    return isReady;
}

quint32 MultisigState::signaturesRequired() const {
    return threshold;
}

quint32 MultisigState::participantsCount() const {
    return total;
}
