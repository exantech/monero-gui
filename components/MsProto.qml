pragma Singleton

import QtQuick 2.0

import "../js/Request.js" as Request

QtObject {
    property string mwsUrl: "http://mws-stage.exan.tech/"
    property string apiVersion: "api/v1/"

    property var meta
    property var mWallet
    property int nonce: 1
    property bool newWallet: false
    property string inviteCode
    property bool stopped: false
    property bool exchangingOutputs: false

    property string sessionId

    signal sessionOpened
    signal inviteCodeReceived(string inviteCode)
    signal keyExchangeRoundPassed(int newRoundNumber)
    signal joinedToWallet
    signal walletCreated
    signal error(string msg)

    signal proposalSent(int id)
    signal sendProposalError(string message);

    signal activeProposal(var prop)

    property Timer timer: Timer{
        interval: 2000
        running: false
        repeat: true
        triggeredOnStart: false
    }

    property Timer repeatTimer: Timer {
        interval: 2000
        running: false
        repeat: true
        triggeredOnStart: false
    }

    function stop() {
        if (stopped) {
            return
        }

        //debug my
        console.error("Stopping protocol");
        timer.stop();
        timer.onTriggered.disconnect(exchangeKeys);
        if (mWallet) {
            mWallet.refreshed.disconnect(onWalletRefreshed);
            mWallet.multisigTxRestored.disconnect(onMultisigTxRestored);
        }

        mWallet = null;
        stopped = true;

        if (meta) {
            meta.save();
            meta = null;
        }

        sessionId = "";
        inviteCode = "";
        exchangingOutputs = false;
    }

    function start() {
        if (!mWallet) {
            throw "wallet must be set";
        }

        if (meta.state === "personal" && (meta.signaturesRequired === 0 || meta.participantsCount === 0)) {
            throw "signatures and participants count are both required for newly created wallets";
        }

        if (sessionId != "") {
            throw "multisignature protocol already started";
        }

        mWallet.refreshed.connect(onWalletRefreshed)
        mWallet.multisigTxRestored.connect(onMultisigTxRestored)

        stopped = false;
        openSession();
    }

    function onOpenSessionResponse() {
        sessionOpened(); // emit signal
        //debug my
        console.error("session opened.")

        switch (meta.state) {
        case "personal":
            createWallet("good wallet");
            break;
        case "joining":
            joinWallet();
            break;
        case "inProgress":
            getWalletInfo(infoHandler);
            break;
        case "ready":
            break;
        default:
            console.error("unknown multisignature state: " + meta.state);
        }
    }

    function openSession() {
        var signerKey = mWallet.publicSpendKey;
        if (meta.keysRounds > 0) {
            signerKey = mWallet.publicMultisigSignerKey;
        }

        //debug my
        console.error("openning session. public key: " + signerKey + ", keys rounds: " + meta.keysRounds);
        var data = JSON.stringify({
            'public_key': signerKey
        });

        var req = new Request.Request()
            .setMethod("POST")
            .setUrl(getUrl("open_session"))
            .setData(data)
            .onSuccess(getHandler("open session", function (obj) {
                if (!obj.session_id) {
                    error("unexpected \"open_session\" response: " + resp);
                    return;
                }

                sessionId = obj.session_id;
                onOpenSessionResponse();
            }))
            .onError(getStdError("open session"));

        req.send();
    }

    function createWallet(name) {
        var data = JSON.stringify({
            'signers': meta.signaturesRequired,
            'participants': meta.participantsCount,
            'multisig_info': mWallet.multisigInfo,
            'name': name,
        });

        var nonce = nextNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request()
            .setMethod("POST")
            .setUrl(getUrl("create_wallet"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .setData(data)
            .onSuccess(getHandler("create wallet", function (obj) {
                meta.state = "inProgress";
                meta.save();

                inviteCodeReceived(obj.invite_code);
                //debug my
                console.error("invite code: " + obj.invite_code);
                timer.onTriggered.connect(exchangeKeys);
                timer.start();
            }))
            .onError(getStdError("create wallet"));

        req.send();
    }

    function exchangeKeys() {
        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);
        //debug my
        console.error("exchange keys. changed keys: " + meta.keysRounds);

        var url = getUrl("info/multisig");
        var name = "multisig info";
        var callback = processMultisigInfo;
        if (meta.keysRounds > 0) {
            url = getUrl("info/extra_multisig");
            name = "extra multisig info";
            callback = processExtraMultisigInfo;
        }

        var req = new Request.Request()
            .setMethod("GET")
            .setUrl(url)
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .onSuccess(getHandler(name, callback))
            .onError(getStdError(name));

        req.send();
    }

    function pushExtraMultisigInfo(ems) {
        var data = JSON.stringify({
            "extra_multisig_info": ems
        });

        var nonce = nextNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, mWallet.secretSpendKey);
        //debug my
        console.error("push extra multisig info data: " + data);

        var req = new Request.Request()
            .setMethod("POST")
            .setUrl(getUrl("extra_multisig_info"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .setData(data)
            .onSuccess(getHandler("push extra_multisig_info", function (obj) {
                timer.start();
            }))
            .onError(getStdError("push extra_multisig_info"));

        req.send();
    }

    function changePublicKey(oldSecretKey, callback) {
        var data = JSON.stringify({
            "public_key": mWallet.publicMultisigSignerKey
        });

        var nonce = nextNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, oldSecretKey);

        var req = new Request.Request()
            .setMethod("POST")
            .setUrl(getUrl("change_public_key"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .setData(data)
            .onSuccess(getHandler("change public key", function (obj) {
                //debug my
                console.error("public key changed successfully");
                callback();
            }))
            .onError(getStdError("change public key"));

        req.send();
    }

    function processMultisigInfo(resp) {
        try {
            timer.stop();
            //debug my
            console.error("multisig info response: " + JSON.stringify(resp, null, ' '));

            if (resp.multisig_infos.length !== meta.participantsCount) {
                timer.start();
                return
            }

            var oldSecretKey = mWallet.secretSpendKey;

            var multisig_infos = resp.multisig_infos.map(function (x) {return x.multisig_info});
            var extra_ms_info = mWallet.makeMultisig(multisig_infos, meta.signaturesRequired);
            meta.keysRounds++;
            meta.save();
            keyExchangeRoundPassed(meta.keysRounds);

            if (extra_ms_info) {
                if (stopped) {
                    console.log("multisignature protocol stopped");
                    return;
                }

                changePublicKey(oldSecretKey, function () {
                    pushExtraMultisigInfo(extra_ms_info);
                });
            } else {
                timer.onTriggered.disconnect(exchangeKeys);
                //debug my
                console.error("wallet created. secret key: " + mWallet.secretSpendKey);
                meta.state = "ready";
                meta.save();

                walletCreated();
                changePublicKey(oldSecretKey, function () { });
            }
        } catch (e) {
            timer.start();
            throw e;
        }
    }

    function processExtraMultisigInfo(resp) {
        try {
            timer.stop();
            //debug my
            console.error("extra multisig info response: " + JSON.stringify(resp, null, ' '));

            if (resp.extra_multisig_infos.length !== meta.participantsCount) {
                timer.start()
                return
            }

            //debug my
            console.error("accepting extra multisig info. current state: " + meta.state)
            var oldSecretKey = mWallet.secretSpendKey;
            var multisig_infos = resp.extra_multisig_infos.map(function (x) {return x.extra_multisig_info});
            var extra_ms_info = mWallet.exchangeMultisigKeys(multisig_infos);
            meta.keysRounds++
            keyExchangeRoundPassed(meta.keysRounds);

            if (extra_ms_info) {
                if (stopped) {
                    console.log("multisignature protocol stopped");
                    return;
                }

                changePublicKey(oldSecretKey, function () {
                    pushExtraMultisigInfo(extra_ms_info);
                });
            } else {
                timer.onTriggered.disconnect(exchangeKeys);
                meta.state = "ready";
                meta.save();
                walletCreated();
                changePublicKey(oldSecretKey, function () { });
            }
        } catch (e) {
            timer.start();
            throw e;
        }
    }

    function joinWallet() {
        //debug my
        console.error("joining wallet with invite code: " + inviteCode);

        var data = JSON.stringify({
            "invite_code": inviteCode,
            "multisig_info": mWallet.multisigInfo
        });

        var nonce = nextNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, mWallet.secretSpendKey);
        //debug my
        console.error("join wallet. secret key: " + mWallet.secretSpendKey);

        var req = new Request.Request()
            .setMethod("POST")
            .setUrl(getUrl("join_wallet"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .setData(data)
            .onSuccess(getHandler("join wallet", function (obj) {
                meta.state = "inProgress";
                meta.save();
                joinedToWallet();

                getWalletInfo(infoHandler);
            }))
            .onError(getStdError("join wallet"));

        req.send();
    }

    function getWalletInfo(infoCb) {
        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request()
            .setMethod("GET")
            .setUrl(getUrl("info/wallet"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .onSuccess(getHandler("wallet info", infoCb))
            .onError(getStdError("wallet info"));

        req.send();
    }

    function infoHandler(info) {
        //debug my
        console.error("wallet info response: " + JSON.stringify(info));
        if (meta.signaturesRequired === 0) {
            meta.signaturesRequired = info.signers;
        }

        if (meta.participantsCount === 0) {
            meta.participantsCount = info.participants;
        }

        timer.onTriggered.connect(exchangeKeys);
        timer.start();

        if (stopped) {
            console.log("multisignature protocol stopped");
            return;
        }

        exchangeKeys();
    }

    function onWalletRefreshed() {
        //debug my
        console.error("wallet refreshed. state: " + meta.state + ", sycnhronized: " + mWallet.synchronized + ", exchanging outputs: " + exchangingOutputs);
        if (meta.state !== "ready") {
            return;
        }

        if (!mWallet.synchronized) {
            return;
        }

        if (exchangingOutputs) {
            //debug my
            console.error("another exchanging outputs process");
            return;
        }

        startOutputsExchange();
    }

    function startOutputsExchange() {
        exchangingOutputs = true;

        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request()
            .setMethod("GET")
            .setUrl(getUrl("revision"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .onSuccess(getHandler("static revision number", function (obj) {
                //debug my
                console.error("static revision number: " + obj.revision);
                getProposals(obj.revision);
            }))
            .onError(function (status, text) {
                getStdError("revision")(status, text);
                exchangingOutputs = false;
            });

        req.send();
    }

    function getProposals(staticRevision) {
        //debug my
        console.error("Getting proposals");

        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request()
            .setMethod("GET")
            .setUrl(getUrl("tx_proposals"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .onSuccess(getHandler("transaction proposals", function (props) {
                //debug my
                console.error("props count: " + props.length);

                var hasActive = false;
                for (var i = 0; i < props.length; i++) {
                    var prop = props[i];
                    if (prop.status === "signing") {
                        hasActive = true;
                        activeProposal(prop);
                        //debug my
                        console.error("my key: " + mWallet.publicMultisigSignerKey)
                        break;
                    }
                }

                if (hasActive) {
                    //debug my
                    console.error("has active proposals");
                    exchangingOutputs = false;
                    return;
                } else {
                    activeProposal(null);
                }

                var txCount = 0;
                for (i = 0; i < mWallet.history.count; i++) {
                    var tx = mWallet.history.transaction(i)
                    if (tx.confirmations === 0) {
                        //debug my
                        console.error("have at least one unconfimed transaction");
                        exchangingOutputs = false;
                        return;
                    }

                    if (tx.direction === 0) {
                        txCount += 1;
                    }
                }

                var n = staticRevision + txCount;
                if (props.length) {
                    n += props.length;
                }

                //debug my
                console.error("n: " + n + ", last n: " + meta.lastOutputsRevision);
                if (n > meta.lastOutputsRevision) {
                    exchangeOutputs(n);
                } else if (meta.lastOutputsImported === 0) {
                    importOutputs(meta.lastOutputsRevision);
                } else {
                    exchangingOutputs = false;
                    //debug my
                    console.error("nothing is changed, no need to export. has partial key images: " + mWallet.hasMultisigPartialKeyImages());
                }
            }))
            .onError(function (status, text) {
                getStdError("tx_proposals")(status, text);
                exchangingOutputs = false;
            });

        req.send();
    }

    function exchangeOutputs(n) {
        //debug my
        console.error("trying to exchange outputs w/ n = " + n);
        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request()
            .setMethod("HEAD")
            .setUrl(getUrl("outputs_extended/" + n))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .onSuccess(getHandler("check outputs_extended", function () {
                sendOutputs(n);
            }))
            .onError(function (status, text) {
                switch (status) {
                case 0:
                    //stupid JS returns 0 status code if this request fails with 4xx code
                    console.warn("can't exchange outputs");
                    break;
                case 400:
                    console.log("can't exchange outputs: revision is too small - " + n);
                    //debug my
                    console.error("can't exchange outputs: revision is too small - " + n);
                    break;
                case 409:
                    console.log("can't exchange outputs: outputs from this wallet have already been sent");
                    //debug my
                    console.error("can't exchange outputs: outputs from this wallet have already been sent");
                    break;
                case 412:
                    console.log("can't exchange outputs: there is active proposal");
                    //debug my
                    console.error("can't exchange outputs: there is active proposal");
                    break;
                default:
                    console.warn("can't exchange outputs: unknown HTTP status - " + status + ", " + text);
                    break;
                }

                exchangingOutputs = false;
            });

        req.send();
    }

    function sendOutputs(n) {
        //debug my
        console.error("sending outputs");
        var outputs = mWallet.exportMultisigImages();
        var data = JSON.stringify({
            "outputs": outputs
        });

        var nonce = nextNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request()
            .setMethod("POST")
            .setUrl(getUrl("outputs_extended/" + n))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .setData(data)
            .onSuccess(getHandler("export outputs", function () {
                console.log("outputs exported successfully");
                meta.lastOutputsRevision = n;
                meta.lastOutputsImported = 0;
                meta.save();
                exchangingOutputs = false;
                //debug my
                console.error("outputs exported successfully");
            }))
            .onError(function (status, text) {
                getStdError("export outputs")(status, text);
                exchangingOutputs = false;
            });

        req.send();
    }

    function importOutputs(n) {
        var handler = getHandler("import outputs", function (obj) {
            var outputs = obj.outputs;

            var hasHigherRevision = false;
            var toImport = [];
            for (var i = 0; i < outputs.length; i++) {
                var out = outputs[i];
                if (out[1] > n) {
                    hasHigherRevision = true;
                    console.warn("Higher outputs revision found. Max: " + out[1] + ", we have: " + n);
                    return;
                }

                if (out[1] === n) {
                    toImport.push(out[0]);
                }
            }

            if (toImport.length < meta.signaturesRequired) {
                console.log("Not enough participants exported their outputs (" + toImport.length + " of at least " + meta.signaturesRequired + "). Postponing import");
                //debug my
                console.error("Not enough participants exported their outputs (" + toImport.length + " of at least " + meta.signaturesRequired + "). Postponing import");
                return;
            }

            var imported = mWallet.importMultisigImages(toImport); //TODO: exception???
            meta.lastOutputsImported = toImport.length;
            meta.save();
            console.log("imported " + imported + " outputs of " + meta.participantsCount + " participants");
            //debug my
            console.error("imported " + imported + " outputs of " + meta.participantsCount + " participants");
        });

        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request()
            .setMethod("GET")
            .setUrl(getUrl("outputs_extended"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .onSuccess(function (obj) {
                handler(obj);
                exchangingOutputs = false;
            })
            .onError(function (status, text) {
                getStdError("import outputs")(status, text);
                exchangingOutputs = false;
            });

        req.send();
    }

    function sendProposalAsync(proposal) {
//        meta.unsentProposal = proposal;

        var data = JSON.stringify({
            "destination_address": proposal.destination_address,
            "description": proposal.description,
            "signed_transaction": proposal.signed_transaction,
            "amount": proposal.amount,
            "fee": proposal.fee
        });

        var nonce = nextNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request()
            .setMethod("POST")
            .setUrl(getUrl("tx_proposals"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .setData(data)
            .onSuccess(function (obj) {
                var id = obj.proposal_id || -1;
                proposalSent(id);
                meta.unsentProposal = "";
            })
            .onError(function (status, text) {
                console.error("failed to send proposal (http status " + status + "): " + text);

                switch (status) {
                case 409:
                    sendProposalError(text);
                    meta.unsentProposal = "";
                    break;
                default:
                    //TODO: retry send on timer
                    sendProposalError(text);
                    meta.unsentProposal = "";
                    break;
                }
            });

        req.send();
    }

    property var pendingDecision
    function sendProposalDecisionAsync(approve, proposal) {
        //TODO: stop trying to send decision on already finished proposal
        pendingDecision = {
            "decision": approve,
            "proposal_id": proposal.proposal_id,
            "signing_data": proposal.last_signed_transaction,
            "approved": proposal.approvals.length,
            "state": "pending",
        }

        if (!approve) {
            pendingDecision.state = "locking";
            sendProposalDecision();
            return;
        }

        pendingDecision.state = "restoring";
        mWallet.restoreMultisigTxAsync(pendingDecision.signing_data);
    }

    function sendProposalDecision() {
        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request()
            .setMethod("HEAD")
            .setUrl(getUrl("tx_proposals/" + pendingDecision.proposal_id + "/decision"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .onSuccess(getHandler("proposal decision lock", function (obj) {
                var decision = {
                    "approved": pendingDecision.decision,
                    "approval_nonce": pendingDecision.approved,
                    "signed_transaction": "",
                }

                if (pendingDecision.decision) {
                    decision.signed_transaction = pendingDecision.signing_data;
                }

                doSendDecision(decision);
            }))
            .onError(function (status, text) {
                pendingDecision.state = "pending";
                //TODO: run timer to check periodically
            });

        req.send();
    }

    function doSendDecision(decision) {
        var data = JSON.stringify(decision);
        var nonce = nextNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request()
            .setMethod("PUT")
            .setUrl(getUrl("tx_proposals/" + pendingDecision.proposal_id + "/decision"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .setData(data)
            .onSuccess(getHandler("proposal decision", function (obj) {
                //debug my
                console.error("proposal successfully sent");
                pendingDecision.state = "sent";

                //TODO: emit signal
                //TODO: increment revision's static counter
            }))
            .onError(function (status, text) {
                //debug my
                console.warn("failed to send proposal decision (" + status + "): " + text)
                if (status === 409) {
                    pendingDecision.state = "pending";
                    return;
                }

                //TODO: emit signal
                //TODO: increment revision's static counter
                pendingDecision = null;
            });

        req.send();
    }

    function onMultisigTxRestored(pendingTransaction) {
        if (!pendingTransaction) {
            console.error("wallet couldn't restore multisig transaction");
        }

        //debug my
        console.error("multisig transaction successfully restored");

        pendingTransaction.signMultisigTx();
        if (pendingTransaction.status != 0) {
            console.error("failed to sign multisig transaction: " + pendingTransaction.errorString);
            pendingDecision = null;
            //TODO: notify callback
            return;
        }

        pendingDecision.signing_data = pendingTransaction.multisigSignData();
        sendProposalDecision();

        //debug my
        console.error("committing transaction " + pendingTransaction.txid[0]);
        mWallet.commitTransactionAsync(pendingTransaction);
    }

    function sendTransactionResult(success, txid) {
        if (!success) {
            pendingDecision = null;
            return;
        }

        var data = JSON.stringify({
            "tx_id": txid,
        });
        var nonce = nextNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, mWallet.secretSpendKey);

        //debug my
        console.error("transaction committed, tx hash: " + txid + ", sending relay status");

        var req = new Request.Request()
            .setMethod("POST")
            .setUrl(getUrl("tx_relay_status/" + pendingDecision.proposal_id))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .setData(data)
            .onSuccess(getHandler("tx relay status", function (obj) {
                //debug my
                console.error("proposal successfully sent");
                pendingDecision = null;
            }))
            .onError(getStdError("tx relay status"));

        req.send();
    }

    function getUrl(method) {
        return mwsUrl + apiVersion + method
    }

    function nextNonce() {
        return nonce++;
    }

    function getHeaders(session, nonce, signature) {
        return {
            'X-Session-Id': session,
            'X-Nonce': nonce,
            'X-Signature': signature
        }
    }

    function getHandler(name, func) {
        return function(resp) {
            try {
                if (stopped) {
                    console.log("multisignature protocol stopped");
                    return
                }

                if (resp) {
                    func(JSON.parse(resp));
                } else {
                    func(null);
                }

            } catch (e) {
                console.error("failed to process " + name + " response: " + e);
                error("failed to process " + name + " response: " + e);
            }
        }
    }

    function getStdError(ctxMsg) {
        return function (status, text) {
            var msg = ctxMsg + ": ";
            if (status) {
                msg += "HTTP error ("+ status + " status code): "
            }

            msg += text;
            console.error(msg);
            error(msg);
        }
    }
}
