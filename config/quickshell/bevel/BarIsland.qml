import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// The "Islands" layout: three floating blocks — by default workspaces, clock, status.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData
    readonly property var hmon: Hyprland.monitorFor(bar.screen)

    anchors { top: Theme.barTop; bottom: !Theme.barTop; left: true; right: true }
    margins {
        top: Theme.barTop ? Theme.gapsOut : 0
        bottom: Theme.barTop ? 0 : Theme.gapsOut
        left: Theme.gapsOut
        right: Theme.gapsOut
    }
    implicitHeight: Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "bevel-bar"
    WlrLayershell.layer: WlrLayer.Top

    // three floating blocks, one behind each group of items (Settings → Bar → Items)
    Island { visible: row.leftW > 0; x: 0; width: row.leftW + 14 }
    Island { visible: row.centerW > 0; x: row.centerX; width: row.centerW + 14 }
    Island { visible: row.rightW > 0; x: parent.width - width; width: row.rightW + 14 }
    BarRow {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 7
        anchors.rightMargin: 7
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        spacing: 10
        bar: bar
        originX: Theme.gapsOut + 7
        hmon: bar.hmon
    }
    component Island: Bevel {
        height: bar.height
        radius: Theme.radius
        fillOpacity: Theme.panelOpacity
    }
}
