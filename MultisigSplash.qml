import QtQuick 2.0
import QtQuick.Layouts 1.1

import "components" as MoneroComponents

Item {
    id: multisigSplash
    anchors.fill: parent

    property string inviteCode
    property alias status: multisigWaitLabel.text
    property var wallet
    property int signaturesCount
    property int participantsCount

    signal walletCreated

    onInviteCodeChanged: {
        if (inviteCode) {
            multisigInviteCode.text = qsTr("Invite code: " + inviteCode);
        } else {
            multisigInviteCode.text = "";
        }
    }

    Rectangle {
        anchors.fill: parent
        color: MoneroComponents.Style.moneroGrey

        RowLayout {
            anchors.centerIn: parent

            MoneroComponents.Label {
                id: multisigWaitLabel
            }

            MoneroComponents.Label {
                 id: multisigInviteCode
            }
        }
    }

    Connections {
        target: MoneroComponents.MsProto
        onSessionOpened: {
            status = "Session opened, creating wallet...";
            MoneroComponents.MsProto.createWallet(wallet, "good wallet", signaturesCount, participantsCount);
        }

        onError: {
            status = "Failed to create shared wallet: " + msg;
        }

        onInviteCodeReceived: {
            status = "Share invite code";
            inviteCode = inviteCode;
        }

        onWalletCreated: {
            walletCreated()
        }
    }
}
