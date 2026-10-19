import QtQuick
import QtQuick.Layouts

// Etched group box with a title.
Item {
    id: root
    property string title: ""
    default property alias content: col.data
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 28
    implicitWidth: col.implicitWidth + 24

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 8
        color: "transparent"
        border.color: Theme.lo
        radius: Theme.radiusSm
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: "transparent"
            border.color: Theme.hi
            radius: Theme.radiusSm
            opacity: 0.8
        }
    }
    Rectangle {
        x: 10
        width: t.implicitWidth + 8
        height: t.implicitHeight
        color: Theme.face
        BText { id: t; x: 4; text: root.title; font.bold: true }
    }
    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.topMargin: 22
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 10
        spacing: 8
    }
}
