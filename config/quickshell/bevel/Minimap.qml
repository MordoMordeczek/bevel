import QtQuick
import Quickshell
import Quickshell.Hyprland

// One workspace indicator: a tiny map of where the windows are tiled.
Bevel {
    id: mm

    property int wsId: 1
    property var hmon: null

    readonly property var ws: {
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].id === mm.wsId)
                return list[i];
        return null;
    }
    // shown on its monitor (pressed in) · has the keyboard (an accent line, when there are several monitors)
    readonly property var wsMon: ws && ws.monitor ? ws.monitor : null
    readonly property bool isActive: wsMon && wsMon.activeWorkspace ? wsMon.activeWorkspace.id === mm.wsId
                                     : (Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === mm.wsId)
    readonly property bool isFocused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === mm.wsId
    readonly property var wins: ws ? ws.toplevels.values : []

    // monitor geometry in logical pixels
    // the geometry of the monitor this workspace is on (another screen's workspace maps right too)
    readonly property var mon: wsMon && wsMon.lastIpcObject ? wsMon.lastIpcObject : (hmon && hmon.lastIpcObject ? hmon.lastIpcObject : null)
    readonly property real monScale: mon && mon.scale ? mon.scale : 1
    readonly property real monX: (mon && mon.x !== undefined) ? mon.x : 0
    readonly property real monY: (mon && mon.y !== undefined) ? mon.y : 0
    readonly property real monW: (mon && mon.width) ? mon.width / monScale : 1920
    readonly property real monH: (mon && mon.height) ? mon.height / monScale : 1080

    sunken: true
    depth: isActive ? 2 : 1
    fill: isActive ? Theme.face2 : Theme.face
    fillOpacity: Theme.panelOpacity
    radius: Theme.radiusSm
    implicitWidth: Theme.minimaps ? Math.round(height * monW / monH * 1.15) : height + 4

    Item {
        id: area
        anchors.fill: parent
        anchors.margins: 1
        visible: Theme.minimaps

        Repeater {
            model: mm.wins
            Rectangle {
                required property var modelData
                readonly property var o: modelData.lastIpcObject
                readonly property bool ok: o !== undefined && o !== null && o.at !== undefined && o.size !== undefined
                readonly property bool floating: ok && o.floating === true
                visible: ok
                x: ok ? Math.round((o.at[0] - mm.monX) / mm.monW * area.width) : 0
                y: ok ? Math.round((o.at[1] - mm.monY) / mm.monH * area.height) : 0
                width: ok ? Math.max(2, Math.round(o.size[0] / mm.monW * area.width) - 1) : 0
                height: ok ? Math.max(2, Math.round(o.size[1] / mm.monH * area.height) - 1) : 0
                z: floating ? 2 : 1
                color: floating ? "transparent" : (modelData.activated ? Theme.accent : Theme.lo)
                border.width: floating ? 1 : 0
                border.color: modelData.activated ? Theme.accent : Theme.text
            }
        }
    }

    BText {
        anchors.centerIn: parent
        visible: !Theme.minimaps || mm.wins.length === 0
        text: mm.wsId
        font.family: Theme.barFont
        font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
        font.pixelSize: Math.max(9, Theme.barFontSize - 2)
        color: (mm.isActive || mm.wins.length > 0) ? Theme.text : Theme.lo
        font.bold: mm.isActive
    }

    Rectangle {
        // keyboard focus, when several monitors each show a workspace
        visible: mm.isFocused && Quickshell.screens.length > 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 2
        height: 2
        color: Theme.accent
    }
    Rectangle {
        // urgent marker
        visible: mm.ws !== null && mm.ws.urgent
        anchors.right: parent.right
        anchors.top: parent.top
        width: 4; height: 4
        color: "#cc3333"
    }
}
