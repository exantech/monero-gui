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

import QtQuick 2.7
import QtQuick.Layouts 1.2
import QtQuick.Controls 2.0

import moneroComponents.Clipboard 1.0
import "../components" as MoneroComponents
import "../js/Wizard.js" as Wizard
import moneroComponents.NetworkType 1.0

Rectangle {
    id: wizardJoinMultisigWallet1

    color: "transparent"
    property string viewName: "wizardJoinMultisigWallet3"

    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter;
        width: parent.width - 100
        Layout.fillWidth: true
        anchors.horizontalCenter: parent.horizontalCenter;

        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: wizardController.wizardSubViewTopMargin
            Layout.maximumWidth: wizardController.wizardSubViewWidth
            Layout.alignment: Qt.AlignHCenter
            spacing: 20 * scaleRatio

            WizardHeader {
                title: "Join multisig wallet"
                subtitle: "Create new wallet and enter invite code"
            }

            WizardWalletInput{
                id: walletInput
            }

            RowLayout {
                Layout.fillWidth: true

                MoneroComponents.LineEditMulti {
                    id: inviteCodeLine
                    Layout.topMargin: 20
                    spacing: 0
                    fontBold: true
                    labelText: "Invite code"
                    wrapMode: Text.WrapAnywhere
                    addressValidation: false
                    pasteButton: true
                    onPaste: function(clipboardText) {
                        inviteCodeLine.text = clipboardText;
                    }
                    inlineButtonVisible : false
                }
            }

            MoneroComponents.LineEdit {
                id: mwsUrlInput
                Layout.fillWidth: true
                Layout.topMargin: 20
                labelText: qsTr("Multisignature wallet service url") + translationManager.emptyString
                error: mwsUrlInput.text == ""
            }

            MoneroComponents.LineEditMulti {
                id: seed

                Layout.topMargin: 20

                spacing: 0
                inputPaddingLeft: 16
                inputPaddingRight: 16
                inputPaddingTop: 20
                inputPaddingBottom: 20
                inputRadius: 0

                fontSize: 18
                fontBold: true
                wrapMode: Text.WordWrap
                backgroundColor: "red"
                addressValidation: false
                labelText: qsTr("Mnemonic seed") + translationManager.emptyString
                labelFontSize: 14
                copyButton: false
                readOnly: true

                placeholderText: "-"
                text: wizardController.walletOptionsSeed
            }

            MoneroComponents.WarningBox {
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: MoneroComponents.Style.inputBorderColorInActive
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    height: 1
                    color: MoneroComponents.Style.inputBorderColorInActive
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: MoneroComponents.Style.inputBorderColorInActive
                }

                radius: 0
                border.color: MoneroComponents.Style.inputBorderColorInActive
                border.width: 0

                text: qsTr("This seed is <b>very</b> important to write down and keep secret. It is all you need to backup and restore your wallet.") + translationManager.emptyString
            }

            WizardNav {
                progressSteps: 4
                progress: 1
                btnNext.enabled: walletInput.verify() && inviteCodeLine.text != "" && walletInput.verify() && mwsUrlInput.text != "";
                onPrevClicked: {
                    wizardStateView.state = "wizardHome";
                    wizardController.isMultisignature = false;
                }

                onNextClicked: {
                    wizardController.mwsUrl = Wizard.normalizeMwsUrl('https', mwsUrlInput.text);
                    wizardController.walletOptionsName = walletInput.walletName.text;
                    wizardController.walletOptionsLocation = walletInput.walletLocation.text;
                    wizardController.inviteCode = inviteCodeLine.text
                    wizardStateView.state = "wizardJoinMultisigWallet2";
                }
            }

            Clipboard { id: clipboard }
        }
    }

    function onPageCompleted(previousView){
        if(previousView.viewName !== "wizardHome") {
            return;
        }

        inviteCodeLine.text = "";

        if (appWindow.persistentSettings.nettype == NetworkType.MAINNET) {
            mwsUrlInput.text = "https://mws.exan.tech/";
        } else if (appWindow.persistentSettings.nettype == NetworkType.STAGENET) {
            mwsUrlInput.text = "https://mws-stage.exan.tech/";
        } else {
            mwsUrlInput.text = "";
        }
    }
}
