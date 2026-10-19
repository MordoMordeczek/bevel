import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// The bar's little menus (Hyprland): click the clock, battery, volume, network or CPU on the bar —
// or the matching desktop widget — and a panel drops down under it. The contents are the same parts
// as in the control panel (ControlBody.qml), just fewer of them and always open.
// `qs -c bevel ipc call flyout toggle clock` (or `bevelctl flyout clock`) opens one from anywhere.
Scope {
    id: root

    // which parts of the control panel each menu shows
    readonly property var parts: ({
        clock: ["clock", "calendar", "worldclock", "timer"],
        battery: ["battery", "display"],
        sound: ["sound", "media"],
        network: ["wifi", "bt"],
        system: ["system"],
        notifs: ["notifs"]
    })
    readonly property var titles: ({ clock: "Date & time", battery: "Power", sound: "Sound", network: "Network",
                                     system: "System", notifs: "Notifications" })

    function open(kind, x, screen) {
        if (!root.parts[kind]) return;
        Ui.controlOpen = false;
        Ui.flyoutScreen = screen || null;
        Ui.flyoutX = x === undefined ? -1 : x;
        Ui.flyout = kind;
    }

    Connections { target: Ui; function onControlOpenChanged() { if (Ui.controlOpen) Ui.flyout = ""; } }

    IpcHandler {
        target: "flyout"
        function toggle(kind: string): void { if (Ui.flyout === kind) Ui.flyout = ""; else root.open(kind); }
        function show(kind: string): void { root.open(kind); }
        function hide(): void { Ui.flyout = ""; }
    }

    // built once in the background after login (or on first use), then only shown and hidden
    property bool warm: false
    Timer { interval: 5000; running: true; onTriggered: root.warm = true }
    Connections { target: Ui; function onFlyoutChanged() { if (Ui.flyout !== "") root.warm = true; } }

    LazyLoader {
        active: root.warm

        PanelWindow {
            id: win
            screen: Ui.flyoutScreen || Ui.focusedScreen
            readonly property bool open: Ui.flyout !== "" && root.parts[Ui.flyout] !== undefined
            visible: open
            PopupHold { active: win.open }
            anchors { top: true; bottom: true; left: true; right: true }
            // the whole screen, bar included: a click anywhere — also on the bar — reaches this window
            // straight away (a click on the bar item that opened it closes it again)
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "bevel-flyout"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            // the menu showing (kept while hidden, so nothing reshuffles as it closes)
            property string kind: "clock"
            Connections {
                target: Ui
                function onFlyoutChanged() {
                    if (Ui.flyout === "" || root.parts[Ui.flyout] === undefined) return;
                    win.kind = Ui.flyout;
                    dropIn.restart();
                }
            }
            readonly property int gap: Theme.barFloating ? Theme.gapsOut : 4
            // the bar's strip at the top (or bottom) of the screen
            readonly property int barSpace: Theme.barHeight + (Theme.barFloating ? Theme.gapsOut : 0)
            // under the item it came from; from a widget (or the keyboard): under that item on the bar
            readonly property real ax: {
                if (Ui.flyoutX >= 0) return Ui.flyoutX;
                const all = Ui.anchorsFor(win.screen);
                const a = all[win.kind];
                if (a !== undefined) return a;
                const c = all.clock;
                return c !== undefined ? c : win.width - 200;
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onPressed: mouse => {
                    const onBar = Theme.barTop ? mouse.y < win.barSpace + 2 : mouse.y > win.height - win.barSpace - 2;
                    if (onBar && mouse.button === Qt.LeftButton) {
                        // which bar menu item is under the pointer? the same one = close, another = switch
                        let best = "", dist = 46;
                        const a = Ui.anchorsFor(win.screen);
                        for (const k in a) {
                            const d = Math.abs(a[k] - mouse.x);
                            if (d < dist) { dist = d; best = k; }
                        }
                        if (best !== "" && best !== win.kind) {
                            Ui.flyoutX = a[best];
                            Ui.flyout = best;
                            return;
                        }
                    }
                    Ui.flyout = "";
                }
            }
            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Ui.flyout = ""
            }

            Bevel {
                id: panel
                width: win.kind === "clock" ? 360 : (win.kind === "network" ? 420 : 370)
                height: Math.min(win.height - win.barSpace - 2 * win.gap, body.contentHeight + 4)
                x: Math.max(win.gap, Math.min(win.width - width - win.gap, Math.round(win.ax - width / 2)))
                y: Theme.barTop ? win.barSpace + win.gap : win.height - win.barSpace - height - win.gap
                radius: Theme.radius
                fillOpacity: Math.max(0.97, Theme.panelOpacity)
                padding: 0
                clip: true
                // drop down from the bar (or rise from a bottom bar)
                transform: Translate { id: slide; y: 0 }
                ParallelAnimation {
                    id: dropIn
                    NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: 140 }
                    NumberAnimation { target: slide; property: "y"; from: Theme.barTop ? -14 : 14; to: 0; duration: 160; easing.type: Easing.OutCubic }
                }
                Component.onCompleted: if (win.open) { win.kind = Ui.flyout; dropIn.restart(); }

                MouseArea { anchors.fill: parent; onWheel: wheel => wheel.accepted = true }   // keep clicks inside
                Dither { anchors.fill: parent; visible: Theme.dither }

                ControlBody {
                    id: body
                    anchors.top: parent.top
                    anchors.topMargin: 2
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    only: root.parts[win.kind] || []
                    shown: win.open
                    onCloseRequested: Ui.flyout = ""
                }
            }
        }
    }
}
