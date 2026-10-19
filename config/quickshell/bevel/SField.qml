import QtQuick
import QtQuick.Layouts

// Label + sunken text field. Emits accepted(text) on Enter or when focus leaves.
RowLayout {
    id: root
    property string text: ""
    property string value: ""
    property int labelWidth: 130
    readonly property alias currentText: input.text
    signal accepted(string text)

    spacing: 10
    Layout.fillWidth: true

    BText {
        visible: root.text !== ""
        text: root.text
        Layout.preferredWidth: root.labelWidth
    }
    Bevel {
        Layout.fillWidth: true
        implicitHeight: Theme.fontSize + 12
        sunken: true
        fill: Theme.base
        radius: Theme.radiusSm
        padding: 2
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 3
            verticalAlignment: TextInput.AlignVCenter
            text: root.value
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentText
            font.family: Theme.font
            font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
            font.pixelSize: Theme.fontSize
            clip: true
            selectByMouse: true
            onAccepted: root.accepted(text)
            onActiveFocusChanged: if (!activeFocus && text !== root.value) root.accepted(text)
        }
    }
}
