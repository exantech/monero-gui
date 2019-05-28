pragma Singleton

import QtQuick 2.0

import "../js/Request.js" as Request

QtObject {
    property string mwsUrl: "https://mws-stage.exan.tech/"
    property string apiVersion: "api/v1/"

    property var mWallet
    property int signaturesCount
    property int participantsCount
    property int msLevel: 0

    property string sessionId
//    property string state

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

    function openSession(signerKey) {
        console.error("openning session. public key: " + signerKey);
        var data = JSON.stringify({
            'public_key': signerKey
        });

        var req = new Request.Request()
            .setMethod("POST")
            .setUrl(getUrl("open_session"))
            .setData(data)
            .onSuccess(function(resp) {
                try {
                    var obj = JSON.parse(resp);
                    if (!obj.session_id) {
                        error("unexpected \"open_session\" response: " + resp);
                    }

                    sessionId = obj.session_id;
                    sessionOpened();
                } catch (e) {
                    error("failed to process \"open_session\" response: " + e);
                }
            })
            .onError(function(status, text) {
                var msg = "failed to open session (HTTP status " + status + ")";
                if (text) {
                    msg += ": " + text;
                }

                console.error(msg);
                error(msg);
            });

        req.send();
    }

    function createWallet(wallet, name, signatures, participants) {
        // session must be opened
        if (!wallet) {
            error("Wallet is null");
            return;
        }

        mWallet = wallet
        signaturesCount = signatures
        participantsCount = participants

        //debug my
        console.error("sending create wallet request");

        var data = JSON.stringify({
            'signers': signatures,
            'participants': participants,
            'multisig_info': wallet.multisigInfo,
            'name': name,
        });

        var nonce = nextNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, wallet.secretSpendKey);

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
                    timer.onTriggered.connect(checkMultisigInfos);
                    timer.start();
                } catch (e) {
                    //debug my
                    console.error("failed to process response: " + e);
                    error("failed to process response: " + e);
                }
            })
            .onError(function(status, text) {
                //debug my
                console.error("fail: " + text);
                var msg = "\"create_wallet\" HTTP status " + status;
                if (text) {
                    msg += ". error: " + text;
                }

                error(msg);
            });

        req.send();
    }

    function checkMultisigInfos() {
        //debug my
        console.error("Checking multisig infos");
        // session must be opened
        if (!mWallet) {
            error("Wallet is null");
            return;
        }

        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request()
            .setMethod("GET")
            .setUrl(getUrl("info/multisig"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .onSuccess(function (resp) {
                timer.stop();
                //debug my
                console.error("multisig info response: " + resp);

                try {
                    var obj = JSON.parse(resp);
                    if (obj.multisig_infos.length !== participantsCount) {
                        timer.start()
                        return
                    }

                    var multisig_infos = obj.multisig_infos.map(function (x) {return x.multisig_info});
                    var extra_ms_info = mWallet.makeMultisig(multisig_infos, signaturesCount);
                    msLevel++

                    if (extra_ms_info) {
                        // next round
                        //TODO: implement it
                        // wallet created
                        error("Multisignature schemes other than N/N are currently unsupported");
                    } else {
                        walletCreated();
                    }
                } catch (e) {
                    //debug my
                    console.error("failed to process response: " + e);
                    error("failed to process response: " + e);
                    timer.start();
                }
            })
            .onError(function (status, text) {
                var msg = "failed to check multisig info (HTTP status " + status + ")";
                if (text) {
                    msg += ": " + text;
                }

                console.error(msg);
                error(msg);
            });

        req.send();
    }

    function getUrl(method) {
        return mwsUrl + apiVersion + method
    }

    function nextNonce() {
        return new Date().getTime();
    }

    function getHeaders(session, nonce, signature) {
        return {
            'X-Session-Id': session,
            'X-Nonce': nonce,
            'X-Signature': signature
        }
    }
}
