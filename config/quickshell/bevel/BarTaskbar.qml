import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// The "Taskbar" layout: a Windows 95 taskbar along the bottom — Start, window buttons, tray, clock.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData
    readonly property var hmon: Hyprland.monitorFor(bar.screen)

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Theme.barHeight + 4
    color: "transparent"
    WlrLayershell.namespace: "bevel-bar"
    WlrLayershell.layer: WlrLayer.Top

    Bevel {
        anchors.fill: parent
        fillOpacity: Theme.panelOpacity
        Dither { anchors.fill: parent; visible: Theme.dither }

        // the right-hand group sits in a sunken "notification area", like Windows 95
        Bevel {
            visible: row.rightW > 0
            x: row.x + row.width - row.rightW - 6
            y: 3
            width: row.rightW + 10
            height: parent.height - 6
            sunken: true
            depth: 1
            fill: "transparent"
            radius: Theme.radiusSm
        }
        BarRow {
            id: row
            anchors.fill: parent
            anchors.leftMargin: 3
            anchors.rightMargin: 9
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            spacing: 6
            compact: true
            bar: bar
            originX: 3
            hmon: bar.hmon
        }
    }
}
