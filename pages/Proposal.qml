// Copyright (c) 2014-2019, The Monero Project
// 
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without modification, are
// permitted provided that the following conditions are met:
// 
// 1. Redistributions of source code must retain the above copyright notice, this list of
//    conditions and the following disclaimer.
// 
// 2. Redistributions in binary form must reproduce the above copyright notice, this list
//    of conditions and the following disclaimer in the documentation and/or other
//    materials provided with the distribution.
// 
// 3. Neither the name of the copyright holder nor the names of its contributors may be
//    used to endorse or promote products derived from this software without specific
//    prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
// THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
// THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import QtQuick 2.9
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.1
import QtQuick.Dialogs 1.2

import "../components" as MoneroComponents
import "../components/effects/" as MoneroEffects

import "../js/TxUtils.js" as TxUtils
import moneroComponents.AddressBook 1.0
import moneroComponents.AddressBookModel 1.0
import moneroComponents.Clipboard 1.0
import moneroComponents.NetworkType 1.0
import FontAwesome 1.0

Rectangle {
    id: root
    color: "transparent"

    property var proposal

    property alias proposalHeight: mainLayout.height
    property bool selectAndSend: false
    property bool editEntry: false

    Clipboard { id: clipboard }

    ColumnLayout {
        id: mainLayout
        anchors.margins: (isMobile)? 17 : 20
        anchors.topMargin: 40

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right

        spacing: 20

        ColumnLayout {
            id: proposalEmptyLayout
            visible: root.proposal == null
            Layout.fillWidth: true

            TextArea {
                id: titleLabel
                Layout.fillWidth: true
                color: MoneroComponents.Style.defaultFontColor
                font.family: MoneroComponents.Style.fontRegular.name
                font.pixelSize: 32
                horizontalAlignment: TextInput.AlignLeft
                selectByMouse: false
                wrapMode: Text.WordWrap;
                textMargin: 0
                leftPadding: 0
                topPadding: 0
                text: qsTr("No active proposals") + translationManager.emptyString
                width: parent.width
                readOnly: true
            }
        }

        ColumnLayout {
            id: proposalLayout
            visible: root.proposal != null

            MoneroComponents.Label {
                Layout.bottomMargin: 20
                fontSize: 32
                text: qsTr("Active proposal") + translationManager.emptyString
            }

            Rectangle {
                id: border2
                color: MoneroComponents.Style.appWindowBorderColor
                Layout.fillWidth: true
                height: 1

                MoneroEffects.ColorTransition {
                    targetObj: border2
                    blackColor: MoneroComponents.Style._b_appWindowBorderColor
                    whiteColor: MoneroComponents.Style._w_appWindowBorderColor
                }
            }

            ColumnLayout {
                Layout.topMargin: 10
                spacing: 10

                // Destination line
                RowLayout {
                    MoneroComponents.TextPlain {
                        text: qsTr("Destination: ") + translationManager.emptyString
                        Layout.fillWidth: true
                        color: MoneroComponents.Style.defaultFontColor
                        font.pixelSize: 16
                        font.family: MoneroComponents.Style.fontRegular.name
                        themeTransition: false
                    }

                    MoneroComponents.TextPlain {
                        font.family: MoneroComponents.Style.fontMonoRegular.name;
                        font.pixelSize: 16
                        color: MoneroComponents.Style.defaultFontColor
                        themeTransition: false
                        text: TxUtils.addressTruncatePretty(proposal.destination_address, mainLayout.width < 740 ? 1 : (mainLayout.width < 900 ? 2 : 3))

                        MouseArea {
                            hoverEnabled: true
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.color = MoneroComponents.Style.orange
                            onExited: parent.color = MoneroComponents.Style.defaultFontColor
                            onClicked: {
                                console.log("Copied to clipboard");
                                clipboard.setText(proposal.destination_address);
                                appWindow.showStatusMessage(qsTr("Copied to clipboard"),3)
                            }
                        }
                    }
                }

                // Amount line
                RowLayout {
                    MoneroComponents.TextPlain {
                        text: qsTr("Amount: ") + translationManager.emptyString
                        Layout.fillWidth: true
                        color: MoneroComponents.Style.defaultFontColor
                        font.pixelSize: 16
                        font.family: MoneroComponents.Style.fontRegular.name
                        themeTransition: false
                    }

                    MoneroComponents.TextPlain {
                        font.family: MoneroComponents.Style.fontMonoRegular.name;
                        font.pixelSize: 16
                        color: MoneroComponents.Style.defaultFontColor
                        themeTransition: false
                        text: walletManager.displayAmount(proposal.amount)

                        MouseArea {
                            hoverEnabled: true
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.color = MoneroComponents.Style.orange
                            onExited: parent.color = MoneroComponents.Style.defaultFontColor
                            onClicked: {
                                console.log("Copied to clipboard");
                                clipboard.setText(parent.text);
                                appWindow.showStatusMessage(qsTr("Copied to clipboard"),3)
                            }
                        }
                    }
                }

                // Fee line
                RowLayout {
                    MoneroComponents.TextPlain {
                        text: qsTr("Fee: ") + translationManager.emptyString
                        Layout.fillWidth: true
                        color: MoneroComponents.Style.defaultFontColor
                        font.pixelSize: 16
                        font.family: MoneroComponents.Style.fontRegular.name
                        themeTransition: false
                    }

                    MoneroComponents.TextPlain {
                        font.family: MoneroComponents.Style.fontMonoRegular.name;
                        font.pixelSize: 16
                        color: MoneroComponents.Style.defaultFontColor
                        themeTransition: false
                        text: walletManager.displayAmount(proposal.fee)

                        MouseArea {
                            hoverEnabled: true
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.color = MoneroComponents.Style.orange
                            onExited: parent.color = MoneroComponents.Style.defaultFontColor
                            onClicked: {
                                console.log("Copied to clipboard");
                                clipboard.setText(parent.text);
                                appWindow.showStatusMessage(qsTr("Copied to clipboard"),3)
                            }
                        }
                    }
                }

                // Approvals line
                RowLayout {
                    MoneroComponents.TextPlain {
                        text: qsTr("Approvals: ") + translationManager.emptyString
                        Layout.fillWidth: true
                        color: MoneroComponents.Style.defaultFontColor
                        font.pixelSize: 16
                        font.family: MoneroComponents.Style.fontRegular.name
                        themeTransition: false
                    }

                    MoneroComponents.TextPlain {
                        font.family: MoneroComponents.Style.fontMonoRegular.name;
                        font.pixelSize: 16
                        color: MoneroComponents.Style.defaultFontColor
                        themeTransition: false
                        text: proposal.approvals.length + "/" + MoneroComponents.MsProto.meta.signaturesRequired

                        MouseArea {
                            hoverEnabled: true
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.color = MoneroComponents.Style.orange
                            onExited: parent.color = MoneroComponents.Style.defaultFontColor
                            onClicked: {
                                console.log("Copied to clipboard");
                                clipboard.setText(parent.text);
                                appWindow.showStatusMessage(qsTr("Copied to clipboard"),3)
                            }
                        }
                    }
                }

                // Rejects line
                RowLayout {
                    MoneroComponents.TextPlain {
                        text: qsTr("Rejects: ") + translationManager.emptyString
                        Layout.fillWidth: true
                        color: MoneroComponents.Style.defaultFontColor
                        font.pixelSize: 16
                        font.family: MoneroComponents.Style.fontRegular.name
                        themeTransition: false
                    }

                    MoneroComponents.TextPlain {
                        font.family: MoneroComponents.Style.fontMonoRegular.name;
                        font.pixelSize: 16
                        color: MoneroComponents.Style.defaultFontColor
                        themeTransition: false
                        text: proposal.rejects.length + "/" + MoneroComponents.MsProto.meta.participantsCount

                        MouseArea {
                            hoverEnabled: true
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.color = MoneroComponents.Style.orange
                            onExited: parent.color = MoneroComponents.Style.defaultFontColor
                            onClicked: {
                                console.log("Copied to clipboard");
                                clipboard.setText(parent.text);
                                appWindow.showStatusMessage(qsTr("Copied to clipboard"),3)
                            }
                        }
                    }
                }

                // Proposal description
                MoneroComponents.LineEditMulti {
                    Layout.fillWidth: true
                    readOnly: true
                    labelText: qsTr("Transaction description") + translationManager.emptyString
                    fontSize: 16
                    text: proposal.description
                }

                // Decision buttons
                RowLayout {
                    Layout.topMargin: 15
                    spacing: 10

                    MoneroComponents.StandardButton {
                        id: approveButton
                        text: "approve"

                        enabled: !root.proposal.answered

                        onClicked: {
                            appWindow.showProcessingSplash("Sending proposal decision");
                            MoneroComponents.MsProto.sendProposalDecisionAsync(true, root.proposal);
                        }
                    }

                    MoneroComponents.StandardButton {
                        id: rejectButton
                        text: "reject"
                        width: approveButton.width

                        enabled: !root.proposal.answered

                        onClicked: {
                            appWindow.showProcessingSplash("Sending proposal decision");
                            MoneroComponents.MsProto.sendProposalDecisionAsync(false, root.proposal);
                        }
                    }
                }
            }
        }
    }

    function setActiveProposal(prop) {
        root.proposal = prop;
    }

    function onPageCompleted() {
    }

    function onPageClosed() {
    }
}
