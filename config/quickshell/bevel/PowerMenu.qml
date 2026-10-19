import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Super+L — leave the session. Three looks (Settings → Desktop style → Shut-down menu):
//   dialog    the classic "Shut Down" dialog with radio buttons
//   tiles     five big icon tiles across the middle of the screen
//   dropdown  a small menu dropping from the bar's corner
// Arrows/Tab pick · Enter or 1–5 confirm · Esc cancels.
Scope {
    id: root
    property bool open: false
    property string farewell: ""     // the "It's now safe to turn off your computer" screen
    property var pending: null

    readonly property string style: {
        const s = Theme.sv("power.style", "dialog");
        return ["dialog", "tiles", "dropdown"].indexOf(s) >= 0 ? s : "dialog";
    }
    readonly property bool safeScreen: Theme.sv("power.safeScreen", true)

    readonly property var actions: [
        { label: "Lock", icon: "lock", cmd: ["hyprlock"] },
        { label: "Log out", icon: "logout", cmd: ["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"] },
        { label: "Suspend", icon: "suspend", cmd: ["sh", "-c", "(hyprlock &) ; sleep 0.6 ; systemctl suspend 2>/dev/null || loginctl suspend"] },
        { label: "Restart", icon: "restart", cmd: ["sh", "-c", "systemctl reboot 2>/dev/null || loginctl reboot"], bye: "Please wait while your\ncomputer restarts…" },
        { label: "Shut down", icon: "shutdown", cmd: ["sh", "-c", "systemctl poweroff 2>/dev/null || loginctl poweroff"], bye: "It's now safe to turn off\nyour computer." }
    ]

    function run(a) {
        root.open = false;
        if (a.bye && root.safeScreen) {
            root.pending = a.cmd;
            root.farewell = a.bye;
            byeTimer.restart();
        } else {
            Quickshell.execDetached(a.cmd);
        }
    }
    Timer { id: byeTimer; interval: 2200; onTriggered: if (root.pending) Quickshell.execDetached(root.pending) }

    IpcHandler {
        target: "power"
        function toggle(): void { root.open = !root.open; }
        function show(): void { root.open = true; }
        function hide(): void { root.open = false; }
    }

    // ---- the farewell screen
    LazyLoader {
        active: root.farewell !== ""
        PanelWindow {
            screen: Ui.focusedScreen
            PopupHold {}
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            WlrLayershell.namespace: "bevel-farewell"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            Text {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                text: root.farewell
                color: "#ff9a1f"
                font.family: Theme.font
                font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
                font.pixelSize: 44
                lineHeight: 1.2
            }
            // changed your mind? Esc cancels in the moment before it happens
            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: { byeTimer.stop(); root.pending = null; root.farewell = ""; }
            }
        }
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            screen: Ui.focusedScreen
            PopupHold {}
            id: win
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "bevel-power"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            property int sel: root.style === "tiles" ? 4 : 0
            function go() { root.run(root.actions[win.sel]); }

            // dithered dim, like the classic shut-down screen (not for the small dropdown)
            Image {
                anchors.fill: parent
                visible: root.style !== "dropdown"
                source: Qt.resolvedUrl("dither.png")
                fillMode: Image.Tile
                smooth: false
                opacity: 0.9
            }
            MouseArea { anchors.fill: parent; onClicked: root.open = false }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    const n = root.actions.length;
                    const k = event.key;
                    const horiz = root.style === "tiles";
                    if (k === Qt.Key_Escape) root.open = false;
                    else if (k === (horiz ? Qt.Key_Right : Qt.Key_Down) || k === Qt.Key_Tab) win.sel = (win.sel + 1) % n;
                    else if (k === (horiz ? Qt.Key_Left : Qt.Key_Up) || k === Qt.Key_Backtab) win.sel = (win.sel + n - 1) % n;
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) win.go();
                    else if (k >= Qt.Key_1 && k <= Qt.Key_5) { win.sel = k - Qt.Key_1; win.go(); }
                    else return;
                    event.accepted = true;
                }
            }

            // ======================================================== dialog
            Bevel {
                visible: root.style === "dialog"
                anchors.centerIn: parent
                width: 380
                height: dcol.implicitHeight + 12
                radius: Theme.radius
                padding: 2
                MouseArea { anchors.fill: parent }
                ColumnLayout {
                    id: dcol
                    anchors.fill: parent
                    spacing: 10
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Theme.fontSize + 10
                        color: Theme.accent
                        radius: Theme.radiusSm
                        BText {
                            anchors.left: parent.left; anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Shut Down " + Theme.distro; font.bold: true; color: Theme.accentText
                        }
                    }
                    RowLayout {
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        spacing: 14
                        Item {      // little monitor
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: 40; implicitHeight: 40
                            Rectangle { x: 2; y: 4; width: 36; height: 24; color: Theme.face; border.color: Theme.dark; border.width: 2 }
                            Rectangle { x: 6; y: 8; width: 28; height: 16; color: Theme.accent }
                            Rectangle { x: 15; y: 28; width: 10; height: 4; color: Theme.lo }
                            Rectangle { x: 9; y: 32; width: 22; height: 4; color: Theme.face; border.color: Theme.dark }
                        }
                        ColumnLayout {
                            spacing: 4
                            BText { text: "What do you want the computer to do?"; Layout.bottomMargin: 4 }
                            Repeater {
                                model: root.actions
                                Item {
                                    id: opt
                                    required property var modelData
                                    required property int index
                                    readonly property bool current: index === win.sel
                                    implicitWidth: optRow.implicitWidth + 8
                                    implicitHeight: Theme.fontSize + 10
                                    Row {
                                        id: optRow
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: 4
                                        spacing: 8
                                        Bevel {
                                            width: 12; height: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            sunken: true; depth: 1; fill: Theme.base
                                            radius: 6
                                            Rectangle { anchors.centerIn: parent; width: 4; height: 4; radius: 2; color: Theme.text; visible: opt.current }
                                        }
                                        BText { text: (opt.index + 1) + "  " + opt.modelData.label }
                                    }
                                    Rectangle { anchors.fill: parent; visible: opt.current; color: "transparent"; border.color: Theme.text; opacity: 0.6 }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: win.sel = opt.index
                                        onDoubleClicked: { win.sel = opt.index; win.go(); }
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        Layout.rightMargin: 10
                        Layout.bottomMargin: 8
                        spacing: 6
                        SButton { text: "OK"; onClicked: win.go(); highlighted: true }
                        SButton { text: "Cancel"; onClicked: root.open = false }
                    }
                }
            }

            // ======================================================== tiles
            Column {
                visible: root.style === "tiles"
                anchors.centerIn: parent
                spacing: 18
                BText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "See you later, " + (Quickshell.env("USER") || "friend") + "."
                    font.pixelSize: Theme.fontSize + 12
                    font.bold: true
                    color: "white"
                    style: Text.Outline
                    styleColor: Theme.dark
                }
                Row {
                    spacing: 14
                    Repeater {
                        model: root.actions
                        Bevel {
                            id: tile
                            required property var modelData
                            required property int index
                            readonly property bool current: index === win.sel
                            width: 112; height: 120
                            radius: Theme.radius
                            sunken: tileMa.pressed
                            fill: current ? Theme.accent : Theme.face
                            PowerGlyph {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 18
                                width: 44; height: 44
                                kind: tile.modelData.icon
                                color: tile.current ? Theme.accentText : Theme.text
                            }
                            BText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 74
                                text: tile.modelData.label
                                font.bold: true
                                color: tile.current ? Theme.accentText : Theme.text
                            }
                            BText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 94
                                text: String(tile.index + 1)
                                color: tile.current ? Theme.accentText : Theme.textDim
                                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                            }
                            MouseArea {
                                id: tileMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: win.sel = tile.index
                                onClicked: { win.sel = tile.index; win.go(); }
                            }
                        }
                    }
                }
                BText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "← → pick · Enter · Esc stay"
                    color: "white"
                    style: Text.Outline
                    styleColor: Theme.dark
                }
            }

            // ======================================================== dropdown
            Bevel {
                visible: root.style === "dropdown"
                x: win.width - width - (Theme.barLayout === "taskbar" ? 2 : Theme.gapsOut)
                y: Theme.barTop ? Theme.barHeight + 2 * Theme.gapsOut
                                : win.height - height - (Theme.barLayout === "taskbar" ? Theme.barHeight + 6 : Theme.barHeight + 2 * Theme.gapsOut)
                width: 230
                height: ddcol.implicitHeight + 8
                radius: Theme.radius
                padding: 2
                MouseArea { anchors.fill: parent }
                Column {
                    id: ddcol
                    width: parent.width
                    Rectangle {
                        width: parent.width
                        height: Theme.fontSize + 10
                        color: Theme.accent
                        BText {
                            anchors.left: parent.left; anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: Quickshell.env("USER") || "Session"; font.bold: true; color: Theme.accentText
                        }
                    }
                    Item { width: 1; height: 4 }
                    Repeater {
                        model: root.actions
                        Rectangle {
                            id: dd
                            required property var modelData
                            required property int index
                            readonly property bool current: index === win.sel
                            width: ddcol.width
                            height: Theme.fontSize + 16
                            color: current ? Theme.accent : "transparent"
                            PowerGlyph {
                                id: dg
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.fontSize + 4; height: width
                                kind: dd.modelData.icon
                                color: dd.current ? Theme.accentText : Theme.text
                            }
                            BText {
                                anchors.left: dg.right; anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: dd.modelData.label
                                color: dd.current ? Theme.accentText : Theme.text
                            }
                            BText {
                                anchors.right: parent.right; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: String(dd.index + 1)
                                color: dd.current ? Theme.accentText : Theme.textDim
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: win.sel = dd.index
                                onClicked: win.go()
                            }
                        }
                    }
                }
            }
        }
    }
}
