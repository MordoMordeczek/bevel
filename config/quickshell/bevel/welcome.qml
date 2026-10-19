//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell
import QtQuick
import QtQuick.Layouts
import "keys.js" as KeyList

// "Welcome to Bevel": a short tour on first login, and the keyboard cheat sheet (Super+F1).
// Start with: bevelctl welcome [keys]
ShellRoot {
    FloatingWindow {
        id: win
        title: "Welcome to Bevel"
        implicitWidth: 760
        implicitHeight: 520
        color: Theme.face
        onClosed: Qt.quit()

        readonly property bool xfce: false
        readonly property var keyGroups: KeyList.hypr
        readonly property var pages: [
            { id: "hello", title: "Welcome to Bevel" },
            { id: "basics", title: "The basics" },
            { id: "look", title: "Make it yours" },
            { id: "desktop", title: "Your desktop" },
            { id: "fun", title: "Just for fun" },
            { id: "keys", title: "Keyboard shortcuts" }
        ]
        property int page: (Quickshell.env("BEVEL_WELCOME_PAGE") || "") === "keys" ? 5 : 0
        function run(args) { Quickshell.execDetached(args); }
        // seen: don't open by itself at the next login (unless the box below is ticked)
        Component.onCompleted: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$HOME/.config/bevel\" && touch \"$HOME/.config/bevel/.welcome-shown\""])

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Qt.quit()
            Keys.onRightPressed: if (win.page < win.pages.length - 1) win.page++
            Keys.onLeftPressed: if (win.page > 0) win.page--
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 14

            // ---- the banner down the left, like the old Windows welcome screen
            Rectangle {
                Layout.preferredWidth: 190
                Layout.fillHeight: true
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.accent }
                    GradientStop { position: 1; color: Qt.darker(Theme.accent, 1.8) }
                }
                Column {
                    x: 14; y: 18
                    width: parent.width - 28
                    spacing: 6
                    BText { text: "Welcome to"; color: Theme.accentText; font.pixelSize: Theme.fontSize + 2 }
                    Logo { block: 5; word: "BEVEL" }
                    Item { width: 1; height: 16 }
                    Repeater {
                        model: win.pages
                        Rectangle {
                            required property var modelData
                            required property int index
                            width: parent.width
                            height: Theme.fontSize + 10
                            color: index === win.page ? Qt.rgba(1, 1, 1, 0.22) : "transparent"
                            BText {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                text: (index === win.page ? "▸ " : "   ") + modelData.title
                                color: Theme.accentText
                                font.bold: index === win.page
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.page = index }
                        }
                    }
                }
                PixIcon {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.margins: 14
                    kind: "monitor"
                    zoom: 4
                }
            }

            // ---- the page
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                BText {
                    text: win.pages[win.page].title
                    font.pixelSize: Theme.fontSize + 10
                    font.bold: true
                }
                Rectangle { Layout.fillWidth: true; height: 2; color: Theme.lo; Rectangle { y: 1; width: parent.width; height: 1; color: Theme.hi } }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: win.page

                    // hello
                    ColumnLayout {
                        spacing: 10
                        Para { text: "Bevel is a 9x-flavoured desktop: square corners, raised edges and colours that come from your wallpaper. " }
                        Para { text: "This short tour shows where things are. Use the arrows or the buttons below; you can open it again any time from the menu (\"Welcome to Bevel\") or with Super+F1." }
                        Tip { icon: "monitor"; text: "Bevel was made and tested on one laptop. If something looks wrong on yours, Bevel Settings → About → \"Make a bug report\" collects what's needed to fix it." }
                    }
                    // basics
                    ColumnLayout {
                        spacing: 8
                        Tip { icon: "app"; text: "<b>Run / launcher</b> — Super+R. Type to search apps; \"=12*7\" calculates." }
                        Tip { icon: "gear"; text: "<b>Control panel</b> — Super+A: Wi-Fi, Bluetooth, sound, brightness, battery, notifications and more." }
                        Tip { icon: "picture"; text: "<b>Bevel Settings</b> — Super+I: wallpaper, themes, colours, widgets, style." }
                        Tip { icon: "power"; text: "<b>Lock · log out · shut down</b> — Super+L (or Super+Esc to lock right away)." }
                        Tip { icon: "terminal"; text: "<b>Terminal</b> — Super+Q (floating) or Super+Shift+Q (tiled)." }
                        Item { Layout.fillHeight: true }
                    }
                    // look
                    ColumnLayout {
                        spacing: 8
                        Tip { icon: "picture"; text: "<b>Wallpaper</b> — pick a picture, or switch to <b>Animated</b> for 28 moving backgrounds in any colour. The whole desktop recolours itself to match." }
                        Tip { icon: "folder"; text: "<b>Themes</b> — save your whole look as one .bevel file, share it, or try the built-in ones (Windows 95, Vaporwave, Terminal…). Undo is one click." }
                        Tip { icon: "eye"; text: "<b>Look & colors</b> — black & white mode, dark panels, retro or modern icons." }
                        RowLayout {
                            spacing: 6
                            SButton { text: "Open Themes"; onClicked: win.run(["bevelctl", "settings", "show"]) }
                        }
                        Item { Layout.fillHeight: true }
                    }
                    // desktop
                    ColumnLayout {
                        spacing: 8
                        Tip { icon: "calendar"; text: "<b>Widgets</b> — clocks, calendar, system info, weather, a news ticker, Minesweeper, a Recycle Bin… Settings → Widgets. They line up by themselves." }
                        Tip { icon: "bell"; text: "<b>Notifications</b> — missed ones wait in the control panel. \"Quiet\" there stops pop-ups." }
                        Tip { icon: "note"; text: "<b>Clipboard</b> — Super+V shows what you copied before." }
                        Tip { icon: "app"; text: "<b>Alt+Tab</b> — hold Alt and tap Tab to pick a window." }
                        Item { Layout.fillHeight: true }
                    }
                    // fun
                    ColumnLayout {
                        spacing: 8
                        Tip { icon: "moon"; text: "<b>Screensavers</b> — Starfield, Mystify and Pipes" + (" (Super+Shift+Z).") }
                        Tip { icon: "user"; text: "<b>Bevvy the sheep</b> — a desktop pet. Settings → Fun. Click it." }
                        Tip { icon: "arch"; text: "<b>I use … btw</b> — a badge for the bar and a widget, for the important things in life." }
                        Tip { icon: "key"; text: "In the launcher, try typing <i>party</i>, <i>fortune</i> or an old cheat code. And click the logo on Settings → About." }
                        Item { Layout.fillHeight: true }
                    }
                    // keys
                    Item {
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: wheel => {
                                const dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 2;
                                kf.contentY = Math.max(0, Math.min(Math.max(0, kf.contentHeight - kf.height), kf.contentY - dy));
                            }
                            Flickable {
                                id: kf
                                anchors.fill: parent
                                clip: true
                                interactive: false
                                contentHeight: kgrid.implicitHeight
                                GridLayout {
                                    id: kgrid
                                    width: kf.width - 8
                                    columns: 2
                                    columnSpacing: 16
                                    rowSpacing: 10
                                    Repeater {
                                        model: win.keyGroups
                                        ColumnLayout {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignTop
                                            spacing: 2
                                            BText { text: modelData.group; font.bold: true; color: Theme.accent }
                                            Repeater {
                                                model: modelData.keys
                                                RowLayout {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    spacing: 6
                                                    Bevel {
                                                        implicitWidth: kcap.implicitWidth + 10
                                                        implicitHeight: Theme.fontSize + 6
                                                        depth: Math.min(2, Theme.bevel)
                                                        fill: Theme.face2
                                                        BText { id: kcap; anchors.centerIn: parent; text: modelData[0]; font.pixelSize: Math.max(10, Theme.fontSize - 3); font.bold: true }
                                                    }
                                                    BText { Layout.fillWidth: true; text: modelData[1]; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    SCheck {
                        text: "Show this at every login"
                        checked: Theme.sv("fun.welcome", false)
                        onToggled: v => Theme.setUi("fun.welcome", v)
                    }
                    Item { Layout.fillWidth: true }
                    SButton { text: "< Back"; visible: win.page > 0; onClicked: win.page-- }
                    SButton { text: win.page < win.pages.length - 1 ? "Next >" : "Done"; highlighted: true; onClicked: win.page < win.pages.length - 1 ? win.page++ : Qt.quit() }
                    SButton { text: "Close"; onClicked: Qt.quit() }
                }
            }
        }
    }

    component Para: BText {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        maximumLineCount: 6
        elide: Text.ElideNone
        lineHeight: 1.15
    }
    component Tip: RowLayout {
        property string icon: "gear"
        property string text: ""
        Layout.fillWidth: true
        spacing: 12
        PixIcon { kind: parent.icon; zoom: 2; Layout.alignment: Qt.AlignTop }
        BText {
            Layout.fillWidth: true
            text: parent.text
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideNone
            lineHeight: 1.1
        }
    }
}
