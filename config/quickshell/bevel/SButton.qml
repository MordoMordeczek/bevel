import QtQuick

Bevel {
    id: btn
    property string text: ""
    property bool highlighted: false
    property bool checked: false
    signal clicked()

    sunken: ma.pressed || checked
    fill: checked ? Theme.face2 : Theme.face
    radius: Theme.radiusSm
    implicitWidth: Math.max(72, label.implicitWidth + 24)
    implicitHeight: Theme.fontSize + 12

    Rectangle {
        // default-button outline
        visible: btn.highlighted
        anchors.fill: parent
        anchors.margins: -Math.max(1, btn.depth)
        color: "transparent"
        border.color: Theme.dark
        border.width: 1
        radius: Theme.radiusSm
    }

    BText {
        id: label
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: btn.sunken ? 1 : 0
        anchors.verticalCenterOffset: btn.sunken ? 1 : 0
        text: btn.text
        font.bold: btn.checked
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -Math.max(1, btn.depth)
        onClicked: btn.clicked()
    }
}
