import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

// The "Bevel" layout: one bar on top (or bottom).
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    readonly property int gap: Theme.barFloating ? Theme.gapsOut : 0
    readonly property var hmon: Hyprland.monitorFor(bar.screen)

    anchors {
        top: Theme.barTop
        bottom: !Theme.barTop
        left: true
        right: true
    }
    margins {
        top: Theme.barTop ? bar.gap : 0
        bottom: Theme.barTop ? 0 : bar.gap
        left: bar.gap
        right: bar.gap
    }
    implicitHeight: Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "bevel-bar"
    WlrLayershell.layer: WlrLayer.Top

    Bevel {
        anchors.fill: parent
        radius: Theme.radius
        fillOpacity: Theme.panelOpacity

        Dither {
            anchors.fill: parent
            visible: Theme.dither
        }

        // what's on it and where: Settings → Bar → Items
        BarRow {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            bar: bar
            originX: bar.gap + 4
            hmon: bar.hmon
        }
    }
}
