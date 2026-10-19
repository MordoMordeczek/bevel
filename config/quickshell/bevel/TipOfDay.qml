import Quickshell
import Quickshell.Io
import QtQuick

// "Welcome to Bevel — Did you know…?" Shown once per login (fun.tips), like Windows 95 did.
Scope {
    id: root
    readonly property string sig: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""
    property int tip: Math.floor(Math.random() * tips.length)

    readonly property var tips: [
        "Super+W picks a random wallpaper, and the whole desktop repaints itself in its colours.",
        "Super+I opens Bevel Settings. Try Desktop style → Taskbar for a Windows 95 bottom bar.",
        "Super+R has three looks: the Run box, a Program Manager grid, or a Start menu. Pick one in Desktop style.",
        "In the Run box, type =12*7 to use it as a calculator. Enter copies the answer.",
        "Super+Shift+Z starts the screensaver. Starfield, Mystify or Pipes: your call.",
        "Print takes a screenshot of a region, Shift+Print the whole screen, Super+Print one window.",
        "Super+S hides windows in a scratchpad; Super+Alt+S sends the current one there.",
        "Your own Hyprland tweaks go in ~/.config/hypr/user.lua. Bevel never touches that file.",
        "Right-click an icon in the Dock layout to pin or unpin it.",
        "fastfetch knows the rice. Open a terminal and run it.",
        "Turn on the \"" + Theme.btwLabel + "\" badge in Settings → Fun. Then click it.",
        "Rounded corners? Never heard of them. (Settings → Retro style, if you insist.)",
        "Type \"sheep\" in Super+R. Then click the sheep. Then type \"party\".",
        "Super+L has three looks too: the classic dialog, big tiles, or a small drop-down. Settings → Desktop style.",
        "Type \"fortune\" in Super+R when you need wisdom. Or at least a fortune cookie.",
        "Some old cheat codes still work in the Run box. ↑ ↑ ↓ ↓ …",
        "Whatever you do, don't click the logo on the About page."
    ]

    FileView {
        id: seen
        path: Quickshell.env("HOME") + "/.cache/bevel/tip-session"
        blockLoading: true
        printErrors: false
    }
    Component.onCompleted: {
        if (Theme.tips && root.sig !== "" && (seen.text() || "").trim() !== root.sig) {
            showTimer.start();
        }
    }
    Timer { id: showTimer; interval: 2500; onTriggered: { Ui.tipOpen = true; seen.setText(root.sig); } }

    IpcHandler {
        target: "tips"
        function show(): void { Ui.tipOpen = true; }
    }

    LazyLoader {
        active: Ui.tipOpen
        FloatingWindow {
            title: "Tip of the Day"
            implicitWidth: 480
            implicitHeight: 290
            color: Theme.face
            onClosed: Ui.tipOpen = false

            Bevel {
                anchors.fill: parent
                padding: 10
                Item {
                    id: body
                    anchors.fill: parent
                    BText {
                        id: heading
                        text: "Welcome to Bevel"
                        font.bold: true
                        font.pixelSize: Theme.fontSize + 6
                    }
                    // the white "Did you know" panel
                    Bevel {
                        id: panel
                        anchors.top: heading.bottom
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.right: buttons.left
                        anchors.rightMargin: 10
                        anchors.bottom: showBox.top
                        anchors.bottomMargin: 8
                        sunken: true
                        fill: Theme.base
                        // light bulb, in pixels
                        Item {
                            id: bulb
                            x: 10; y: 10
                            width: 28; height: 40
                            Rectangle { x: 4; y: 0; width: 20; height: 22; radius: 10; color: "#fff3a0"; border.color: Theme.dark }
                            Rectangle { x: 9; y: 22; width: 10; height: 8; color: Theme.lo; border.color: Theme.dark }
                            Rectangle { x: 10; y: 30; width: 8; height: 3; color: Theme.dark }
                        }
                        BText {
                            id: dyk
                            anchors.left: bulb.right; anchors.leftMargin: 12
                            y: 12
                            text: "Did you know…"
                            font.bold: true
                        }
                        Rectangle {
                            anchors.left: dyk.left
                            anchors.right: parent.right; anchors.rightMargin: 10
                            anchors.top: dyk.bottom; anchors.topMargin: 6
                            height: 1
                            color: Theme.lo
                        }
                        Text {
                            anchors.left: dyk.left
                            anchors.right: parent.right; anchors.rightMargin: 10
                            anchors.top: dyk.bottom; anchors.topMargin: 14
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                            text: root.tips[root.tip]
                            wrapMode: Text.Wrap
                            color: Theme.text
                            font.family: Theme.font
                            font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
                            font.pixelSize: Theme.fontSize
                            lineHeight: 1.15
                        }
                    }
                    Column {
                        id: buttons
                        anchors.top: panel.top
                        anchors.right: parent.right
                        width: 104
                        spacing: 6
                        SButton { width: parent.width; text: "Next Tip"; onClicked: root.tip = (root.tip + 1) % root.tips.length }
                        SButton { width: parent.width; text: "Close"; onClicked: Ui.tipOpen = false }
                    }
                    SCheck {
                        id: showBox
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        text: "Show tips at login"
                        checked: Theme.tips
                        onToggled: v => Theme.set("fun.tips", v)
                    }
                }
            }
        }
    }
}
