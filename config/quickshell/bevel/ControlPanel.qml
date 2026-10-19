import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Control Panel on Hyprland (Super+A, or the bar button from Settings → Bar): a panel down the
// right edge of the screen. The contents live in ControlBody.qml (shared with the bar menus).
Scope {
    id: root

    IpcHandler {
        target: "controlpanel"
        function toggle(): void { Ui.controlOpen = !Ui.controlOpen; }
        function show(): void { Ui.controlOpen = true; }
        function hide(): void { Ui.controlOpen = false; }
    }

    // built once in the background after login (or on first use), then only shown and hidden
    property bool warm: false
    Timer { interval: 4000; running: true; onTriggered: root.warm = true }
    Connections { target: Ui; function onControlOpenChanged() { if (Ui.controlOpen) root.warm = true; } }

    LazyLoader {
        active: root.warm

        PanelWindow {
            // on the monitor you're using (Settings → Windows & display has the main one)
            screen: Ui.focusedScreen
            PopupHold { active: Ui.controlOpen }
            id: win
            visible: Ui.controlOpen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Normal
            color: "transparent"
            WlrLayershell.namespace: "bevel-controlpanel"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            MouseArea { anchors.fill: parent; onClicked: Ui.controlOpen = false }
            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Ui.controlOpen = false
            }

            // a panel along the right edge, the full height of the screen. It keeps the same gap
            // as the bar: a floating bar gets a gap all round, a bar flush with the edge gets none.
            readonly property int gap: Theme.barFloating ? Theme.gapsOut : 0
            Bevel {
                id: panel
                width: 410
                x: parent.width - width - win.gap
                y: win.gap
                height: parent.height - 2 * win.gap
                radius: win.gap > 0 ? Theme.radius : 0
                fillOpacity: Theme.panelOpacity
                padding: 0
                // slides in from the edge each time it opens
                transform: Translate { id: slide; x: 0 }
                NumberAnimation { id: slideIn; target: slide; property: "x"; from: panel.width + win.gap; to: 0; duration: 200; easing.type: Easing.OutCubic }
                Connections { target: Ui; function onControlOpenChanged() { if (Ui.controlOpen) slideIn.restart(); } }
                Component.onCompleted: if (Ui.controlOpen) slideIn.restart()
                MouseArea { anchors.fill: parent; onWheel: wheel => wheel.accepted = true }   // keep clicks inside
                Dither { anchors.fill: parent; visible: Theme.dither }
                ControlBody {
                    anchors.fill: parent
                    shown: Ui.controlOpen
                    onCloseRequested: Ui.controlOpen = false
                }
            }
        }
    }
}
