pragma Singleton

import QtQuick 2.0

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
        var data = {
            'public_key': signerKey
        }

        makeRequest(
            "POST",
            getUrl("open_session"),
            JSON.stringify(data),
            null,
            function(resp) {
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
            },
            function(status, text) {
                var msg = "failed to open session (HTTP status " + status + ")";
                if (text) {
                    msg += ": " + text;
                }

                console.error(msg);
                error(msg);
            });
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

        var nonce = getNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, wallet.secretSpendKey);

        makeRequest(
            "POST",
            getUrl("create_wallet"),
            data,
            getHeaders(sessionId, nonce, signature),
            function(resp) {
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
            },
            function(status, text) {
                //debug my
                console.error("fail: " + text);
                var msg = "\"create_wallet\" HTTP status " + status;
                if (text) {
                    msg += ". error: " + text;
                }

                error(msg);
            });
    }

    function checkMultisigInfos() {
        //debug my
        console.error("Checking multisig infos");
        // session must be opened
        if (!mWallet) {
            error("Wallet is null");
            return;
        }

        var nonce = getNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);

        makeRequest("GET", getUrl("info/multisig"), null, getHeaders(sessionId, nonce, signature),
            function (resp) {
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
            },
            function (status, text) {
                var msg = "failed to check multisig info (HTTP status " + status + ")";
                if (text) {
                    msg += ": " + text;
                }

                console.error(msg);
                error(msg);
            })
    }

    function makeRequest(method, url, data, headers, successCb, errorCb) {
        var req = new XMLHttpRequest();
        req.open(method, url);
        req.onreadystatechange = function () {
            if (req.readyState === 4) { //request done
                if (req.status === 200 || req.status === 204) {
                    if (successCb) {
                        successCb(req.responseText);
                    }
                } else {
                    if (errorCb) {
                        errorCb(req.status, req.responseText);
                    }
                }
            }
        }

        for (var k in headers) {
            req.setRequestHeader(k, headers[k])
        }

        req.send(data);
    }

    function getUrl(method) {
        return mwsUrl + apiVersion + method
    }

    function getNonce() {
        return 1;
    }

    function getHeaders(session, nonce, signature) {
        return {
            'X-Session-Id': session,
            'X-Nonce': nonce,
            'X-Signature': signature
        }
    }
}
