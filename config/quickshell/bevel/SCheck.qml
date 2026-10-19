import QtQuick

// Checkbox. Emits toggled(newValue); the caller writes it to settings.
Item {
    id: root
    property string text: ""
    property bool checked: false
    signal toggled(bool value)

    implicitWidth: box.width + 8 + label.implicitWidth
    implicitHeight: Math.max(16, label.implicitHeight + 4)

    Bevel {
        id: box
        width: 14; height: 14
        anchors.verticalCenter: parent.verticalCenter
        sunken: true
        fill: ma.pressed ? Theme.face : Theme.base
        depth: Math.min(2, Theme.bevel)
        Canvas {
            id: tick
            anchors.fill: parent
            visible: root.checked
            property color c: Theme.text
            onCChanged: requestPaint()
            onVisibleChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                g.reset();
                g.strokeStyle = c;
                g.lineWidth = 2;
                g.beginPath();
                g.moveTo(1, width / 2);
                g.lineTo(width / 2 - 1, height - 2);
                g.lineTo(width - 1, 1);
                g.stroke();
            }
        }
    }
    BText {
        id: label
        anchors.left: box.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        onClicked: root.toggled(!root.checked)
    }
}
