import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Io
import QtQuick

// Alt+Tab, Windows 95 style: a grey box with the open windows' icons in a row and the
// picked window's title underneath. Keep Alt down and press Tab to move; let go to switch.
// Hyprland calls `qs -c bevel ipc call switcher next|prev` on Alt+Tab / Alt+Shift+Tab.
Scope {
    id: root
    property bool open: false
    property var wins: []            // [{address, cls, title, entry, top}] most recently used first
    property int sel: 0
    property int pendingSteps: 0     // Tabs pressed before the list arrived

    IpcHandler {
        target: "switcher"
        function next(): void { root.step(1); }
        function prev(): void { root.step(-1); }
        function cancel(): void { root.open = false; }
    }
    function step(d) {
        if (!root.open) {
            root.open = true;
            root.sel = 0;
            root.pendingSteps = d;
            clients.running = true;
            return;
        }
        if (root.wins.length === 0) { root.pendingSteps += d; return; }
        root.sel = ((root.sel + d) % root.wins.length + root.wins.length) % root.wins.length;
    }
    function toplevelFor(c) {
        const l = ToplevelManager.toplevels.values;
        let best = null;
        for (let i = 0; i < l.length; i++) {
            if ((l[i].appId || "") === c.cls && (l[i].title || "") === c.title) return l[i];
            if ((l[i].appId || "") === c.cls && !best) best = l[i];
        }
        return best;
    }
    // The switcher holds the keyboard while it's open, and Hyprland won't hand focus to a window
    // while a layer like that is still on screen. So it closes first, and the window is focused
    // a moment later, by its exact address (two windows of one app can share a title).
    property var picked: null
    function commit() {
        if (!root.open) return;
        root.picked = root.wins[root.sel] || null;
        root.open = false;
        if (root.picked) focusLater.restart();
    }
    Timer {
        id: focusLater
        interval: 40
        onTriggered: {
            const w = root.picked;
            root.picked = null;
            if (!w) return;
            const t = root.toplevelFor(w);
            if (t) t.activate();
            Quickshell.execDetached(["bevelctl", "focus", w.address]);
        }
    }

    Process {
        id: clients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let l = [];
                try { l = JSON.parse(text); } catch (e) {}
                l = l.filter(c => c.mapped !== false && !c.hidden && (c.workspace ? c.workspace.id > 0 : true))
                     .sort((a, b) => (a.focusHistoryID ?? 99) - (b.focusHistoryID ?? 99));
                root.wins = l.map(c => ({
                    address: c.address, cls: c.class || c.initialClass || "", title: c.title || c.class || "",
                    ws: c.workspace ? c.workspace.name : "",
                    entry: DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(c.class || "") : DesktopEntries.byId(c.class || "")
                }));
                if (root.wins.length === 0) { root.open = false; return; }
                root.sel = ((root.pendingSteps % root.wins.length) + root.wins.length) % root.wins.length;
                root.pendingSteps = 0;
            }
        }
    }

    LazyLoader {
        active: root.open && root.wins.length > 0
        PanelWindow {
            // on the monitor you're using (Settings → Windows & display has the main one)
            screen: Ui.focusedScreen
            PopupHold {}
            id: win
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "bevel-switcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Item {
                anchors.fill: parent
                focus: true
                // letting go of Alt picks the window (Enter too); Esc cancels
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta || !(event.modifiers & Qt.AltModifier)) {
                        root.commit();
                        event.accepted = true;
                    }
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) { root.open = false; event.accepted = true; }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { root.commit(); event.accepted = true; }
                    else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { root.step(1); event.accepted = true; }
                    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) { root.step(-1); event.accepted = true; }
                }
            }
            MouseArea { anchors.fill: parent; onClicked: root.open = false }

            Bevel {
                id: box
                anchors.centerIn: parent
                readonly property int perRow: Math.min(root.wins.length, 9)
                width: Math.max(320, perRow * 58 + 24)
                height: grid.height + title.height + 34
                radius: Theme.radius
                fillOpacity: 1
                padding: 2
                MouseArea { anchors.fill: parent }
                Grid {
                    id: grid
                    x: (parent.width - width) / 2
                    y: 12
                    columns: box.perRow
                    spacing: 6
                    Repeater {
                        model: root.wins
                        Item {
                            id: cell
                            required property var modelData
                            required property int index
                            width: 52; height: 52
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: Theme.dark
                                border.width: 2
                                visible: cell.index === root.sel
                                Rectangle { anchors.fill: parent; anchors.margins: 2; color: "transparent"; border.color: Theme.hi; border.width: 1 }
                            }
                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 36
                                source: Quickshell.iconPath(cell.modelData.entry && cell.modelData.entry.icon ? cell.modelData.entry.icon : cell.modelData.cls.toLowerCase(),
                                                            "application-x-executable")
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.sel = cell.index
                                onClicked: { root.sel = cell.index; root.commit(); }
                            }
                        }
                    }
                }
                Bevel {
                    id: title
                    x: 10
                    y: grid.y + grid.height + 10
                    width: parent.width - 24
                    height: Theme.fontSize + 12
                    sunken: true
                    fill: Theme.face
                    BText {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        horizontalAlignment: Text.AlignHCenter
                        readonly property var w: root.wins[root.sel]
                        text: w ? w.title + (w.ws && w.ws !== "" ? "   ·   workspace " + w.ws : "") : ""
                    }
                }
            }
        }
    }
}
