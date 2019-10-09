pragma Singleton

import QtQuick 2.0

import "../js/Request.js" as Request
import moneroComponents.NetworkType 1.0

QtObject {
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

    signal proposalChanged(var prop)

    signal proposalSent(int id)
    signal sendProposalError(string message);

    signal proposalDecisionSent()
    signal proposalDecisionError(string message)

    property var activeProposal: null;
    property int staticRevision: 0;

    property Timer timer: Timer{
        interval: 2000
        running: false
        repeat: true
        triggeredOnStart: false
    }

    onActiveProposalChanged: {
        proposalChanged(activeProposal);
    }

    function stop() {
        if (stopped) {
            return
        }

        console.info("Stopping protocol");
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

        if (!meta) {
            throw "no multisignature meta assigned, check if your wallet's meta file exists";
        }

        if (!meta.mwsUrl) {
            if (mWallet.nettype == NetworkType.MAINNET) {
                meta.mwsUrl = "https://mws.exan.tech/";
            } else if (mWallet.nettype == NetworkType.STAGENET) {
                meta.mwsUrl = "https://mws-stage.exan.tech/";
            } else {
                throw "mws url is not set";
            }
        }

        mWallet.refreshed.connect(onWalletRefreshed)
        mWallet.multisigTxRestored.connect(onMultisigTxRestored)

        stopped = false;
        openSession();
    }

    function onOpenSessionResponse() {
        sessionOpened();
        console.info("session opened.")

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

        console.info("openning session...");
        var data = JSON.stringify({
            'public_key': signerKey
        });

        var req = new Request.Request(httpFactory.createHttpClient())
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

        var req = new Request.Request(httpFactory.createHttpClient())
            .setMethod("POST")
            .setUrl(getUrl("create_wallet"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .setData(data)
            .onSuccess(getHandler("create wallet", function (obj) {
                meta.state = "inProgress";
                meta.save();

                inviteCodeReceived(obj.invite_code);
                console.info("invite code: " + obj.invite_code);
                timer.onTriggered.connect(exchangeKeys);
                timer.start();
            }))
            .onError(getStdError("create wallet"));

        req.send();
    }

    function exchangeKeys() {
        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);
        console.info("exchange keys. changed keys: " + meta.keysRounds);

        var url = getUrl("info/multisig");
        var name = "multisig info";
        var callback = processMultisigInfo;
        if (meta.keysRounds > 0) {
            url = getUrl("info/extra_multisig");
            name = "extra multisig info";
            callback = processExtraMultisigInfo;
        }

        var req = new Request.Request(httpFactory.createHttpClient())
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
        console.info("pushing extra multisig info");

        var req = new Request.Request(httpFactory.createHttpClient())
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

        var req = new Request.Request(httpFactory.createHttpClient())
            .setMethod("POST")
            .setUrl(getUrl("change_public_key"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .setData(data)
            .onSuccess(getHandler("change public key", function (obj) {
                console.info("public key changed successfully");
                callback();
            }))
            .onError(getStdError("change public key"));

        req.send();
    }

    function processMultisigInfo(resp) {
        try {
            timer.stop();

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
                console.info("wallet created");
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

            if (resp.extra_multisig_infos.length !== meta.participantsCount) {
                timer.start()
                return
            }

            console.info("accepting extra multisig info. current state: " + meta.state)
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
        console.info("joining wallet with invite code: " + inviteCode);

        var data = JSON.stringify({
            "invite_code": inviteCode,
            "multisig_info": mWallet.multisigInfo
        });

        var nonce = nextNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request(httpFactory.createHttpClient())
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

        var req = new Request.Request(httpFactory.createHttpClient())
            .setMethod("GET")
            .setUrl(getUrl("info/wallet"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .onSuccess(getHandler("wallet info", infoCb))
            .onError(getStdError("wallet info"));

        req.send();
    }

    function infoHandler(info) {
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
        if (meta.state !== "ready") {
            return;
        }

        if (!mWallet.synchronized) {
            return;
        }

        if (exchangingOutputs) {
            console.info("another exchanging outputs process");
            return;
        }

        startOutputsExchange();
    }

    function startOutputsExchange() {
        exchangingOutputs = true;

        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request(httpFactory.createHttpClient())
            .setMethod("GET")
            .setUrl(getUrl("revision"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .onSuccess(getHandler("static revision number", function (obj) {
                console.info("static revision number: " + obj.revision);
                staticRevision = obj.revision;
                getProposals();
            }))
            .onError(function (status, text) {
                getStdError("revision")(status, text);
                exchangingOutputs = false;
            });

        req.send();
    }

    function getProposals() {
        console.info("Getting proposals");

        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request(httpFactory.createHttpClient())
            .setMethod("GET")
            .setUrl(getUrl("tx_proposals"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .onSuccess(getHandler("transaction proposals", function (props) {
                console.info("props count: " + props.length);

                var hasActive = false;
                for (var i = 0; i < props.length; i++) {
                    var prop = props[i];
                    if (prop.status === "signing") {
                        hasActive = true;
                        prop["answered"] = alredyAnswered(prop);
                        activeProposal = prop;
                        break;
                    }
                }

                if (!hasActive) {
                    activeProposal = null;
                }

                processOutputsExchangeState();
            }))
            .onError(function (status, text) {
                getStdError("tx_proposals")(status, text);
                exchangingOutputs = false;
            });

        req.send();
    }

    function alredyAnswered(prop) {
        if (prop.approvals.find(function (e) { return e == mWallet.publicMultisigSignerKey; }) ||
                prop.rejects.find(function (e) { return e == mWallet.publicMultisigSignerKey; })) {
            return true;
        }

        return false;
    }

    function processOutputsExchangeState() {
        var uniq = {};
        for (var i = 0; i < mWallet.history.count; i++) {
            var tx = mWallet.history.transaction(i)
            if (tx.confirmations === 0) {
                console.info("have at least one unconfimed transaction");
                exchangingOutputs = false;
                return;
            }

            uniq[tx.hash] = 1;
        }

        console.info("static revision number: " + staticRevision);
        var txCount = Object.keys(uniq).length;
        console.info("tx count: " + txCount);
        var n = staticRevision + txCount;

        if (activeProposal != null) {
            if (meta.lastOutputsImported === 0) {
                console.info("has active proposal, but import operation isn't finished. trying to import outputs neverthless");

                // let's consider the following case:
                // we have 2/2 multisig wallet. all of participants synced their outputs. then:
                // * tx came and triggered participant #1 to export his outputs
                // * participant #2 exported his outputs and then imported outputs from #1
                // * participant #2 creates transaction proposal and sends it
                // * participant #1 receives it and cannot import outputs since there is active proposal at the moment;
                // since proposal creator could have incremented static revision number already
                // we shouldn't perform export outputs to not delete our current one-time keys
                // which are already used in the transaction proposal.
                importOutputs(meta.lastOutputsRevision);
                return
            }

            console.info("has active proposal, postponing outputs exchange");
            exchangingOutputs = false;
            return;
        }

        console.info("n: " + n + ", last n: " + meta.lastOutputsRevision);
        if (n > meta.lastOutputsRevision) {
            exchangeOutputs(n);
        } else if (meta.lastOutputsImported < meta.participantsCount) {
            importOutputs(meta.lastOutputsRevision);
        } else {
            exchangingOutputs = false;
            console.info("nothing is changed, no need to export. has partial key images: " + mWallet.hasMultisigPartialKeyImages());
        }
    }

    function exchangeOutputs(n) {
        console.info("trying to exchange outputs w/ n = " + n);
        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request(httpFactory.createHttpClient())
            .setMethod("HEAD")
            .setUrl(getUrl("outputs_extended/" + n))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .onSuccess(getHandler("check outputs_extended", function () {
                sendOutputs(n);
            }))
            .onError(function (status, text) {
                switch (status) {
                case 0:
                    console.warn("can't exchange outputs");
                    break;
                case 400:
                    console.error("can't exchange outputs: revision is too small - " + n);
                    break;
                case 409:
                    console.error("can't exchange outputs: outputs from this wallet have already been sent");
                    break;
                case 412:
                    console.warn("can't exchange outputs: there is active proposal");
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
        console.info("sending outputs");
        var outputs = mWallet.exportMultisigImages();
        var data = JSON.stringify({
            "outputs": outputs
        });

        var nonce = nextNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request(httpFactory.createHttpClient())
            .setMethod("POST")
            .setUrl(getUrl("outputs_extended/" + n))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .setData(data)
            .onSuccess(getHandler("export outputs", function () {
                meta.lastOutputsRevision = n;
                meta.lastOutputsImported = 0;
                meta.save();
                console.info("outputs exported successfully. Checking for import");
                importOutputs(n);
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

            var toImport = [];
            for (var i = 0; i < outputs.length; i++) {
                var out = outputs[i];
                if (out[1] > n) {
                    console.warn("Higher outputs revision found. Max: " + out[1] + ", we have: " + n);
                    return;
                }

                if (out[1] === n) {
                    toImport.push(out[0]);
                }
            }

            if (toImport.length < meta.signaturesRequired) {
                console.info("Not enough participants exported their outputs (" + toImport.length + " of at least " + meta.signaturesRequired + "). Postponing import");
                return;
            }

            if (meta.lastOutputsImported >= toImport.length) {
                console.info("Last outputs imported: " + meta.lastOutputsImported + ", ready to import: " + toImport.length + ". No new outputs available");
                return;
            }

            var imported = mWallet.importMultisigImages(toImport); //TODO: check status
            meta.lastOutputsImported = toImport.length;
            meta.save();
            console.info("imported " + imported + " outputs of " + meta.participantsCount + " participants");
        });

        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request(httpFactory.createHttpClient())
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
        var data = JSON.stringify({
            "destination_address": proposal.destination_address,
            "description": proposal.description,
            "signed_transaction": proposal.signed_transaction,
            "amount": proposal.amount,
            "fee": proposal.fee
        });

        var nonce = nextNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request(httpFactory.createHttpClient())
            .setMethod("POST")
            .setUrl(getUrl("tx_proposals"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .setData(data)
            .onSuccess(function (obj) {
                var id = obj.proposal_id || -1;
                proposalSent(id);

                proposal.approvals = [mWallet.publicMultisigSignerKey];
                proposal.rejects = [];
                proposal.answered = true;
                activeProposal = proposal;

                incStaticRevision();
            })
            .onError(function (status, text) {
                console.error("failed to send proposal (http status " + status + "): " + text);

                switch (status) {
                case 409:
                    sendProposalError("There is active proposal. Two unfinished transaction proposals can't exist at the same time.");
                    console.warn("failed to post proposal: " + text)
                    break;
                default:
                    //TODO: retry send on timer
                    sendProposalError(text);
                    console.warn("failed to post proposal: " + text);
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

        var req = new Request.Request(httpFactory.createHttpClient())
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
                    decision.signed_transaction = pendingDecision.pending_transaction.multisigSignData();
                }

                doSendDecision(decision);
            }))
            .onError(function (status, text) {
                if (status == 409) {
                    pendingDecision = null;
                    proposalDecisionError("Someone else is trying to sign this transaction proposal. Please try again in a minute");
                    return;
                }

                pendingDecision.state = "pending";
                proposalDecisionError("Failed to send proposal decision: " + text);
            });

        req.send();
    }

    function doSendDecision(decision) {
        var data = JSON.stringify(decision);
        var nonce = nextNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request(httpFactory.createHttpClient())
            .setMethod("PUT")
            .setUrl(getUrl("tx_proposals/" + pendingDecision.proposal_id + "/decision"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .setData(data)
            .onSuccess(getHandler("proposal decision", function (obj) {
                console.info("proposal successfully sent");
                pendingDecision.state = "sent";

                if (activeProposal.approvals.length + 1 == meta.signaturesRequired && decision.approved) {
                    console.info("committing transaction " + pendingDecision.pending_transaction.txid[0]);
                    //TODO: make the call after sending proposal decision?
                    mWallet.commitTransactionAsync(pendingDecision.pending_transaction);
                    return;
                }

                proposalDecisionSent();
            }))
            .onError(function (status, text) {
                console.warn("failed to send proposal decision (" + status + "): " + text)
                pendingDecision = null;
                if (status === 409) {
                    pendingDecision.state = "pending";
                    proposalDecisionError("Someone else is trying to sign this transaction proposal. Please try again in a minute");
                    return;
                }

                proposalDecisionError("Failed to send proposal decision: " + text);
            });

        req.send();
    }

    function onMultisigTxRestored(pendingTransaction) {
        if (!pendingTransaction) {
            console.error("wallet couldn't restore multisig transaction");
            return;
        }

        if (mWallet.status != 0) {
            console.error("failed to restore multisig transaction: " + mWallet.errorString);
            //TODO: notify callback
            return;
        }

        console.info("multisig transaction successfully restored");

        pendingTransaction.signMultisigTx();
        if (pendingTransaction.status != 0) {
            console.error("failed to sign multisig transaction: " + pendingTransaction.errorString);
            pendingDecision = null;
            error("failed to sign multisig transaction: " + pendingTransaction.errorString);
            //TODO: notify callback
            return;
        }

        pendingDecision["pending_transaction"] = pendingTransaction;
        sendProposalDecision();
    }

    function sendTransactionResult(success, txid) {
        if (!success) {
            // failed transaction send is handled in main.qml
            pendingDecision = null;
            return;
        }

        var data = JSON.stringify({
            "tx_id": txid,
        });
        var nonce = nextNonce();
        var signature = walletManager.signMessage(data + sessionId + nonce, mWallet.secretSpendKey);

        console.info("transaction committed, tx hash: " + txid + ", sending relay status");

        var req = new Request.Request(httpFactory.createHttpClient())
            .setMethod("POST")
            .setUrl(getUrl("tx_relay_status/" + pendingDecision.proposal_id))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .setData(data)
            .onSuccess(getHandler("tx relay status", function (obj) {
                console.info("proposal successfully sent");
                pendingDecision = null;
            }))
            .onError(getStdError("tx relay status"));

        req.send();
    }

    function isUpdated() {
        return meta.lastOutputsImported !== 0 &&
               activeProposal == null;
    }

    function incStaticRevision() {
        console.info("incrementing revision static counter");

        var nonce = nextNonce();
        var signature = walletManager.signMessage(sessionId + nonce, mWallet.secretSpendKey);

        var req = new Request.Request(httpFactory.createHttpClient())
            .setMethod("POST")
            .setUrl(getUrl("revision"))
            .setHeaders(getHeaders(sessionId, nonce, signature))
            .onSuccess(getHandler("increment revision", function (obj) {
                console.info("revision incremented: " + JSON.stringify(obj));
                staticRevision = obj.revision;
            }))
            .onError(getStdError("increment revision"));

        req.send();
    }

    function retrySend() {
        if (!pendingDecision) {
            return;
        }
    }

    function getUrl(method) {
        return meta.mwsUrl + apiVersion + method
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
