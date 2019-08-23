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

            WizardNav {
                progressSteps: 4
                progress: 1
                btnNext.enabled: walletInput.verify() && inviteCodeLine.text != "";
                onPrevClicked: {
                    wizardStateView.state = "wizardHome";
                    wizardController.isMultisignature = false;
                }

                onNextClicked: {
                    wizardController.walletOptionsName = walletInput.walletName.text;
                    wizardController.walletOptionsLocation = walletInput.walletLocation.text;
                    wizardController.inviteCode = inviteCodeLine.text
                    wizardStateView.state = "wizardJoinMultisigWallet2";
                }
            }

            Clipboard { id: clipboard }
        }
    }
}
