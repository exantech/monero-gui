import QtQuick 2.0
import QtQuick.Layouts 1.1
import QtQuick.Controls 2.0

import "components" as MoneroComponents
import moneroComponents.Clipboard 1.0

Item {
    id: multisigSplash
    anchors.fill: parent

    property alias status: multisigWaitLabel.text
    property string walletInviteCode

    signal walletCreated

    Rectangle {
        anchors.fill: parent
        color: "#161616"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5

            Label {
                id: multisigWaitLabel
                color: MoneroComponents.Style.defaultFontColor
                font.pixelSize: 16 * scaleRatio

                text: "Connecting to server..."
            }

            RowLayout {
                id: inviteCodeLayout
                visible: false
                spacing: 10

                Label {
                    id: multisigInviteCode
                    anchors.left: parent.left
                    color: MoneroComponents.Style.defaultFontColor
                    font.pixelSize: 16 * scaleRatio
                }

                MoneroComponents.IconButton {
                    id: copyButton
                    image: "qrc:///images/copy.svg"
                    anchors.right: parent.right
                    width: 12
                    height: 15

                    onClicked: {
                        clipboard.setText(multisigSplash.walletInviteCode);
                        appWindow.showStatusMessage(qsTr("Invite code copied to clipboard"),3);
                    }
                }
            }

            MoneroComponents.StandardButton {
                text: "Back"
                onClicked: {
                    MoneroComponents.MsProto.stop();
                    appWindow.showWizard();
                }
            }
        }

        Clipboard { id: clipboard }
    }

    Connections {
        target: MoneroComponents.MsProto
        onSessionOpened: {
            multisigWaitLabel.text = "Session opened, creating wallet...";
        }

        onError: {
            status = "Failed to create shared wallet: " + msg;
        }

        onInviteCodeReceived: {
            inviteCodeLayout.visible = true
            multisigWaitLabel.text = "Share invite code";
            multisigInviteCode.text = "Invite code: <b>" + shortInviteCode(inviteCode, 16) + "</b>";
            walletInviteCode = inviteCode
        }

        onJoinedToWallet: {
            multisigWaitLabel.text = "Joined to wallet, exchanging with keys...";
        }

        onKeyExchangeRoundPassed: {
            multisigWaitLabel.text = "Performing keys exchange round #" + (newRoundNumber + 1);
        }

        onWalletCreated: {
            walletCreated()
        }
    }

    function shortInviteCode(text, size) {
        if (!text)
          return text

        if (text.length < size * 2 + 3)
          return text

        var begin = text.substring(0, size);
        var end = text.substring(text.length - size);
        return begin + "..." + end;
    }
}
