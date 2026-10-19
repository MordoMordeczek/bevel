import QtQuick

Bevel {
    id: btn
    property string text: ""
    property bool isDefault: false
    property real s: 1
    property string fontFamily: ""
    property string icon: ""          // a pixel icon from icons/ (e.g. "power")
    signal clicked()

    sunken: ma.pressed || activeFocus
    implicitWidth: Math.max(86 * s, label.implicitWidth + 28 * s + (icon !== "" ? 22 * s : 0))
    implicitHeight: 28 * s
    activeFocusOnTab: true
    Keys.onReturnPressed: btn.clicked()
    Keys.onEnterPressed: btn.clicked()
    Keys.onSpacePressed: btn.clicked()

    Rectangle {
        visible: btn.isDefault
        anchors.fill: parent
        anchors.margins: -3
        color: "transparent"
        border.color: btn.pal.dark
    }
    Image {
        visible: btn.icon !== ""
        source: btn.icon !== "" ? "icons/" + btn.icon + ".png" : ""
        width: 16 * Math.max(1, Math.round(btn.s)); height: width
        smooth: false
        anchors.right: label.left
        anchors.rightMargin: 6 * btn.s
        anchors.verticalCenter: label.verticalCenter
    }
    Text {
        id: label
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: (btn.sunken ? 1 : 0) + (btn.icon !== "" ? 11 * btn.s : 0)
        anchors.verticalCenterOffset: btn.sunken ? 1 : 0
        text: btn.text
        color: btn.pal.text
        font.family: btn.fontFamily
        font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
        font.pixelSize: 14 * btn.s
    }
    Rectangle {
        // dotted-ish focus ring
        visible: btn.activeFocus
        anchors.fill: label
        anchors.margins: -3
        color: "transparent"
        border.color: btn.pal.text
        opacity: 0.5
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -3
        onClicked: btn.clicked()
    }
}
