import QtQuick 2.0
import QtQuick.Layouts 1.1
import QtQuick.Controls 2.0

import "../components" as MoneroComponents
import FontAwesome 1.0

SpinBox {
    //TODO: on hover cursor
    //TODO: vertical separator between areas

    id: spinBox
    value: 2
    editable: false

    Layout.preferredWidth: 80

    contentItem: TextInput {
        z: 2
        text: spinBox.textFromValue(spinBox.value, spinBox.locale)

        font.family: MoneroComponents.Style.fontRegular.name
        font.pointSize: 14 * scaleRatio
        color: MoneroComponents.Style.defaultFontColor
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter

        readOnly: true
        validator: spinBox.validator
    }

    down.indicator: Rectangle {
        color: "transparent"
        anchors.left: parent.left
        height: parent.height
        width: 25

        Label {
            anchors.centerIn: parent
            text: FontAwesome.minus
            color: MoneroComponents.Style.defaultFontColor
        }
    }

    up.indicator: Rectangle {
        color: "transparent"
        anchors.right: parent.right
        height: parent.height
        width: 25

        Label {
            anchors.centerIn: parent
            text: FontAwesome.plus
            color: MoneroComponents.Style.defaultFontColor
        }
    }

    background: Rectangle {
        color: "transparent"
        border.width: 1
        border.color: MoneroComponents.Style.inputBorderColorInActive
        radius: 3
    }
}
