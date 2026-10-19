import QtQuick
import QtQuick.Layouts

// "Please wait" box shown while Bevel repaints everything in new colours.
Bevel {
    id: dlg
    implicitWidth: 380
    implicitHeight: col.implicitHeight + 10
    radius: Theme.radius
    padding: 2

    readonly property var lines: [
        "Pulling colours out of the wallpaper…", "Mixing the paint…", "Sanding the bevels…",
        "Telling kitty about it…", "Asking GTK nicely…", "Reticulating splines…",
        "Polishing every pixel…", "Defragmenting the palette…", "Counting to 256…",
        "Waking up the window manager…", "Repainting the taskbar…", Theme.btwLabel + "…"
    ]
    property int line: Math.floor(Math.random() * lines.length)
    Timer { interval: 1300; running: dlg.visible; repeat: true; onTriggered: dlg.line = (dlg.line + 1) % dlg.lines.length }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: 8
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.fontSize + 10
            color: Theme.accent
            radius: Theme.radiusSm
            BText {
                anchors.left: parent.left; anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: "Bevel"; font.bold: true; color: Theme.accentText
            }
        }
        RowLayout {
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            spacing: 12
            // a little spinning paint can of four panes
            Grid {
                columns: 2; spacing: 2
                // a smooth quarter-turn, a short rest, repeat (always forwards)
                SequentialAnimation on rotation {
                    running: dlg.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: 260 }
                    RotationAnimation { from: 0; to: 90; duration: 220; easing.type: Easing.InOutQuad }
                }
                Rectangle { width: 12; height: 12; color: Theme.accent; border.color: Theme.dark }
                Rectangle { width: 12; height: 12; color: Theme.accent2; border.color: Theme.dark }
                Rectangle { width: 12; height: 12; color: Theme.face2; border.color: Theme.dark }
                Rectangle { width: 12; height: 12; color: Theme.lo; border.color: Theme.dark }
            }
            ColumnLayout {
                spacing: 2
                BText { text: "Repainting your desktop"; font.bold: true }
                BText { text: dlg.lines[dlg.line]; color: Theme.textDim; Layout.preferredWidth: 280 }
            }
        }
        // the classic marching-blocks progress bar
        Bevel {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            implicitHeight: 20
            sunken: true
            fill: Theme.base
            radius: Theme.radiusSm
            Item {
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                Row {
                    id: blocks
                    height: parent.height
                    spacing: 2
                    NumberAnimation on x {
                        running: dlg.visible
                        loops: Animation.Infinite
                        from: -blocks.width
                        to: blocks.parent.width
                        duration: 1600
                    }
                    Repeater {
                        model: 7
                        Rectangle { width: 10; height: parent.height; color: Theme.accent }
                    }
                }
            }
        }
        Item { implicitHeight: 2 }
    }
}
