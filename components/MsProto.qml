pragma Singleton

import QtQuick 2.0

import "../js/Request.js" as Request

QtObject {
    property string mwsUrl: "https://mws-stage.exan.tech/"
    property string apiVersion: "api/v1/"

    property string state
    property var mWallet
    property int signaturesRequired
    property int participantsCount
    property int changedKeys: 0
    property int nonce: 1
    property bool newWallet: false
    property string inviteCode
    property bool stopped: false

    property int prevTxCount //???
    property int prevProposalsCount //???
    property int lastN: 0

    property string sessionId

    signal sessionOpened
    signal inviteCodeReceived(string inviteCode)
    signal keyExchangeRoundPassed(int newRoundNumber)
    signal joinedToWallet
    signal walletCreated
    signal error(string msg)

    property Timer timer: Timer{
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
        }

        stopped = true;
        mWallet = null;
        state = "";
        signaturesRequired = 0;
        participantsCount = 0;
        sessionId = "";
        inviteCode = "";
    }

    function start() {
        if (!mWallet) {
            throw "wallet must be set";
        }

        if (state == "personal" && (signaturesRequired == 0 || participantsCount == 0)) {
            throw "signatures and participants count are both required for newly created wallets";
        }

        if (sessionId != "") {
            throw "multisignature protocol already started";
        }

        mWallet.refreshed.connect(onWalletRefreshed)

        stopped = false;
        openSession();
    }

    function onOpenSessionResponse() {
        sessionOpened(); // emit signal
        //debug my
        console.error("session opened. current state: " + state)

        switch (state) {
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
            console.error("unknown multisignature state: " + state);
        }
    }

    function openSession() {
        var signerKey = mWallet.publicSpendKey;
        if (changedKeys > 0) {
            signerKey = mWallet.publicMultisigSignerKey;
        }

        //debug my
        console.error("openning session. public key: " + signerKey);
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
            'signers': signaturesRequired,
            'participants': participantsCount,
            'multisig_info': mWallet.multisigInfo,
            'name': name,
        });

        var nonce = nextNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, mWallet.secretSpendKey);
        //debug my
        console.error("create wallet. secret key: " + mWallet.secretSpendKey);

        var req = new Request.Request()
            .setMethod("POST")
            .setUrl(getUrl("create_wallet"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .setData(data)
            .onSuccess(getHandler("create wallet", function (obj) {
                inviteCodeReceived(obj.invite_code);
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
        console.error("exchange keys. changed keys: " + changedKeys);

        var url = getUrl("info/multisig");
        var name = "multisig info";
        var callback = processMultisigInfo;
        if (changedKeys > 0) {
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

        //debug my
        console.error("changing public key: " + data);

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

            if (resp.multisig_infos.length !== participantsCount) {
                timer.start();
                return
            }

            var oldSecretKey = mWallet.secretSpendKey;

            //debug my
            console.error("accepting multisig info. current state: " + state)
            var multisig_infos = resp.multisig_infos.map(function (x) {return x.multisig_info});
            var extra_ms_info = mWallet.makeMultisig(multisig_infos, signaturesRequired);
            changedKeys++;
            keyExchangeRoundPassed(changedKeys);

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
                state = "ready";
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

            if (resp.extra_multisig_infos.length !== participantsCount) {
                timer.start()
                return
            }

            //debug my
            console.error("accepting extra multisig info. current state: " + state)
            var oldSecretKey = mWallet.secretSpendKey;
            var multisig_infos = resp.extra_multisig_infos.map(function (x) {return x.extra_multisig_info});
            var extra_ms_info = mWallet.exchangeMultisigKeys(multisig_infos);
            changedKeys++
            keyExchangeRoundPassed(changedKeys);

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
                state = "ready";
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
        if (signaturesRequired == 0) {
            signaturesRequired = info.signers;
        }

        if (participantsCount == 0) {
            participantsCount = info.participants;
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
        if (state !== "ready") {
            return;
        }

        if (!mWallet.synchronized) {
            return
        }

//        var currentTxCount = mWallet.history.count;
//        if (currentTxCount > prevTxCount) {
//            prevTxCount = currentTxCount
//            // need export
//        }

        getProposals();
    }

    function getProposals() {
        //debug my
        console.error("Getting proposals");
        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request()
            .setMethod("GET")
            .setUrl(getUrl("tx_proposals"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .onSuccess(getHandler("transaction proposals", function (props) {
                var hasActive = false;
                for (var i = 0; i < props.length; i++) {
                    var prop = props[i];
                    if (prop.status === "signing") {
                        hasActive = true;
                        break;
                    }
                }

                if (hasActive) {
                    //debug my
                    console.error("has active proposals");
                    return;
                }

                var txCount = mWallet.history.count;
                if (txCount > 0) {
                    var lastTx = mWallet.history.transaction(txCount - 1);
                    if (lastTx.confirmations === 0) {
                        //debug my
                        console.error("have at least one unconfimed transaction");
                        return;
                    }
                }

                var n = props.length + txCount;
                if (n > lastN) {
                    // outputs exchange needed
                }
            }))
            .onError(getStdError("tx_proposals"));

        req.send();
    }

    function exchangeOutputs(n) {
        //debug my
        console.error("trying to exchange outputs");
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
                    console.warn("can't exchange outputs: to connection to server");
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
                    console.warn("can't exchange outputs: unknown HTTP status - " + status);
                    break;
                }
            });
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
                lastN = n;
                //debug my
                console.error("outputs exported successfully");
                importOutputs(n);
            }))
            .onError(getStdError("export outputs"));

        req.send();
    }

    function importOutputs(n) {
        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request()
            .setMethod("GET")
            .setUrl(getUrl("outputs_extended"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .onSuccess(getHandler("import outputs", function (obj) {
                var outputs = obj.outputs;

                var hasHigherRevision = false;
                var toImport = [];
                for (i = 0; i < outputs.length; i++) {
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

                if (toImport.length < signaturesRequired) {
                    console.log("Not enough participants exported their outputs (" + toImport + " of at least " + signaturesRequired + "). Postponing import");
                    //debug my
                    console.error("Not enough participants exported their outputs (" + toImport + " of at least " + signaturesRequired + "). Postponing import");
                    return;
                }

                var imported = mWallet.importMultisigImages(toImport); //TODO: exception???
                console.log("imported " + imported + " outputs of " + participantsCount + " participants");
                //debug my
                console.error("imported " + imported + " outputs of " + participantsCount + " participants");
            }))
            .onError(getStdError("import outputs"));

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
