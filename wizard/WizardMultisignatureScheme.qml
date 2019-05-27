import QtQuick 2.0
import QtQuick.Layouts 1.2
import QtQuick.Controls 2.0

import "../components" as MoneroComponents

GridLayout {
    id: wizardMultisignatureScheme

    property alias signaturesCount: signaturesSpinbox.value
    property alias participantsCount: participantsSpinbox.value

    columns: (isMobile) ? 1 : 2
    Layout.fillWidth: true
    Layout.maximumWidth: wizardController.wizardSubViewWidth
//    Layout.alignment: Qt.AlignHCenter
    Layout.alignment: Qt.AlignLeft
    columnSpacing: 32 * scaleRatio

    ColumnLayout {
        anchors.left: parent.left
        MoneroComponents.Label{
            text: qsTr("Signatures count")
        }

        MoneroComponents.SpinBox {
            id: signaturesSpinbox
            from: 2
            to: participantsSpinbox.value
        }
    }

    ColumnLayout {
        MoneroComponents.Label{
            text: qsTr("Participants count")
        }

        MoneroComponents.SpinBox {
            id: participantsSpinbox
            from: 2
        }
    }
}
