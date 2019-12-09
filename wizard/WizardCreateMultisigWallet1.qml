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
import QtQuick.Dialogs 1.2
import QtQuick.Layouts 1.2
import QtQuick.Controls 2.0

import "../js/Wizard.js" as Wizard
import "../components" as MoneroComponents
import moneroComponents.NetworkType 1.0

Rectangle {
    id: wizardCreateMultisigWallet1
    
    color: "transparent"
    property string viewName: "wizardCreateMultisigWallet1"

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
            spacing: 0

            WizardHeader {
                title: qsTr("Create new multisignature wallet") + translationManager.emptyString
                subtitle: qsTr("Creates new multisignature wallet on this computer.") + translationManager.emptyString
            }

            WizardWalletInput{
                id: walletInput
            }

            MoneroComponents.LineEdit {
                id: mwsUrlInput
                Layout.fillWidth: true
                Layout.topMargin: 20
                labelText: qsTr("Multisignature wallet service url") + translationManager.emptyString
                text: {
                    if (appWindow.persistentSettings.nettype == NetworkType.MAINNET) {
                        return "https://mws.exan.tech/";
                    } else if (appWindow.persistentSettings.nettype == NetworkType.STAGENET) {
                        return "https://mws-stage.exan.tech/";
                    } else {
                        return "";
                    }
                }
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

            ColumnLayout {
                spacing: 0

                Layout.topMargin: 10 * scaleRatio
                Layout.fillWidth: true
            }

            WizardNav {
                progressSteps: 4
                progress: 1
                btnNext.enabled: walletInput.verify() && mwsUrlInput.text != "";
                btnPrev.text: qsTr("Back to menu") + translationManager.emptyString
                onPrevClicked: {
                    wizardStateView.state = "wizardHome";
                }
                onNextClicked: {
                    wizardController.walletOptionsName = walletInput.walletName.text;
                    wizardController.walletOptionsLocation = walletInput.walletLocation.text;
                    wizardController.mwsUrl = Wizard.normalizeMwsUrl('https', mwsUrlInput.text)
                    wizardStateView.state = "wizardCreateMultisigWallet2";
                }
            }
        }
    }

    function onPageCompleted(previousView){
        if(previousView.viewName === "wizardHome"){
            walletInput.reset();
        }
    }
}
