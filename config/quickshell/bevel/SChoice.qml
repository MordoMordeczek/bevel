import QtQuick
import QtQuick.Layouts

// Segmented buttons. model: [{ label, value }, ...]
RowLayout {
    id: root
    property string text: ""
    property var model: []
    property var current
    property int labelWidth: 130
    signal picked(var value)

    spacing: 10
    Layout.fillWidth: true

    BText {
        visible: root.text !== ""
        text: root.text
        Layout.preferredWidth: root.labelWidth
    }
    Flow {
        Layout.fillWidth: true
        spacing: 3
        Repeater {
            model: root.model
            SButton {
                required property var modelData
                text: modelData.label
                checked: String(root.current) === String(modelData.value)
                onClicked: root.picked(modelData.value)
            }
        }
    }
}
