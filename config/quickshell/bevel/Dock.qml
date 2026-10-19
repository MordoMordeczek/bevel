import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

// The "Dock" layout's icon dock: pinned + running apps, NeXT/Indigo style.
// Click: open (or bring up) · right click: a menu (pin, move, close…).
// Size, position, background and auto-hide: Settings → Desktop style → Dock.
PanelWindow {
    id: dock
    required property var modelData
    screen: modelData

    readonly property string pos: Theme.dockPos
    readonly property bool vertical: pos !== "bottom"
    readonly property int icon: Theme.dockSize
    readonly property int tileS: icon + 14
    readonly property int thick: Theme.dockThickness
    readonly property int gap: Theme.gapsOut
    readonly property bool hide: Theme.dockAutohide
    // auto-hide: out of sight until the pointer touches that screen edge
    property bool revealed: !hide
    property string menuFor: ""          // the app whose right-click menu is open

    anchors.bottom: pos === "bottom"
    anchors.left: pos === "left"
    anchors.right: pos === "right"
    margins.bottom: pos === "bottom" && !hide ? gap : 0
    margins.left: pos === "left" && !hide ? gap : 0
    margins.right: pos === "right" && !hide ? gap : 0
    readonly property int along: (vertical ? grid.implicitHeight : grid.implicitWidth) + 16
    readonly property int across: thick + (hide ? gap : 0)
    implicitWidth: vertical ? across : along
    implicitHeight: vertical ? along : across
    exclusionMode: hide ? ExclusionMode.Ignore : ExclusionMode.Auto
    color: "transparent"
    WlrLayershell.namespace: "bevel-dock"
    WlrLayershell.layer: hide ? WlrLayer.Overlay : WlrLayer.Top
    // hidden: only a thin strip at the edge takes the pointer
    mask: Region { item: dock.revealed ? frame : strip }

    function entryFor(id) {
        if (!id) return null;
        const e = DesktopEntries.byId(id) || DesktopEntries.byId(id.toLowerCase());
        if (e) return e;
        return DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(id) : null;
    }
    // pinned apps first, then anything else that is running
    readonly property var items: {
        const out = [];
        const seen = {};
        for (const id of Theme.dockPinned) {
            const e = dock.entryFor(id);
            if (!e) continue;
            out.push({ id: id, entry: e, pinned: true });
            seen[id.toLowerCase()] = true;
            seen[(e.id || "").toLowerCase()] = true;
        }
        if (Theme.dockRunning) {
            for (const t of ToplevelManager.toplevels.values) {
                const id = (t.appId || "").toLowerCase();
                if (!id || seen[id]) continue;
                seen[id] = true;
                out.push({ id: id, entry: dock.entryFor(id), pinned: false });
            }
        }
        return out;
    }
    function windowsOf(item) {
        const ids = [item.id.toLowerCase(), ((item.entry && item.entry.id) || "").toLowerCase()];
        return ToplevelManager.toplevels.values.filter(t => ids.indexOf((t.appId || "").toLowerCase()) >= 0);
    }
    function nameOf(item) {
        return item.entry && item.entry.name ? item.entry.name : item.id;
    }

    // ---- auto-hide
    Item {
        id: strip
        width: dock.vertical ? 4 : dock.width
        height: dock.vertical ? dock.height : 4
        x: dock.pos === "right" ? dock.width - 4 : 0
        y: dock.pos === "bottom" ? dock.height - 4 : 0
        HoverHandler { id: stripHover }
    }
    // pointer over the edge strip or the dock itself
    readonly property bool hovered: stripHover.hovered || frameHover.hovered
    onHoveredChanged: if (hovered) { hideTimer.stop(); revealed = true; } else if (hide) hideTimer.restart()
    Timer {
        id: hideTimer
        interval: 700
        onTriggered: if (dock.hide && !dock.hovered && dock.menuFor === "") dock.revealed = false
    }
    onHideChanged: revealed = !hide
    onMenuForChanged: if (menuFor === "" && hide && !hovered) hideTimer.restart()

    // ---- the dock itself
    Item {
        id: frame
        width: dock.vertical ? dock.thick : dock.width
        height: dock.vertical ? dock.height : dock.thick
        x: dock.pos === "left" && dock.hide ? dock.gap : 0
        y: 0
        HoverHandler { id: frameHover }
        transform: Translate {
            x: dock.revealed ? 0 : (dock.pos === "left" ? -dock.across : (dock.pos === "right" ? dock.across : 0))
            y: dock.revealed || dock.pos !== "bottom" ? 0 : dock.across
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        // background: a raised 9x panel, frosted glass, flat, your accent, or nothing
        Bevel {
            anchors.fill: parent
            visible: Theme.dockStyle === "panel" || Theme.dockStyle === "accent"
            radius: Theme.radius
            fill: Theme.dockStyle === "accent" ? Theme.accent : Theme.face
            fillOpacity: Theme.dockStyle === "accent" ? 1 : Theme.panelOpacity
        }
        Rectangle {
            anchors.fill: parent
            visible: Theme.dockStyle === "glass"
            radius: Math.max(Theme.radius, 6)
            color: Qt.rgba(Theme.face.r, Theme.face.g, Theme.face.b, 0.45)
            border.color: Qt.rgba(1, 1, 1, 0.25)
            border.width: 1
        }
        Rectangle {
            anchors.fill: parent
            visible: Theme.dockStyle === "flat"
            radius: Theme.radius
            color: Theme.face
            border.color: Theme.dark
            border.width: 1
        }

        Grid {
            id: grid
            anchors.centerIn: parent
            columns: dock.vertical ? 1 : Math.max(1, dock.items.length)
            spacing: 6
            Repeater {
                model: dock.items
                Item {
                    id: tile
                    required property var modelData
                    readonly property var wins: dock.windowsOf(modelData)
                    width: dock.tileS
                    height: dock.tileS
                    Bevel {
                        anchors.fill: parent
                        visible: Theme.dockButtons
                        sunken: ma.pressed || dock.menuFor === tile.modelData.id
                        fill: ma.containsMouse ? Theme.face2 : Theme.face
                        radius: Theme.radiusSm
                    }
                    Rectangle {      // plain icons: a soft highlight instead of a button
                        anchors.fill: parent
                        visible: !Theme.dockButtons && (ma.containsMouse || dock.menuFor === tile.modelData.id)
                        color: Qt.rgba(1, 1, 1, 0.18)
                        radius: Theme.radiusSm
                    }
                    IconImage {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: ma.pressed ? 1 : 0
                        implicitSize: Theme.dockGrow && ma.containsMouse ? dock.icon + 8 : dock.icon
                        Behavior on implicitSize { NumberAnimation { duration: 90 } }
                        source: Quickshell.iconPath(tile.modelData.entry && tile.modelData.entry.icon ? tile.modelData.entry.icon : tile.modelData.id,
                                                    "application-x-executable")
                    }
                    Rectangle {      // running: a little bar on the screen-edge side
                        visible: tile.wins.length > 0
                        readonly property bool on: tile.wins.some(w => w.activated)
                        width: dock.vertical ? 3 : (on ? 12 : 6)
                        height: dock.vertical ? (on ? 12 : 6) : 3
                        x: dock.pos === "left" ? -5 : (dock.pos === "right" ? tile.width + 2 : (tile.width - width) / 2)
                        y: dock.pos === "bottom" ? tile.height + 2 : (tile.height - height) / 2
                        color: on ? Theme.accent : Theme.text
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                menu.item = tile.modelData;
                                menu.wins = tile.wins;
                                const c = tile.mapToItem(null, tile.width / 2, tile.height / 2);
                                menu.at = dock.screenPoint(c.x, c.y);
                                dock.menuFor = tile.modelData.id;
                            } else if (mouse.button === Qt.MiddleButton || tile.wins.length === 0) {
                                if (tile.modelData.entry) tile.modelData.entry.execute();
                            } else {
                                // already in front: cycle through its windows
                                const i = tile.wins.findIndex(w => w.activated);
                                tile.wins[(i + 1) % tile.wins.length].activate();
                            }
                        }
                    }
                }
            }
        }
    }

    // where a point of this window is on the screen (for the menu)
    function screenPoint(x, y) {
        const sw = dock.screen ? dock.screen.width : 1920, sh = dock.screen ? dock.screen.height : 1080;
        const m = hide ? 0 : gap;
        const ox = pos === "bottom" ? (sw - dock.width) / 2 : (pos === "left" ? m : sw - m - dock.width);
        const oy = pos === "bottom" ? sh - m - dock.height : (sh - dock.height) / 2;
        return Qt.point(ox + x, oy + y);
    }

    // ---- right-click menu
    QtObject {
        id: menu
        property var item: null
        property var wins: []
        property point at: Qt.point(0, 0)
        readonly property var entries: {
            const it = menu.item;
            if (!it) return [];
            const l = [];
            l.push({ label: menu.wins.length > 0 ? "New window" : "Open", act: () => { if (it.entry) it.entry.execute(); } });
            if (it.pinned) {
                const i = Theme.dockPinned.indexOf(it.id), n = Theme.dockPinned.length;
                if (i > 0) l.push({ label: dock.vertical ? "Move up" : "Move left", act: () => Theme.dockMove(it.id, -1) });
                if (i >= 0 && i < n - 1) l.push({ label: dock.vertical ? "Move down" : "Move right", act: () => Theme.dockMove(it.id, 1) });
                l.push({ label: "Unpin from the dock", act: () => Theme.dockUnpin(it.id) });
            } else {
                l.push({ label: "Pin to the dock", act: () => Theme.dockPin(it.entry && it.entry.id ? it.entry.id : it.id) });
            }
            if (menu.wins.length > 0)
                l.push({ label: menu.wins.length > 1 ? "Close all " + menu.wins.length + " windows" : "Close", act: () => menu.wins.forEach(w => w.close()) });
            l.push({ sep: true });
            l.push({ label: "Dock settings…", act: () => Quickshell.execDetached(["bevelctl", "settings", "show"]) });
            return l;
        }
    }
    LazyLoader {
        active: dock.menuFor !== ""
        PanelWindow {
            id: mw
            screen: dock.screen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "bevel-dock-menu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: dock.menuFor = ""
            }
            Item { anchors.fill: parent; focus: true; Keys.onEscapePressed: dock.menuFor = "" }
            Bevel {
                id: box
                readonly property int off: dock.tileS / 2 + 12
                width: 210
                height: col.implicitHeight + 8
                x: Math.max(4, Math.min(mw.width - width - 4,
                       dock.pos === "bottom" ? menu.at.x - width / 2 : (dock.pos === "left" ? menu.at.x + off : menu.at.x - off - width)))
                y: Math.max(4, Math.min(mw.height - height - 4,
                       dock.pos === "bottom" ? menu.at.y - off - height : menu.at.y - height / 2))
                radius: Theme.radius
                fillOpacity: 1
                padding: 0
                MouseArea { anchors.fill: parent }
                Column {
                    id: col
                    x: 4; y: 4
                    width: parent.width - 8
                    BText {
                        width: parent.width
                        leftPadding: 8
                        height: Theme.fontSize + 10
                        verticalAlignment: Text.AlignVCenter
                        text: menu.item ? dock.nameOf(menu.item) : ""
                        font.bold: true
                        color: Theme.textDim
                    }
                    Repeater {
                        model: menu.entries
                        Item {
                            id: row
                            required property var modelData
                            width: col.width
                            height: modelData.sep ? 8 : Theme.fontSize + 12
                            Rectangle {
                                visible: !!row.modelData.sep
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 1; color: Theme.lo
                                Rectangle { y: 1; width: parent.width; height: 1; color: Theme.hi }
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: !row.modelData.sep && rma.containsMouse
                                color: Theme.accent
                            }
                            BText {
                                id: lbl
                                visible: !row.modelData.sep
                                anchors.verticalCenter: parent.verticalCenter
                                x: 16
                                text: row.modelData.label || ""
                                color: rma.containsMouse ? Theme.accentText : Theme.text
                            }
                            MouseArea {
                                id: rma
                                anchors.fill: parent
                                enabled: !row.modelData.sep
                                hoverEnabled: true
                                onClicked: { const f = row.modelData.act; dock.menuFor = ""; if (f) f(); }
                            }
                        }
                    }
                }
            }
        }
    }
}
