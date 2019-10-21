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
        color: MoneroComponents.Style.blackTheme ? "#161616" : "white"
        opacity: MoneroComponents.Style.blackTheme ? 1.0 : 0.9

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5

            Label {
                id: multisigWaitLabel
                Layout.alignment: Qt.AlignHCenter
                color: MoneroComponents.Style.defaultFontColor
                font.pixelSize: 16

                text: "Connecting to server..."
            }

            Rectangle {
                Layout.preferredHeight: 1
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                Layout.fillWidth: true
                color: MoneroComponents.Style.dividerColor
                opacity: MoneroComponents.Style.dividerOpacity
            }

            GridLayout {
                id: inviteCodeLayout
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 15

                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 20
                    color: "transparent"

                    MoneroComponents.TextBlock {
                        anchors.right: parent.right
                        Layout.alignment: Qt.AlignVCenter
                        font.pixelSize: 16
                        text: "Invite code"
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 20
                    color: "transparent"

                    RowLayout {
                        MoneroComponents.TextBlock {
                            id: multisigInviteCode
                            Layout.alignment: Qt.AlignVCenter
                            font.pixelSize: 16
                            font.bold: true
                        }

                        MoneroComponents.IconButton {
                            id: copyButton
                            visible: multisigInviteCode.text != ""
                            image: "qrc:///images/copy.svg"
                            width: 12
                            height: 15
                            Layout.rightMargin: parent.right

                            onClicked: {
                                clipboard.setText(multisigSplash.walletInviteCode);
                                appWindow.showStatusMessage(qsTr("Invite code copied to clipboard"),3);
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredHeight: 1
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                Layout.fillWidth: true
                color: MoneroComponents.Style.dividerColor
                opacity: MoneroComponents.Style.dividerOpacity
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 15

                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 20
                    color: "transparent"

                    MoneroComponents.TextBlock {
                        anchors.right: parent.right
                        Layout.alignment: Qt.AlignVCenter
                        font.pixelSize: 16
                        text: "Participants joined"
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 20
                    color: "transparent"

                    MoneroComponents.TextBlock {
                        id: participantsLabel
                        Layout.alignment: Qt.AlignVCenter
                        font.pixelSize: 16
                        font.bold: true
                        text: "... / " + MoneroComponents.MsProto.meta.participantsCount
                    }
                }
            }

            Rectangle {
                Layout.preferredHeight: 1
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                Layout.fillWidth: true
                color: MoneroComponents.Style.dividerColor
                opacity: MoneroComponents.Style.dividerOpacity
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 15

                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 20
                    color: "transparent"

                    MoneroComponents.TextBlock {
                        anchors.right: parent.right
                        Layout.alignment: Qt.AlignVCenter
                        font.pixelSize: 16
                        text: "Key exchange rounds"
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 20
                    color: "transparent"

                    MoneroComponents.TextBlock {
                        id: exchangeRoundsLabel
                        Layout.alignment: Qt.AlignVCenter
                        font.pixelSize: 16
                        font.bold: true
                        text: "0"
                    }
                }
            }

            Rectangle {
                Layout.preferredHeight: 1
                Layout.topMargin: 2
                Layout.bottomMargin: 2
                Layout.fillWidth: true
                color: MoneroComponents.Style.dividerColor
                opacity: MoneroComponents.Style.dividerOpacity
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                color: "transparent"
                width: 300
                height: 300

                Image {
                    id: qrCode
                    anchors.fill: parent
                    visible: walletInviteCode != ""

                    smooth: false
                    fillMode: Image.PreserveAspectFit
                    source: "image://qrcode/" + walletInviteCode

                    MouseArea {
                        hoverEnabled: true
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            clipboard.setText(multisigSplash.walletInviteCode);
                            appWindow.showStatusMessage(qsTr("Invite code copied to clipboard"),3);
                        }
                    }
                }
            }

            MoneroComponents.StandardButton {
                text: "Back"
                Layout.topMargin: 10
                Layout.alignment: Qt.AlignHCenter
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
            multisigInviteCode.text = shortInviteCode(inviteCode, 9);
            walletInviteCode = inviteCode
        }

        onJoinedToWallet: {
            multisigWaitLabel.text = "Joined to wallet, exchanging with keys...";
        }

        onParticipantsUpdate: {
            participantsLabel.text = signaturesRequired + " / " + participantsCount;
        }

        onKeyExchangeRoundPassed: {
            exchangeRoundsLabel.text = newRoundNumber
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
