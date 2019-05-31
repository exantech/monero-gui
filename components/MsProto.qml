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

    property string sessionId

    signal sessionOpened
    signal inviteCodeReceived(string inviteCode)
    signal walletCreated
    signal error(string msg)

    property Timer timer: Timer{
        interval: 2000
        running: false
        repeat: true
        triggeredOnStart: false
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

        openSession(mWallet.publicSpendKey);
    }

    function onOpenSessionResponse() {
        sessionOpened(); // emit signal

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

    function openSession(signerKey) {
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
        //debug my
        console.error("sending create wallet request");

        var data = JSON.stringify({
            'signers': signaturesRequired,
            'participants': participantsCount,
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
            .onSuccess(function(resp) {
                //debug my
                console.error("create wallet response: " + resp);
                try {
                    var obj = JSON.parse(resp);
                    inviteCodeReceived(obj.invite_code);
                    timer.onTriggered.connect(exchangeKeys);
                    timer.start();
                } catch (e) {
                    //debug my
                    console.error("failed to process response: " + e);
                    error("failed to process response: " + e);
                }
            })
            .onError(getStdError("create wallet"));

        req.send();
    }

    function exchangeKeys() {
        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);

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

    function processMultisigInfo(resp) {
        try {
            timer.stop();
            //debug my
            console.error("multisig info response: " + JSON.stringify(resp, null, ' '));

            if (resp.multisig_infos.length !== participantsCount) {
                timer.start()
                return
            }

            var multisig_infos = resp.multisig_infos.map(function (x) {return x.multisig_info});
            var extra_ms_info = mWallet.makeMultisig(multisig_infos, signaturesRequired);
            changedKeys++

            if (extra_ms_info) {
                exchangeKeys();
            } else {
                timer.onTriggered.disconnect(exchangeKeys);
                walletCreated();
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

            var multisig_infos = resp.extra_multisig_infos.map(function (x) {return x.extra_multisig_info});
            var extra_ms_info = mWallet.exchangeMultisigKeys(multisig_infos);
            changedKeys++

            if (extra_ms_info) {
                exchangeKeys();
            } else {
                timer.onTriggered.disconnect(exchangeKeys);
                walletCreated();
            }
        } catch (e) {
            timer.start();
            throw e;
        }
    }

    function getWalletInfo(infoCb) {
        //debug my
        console.error("sending info/wallet request");

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

    function joinWallet() {
        //debug my
        console.error("joining wallet with invite code: " + inviteCode);

        var data = JSON.stringify({
            "invite_code": inviteCode,
            "multisig_info": mWallet.multisigInfo
        });

        var nonce = nextNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request()
            .setMethod("POST")
            .setUrl(getUrl("join_wallet"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .setData(data)
            .onSuccess(getHandler("join wallet", function (obj) {
                getWalletInfo(infoHandler)
            }))
            .onError(getStdError("join wallet"));

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

        changedKeys = info.changed_keys

        timer.onTriggered.connect(exchangeKeys);
        timer.start();

        exchangeKeys();
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
