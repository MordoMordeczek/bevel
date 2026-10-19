//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// Bevel — a 9x-flavoured shell for Hyprland. Start with: qs -c bevel
ShellRoot {
    id: shell

    // the bar layout you picked in Settings → Desktop style
    Variants {
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property var modelData
            LazyLoader {
                // desktop layer: animated background and/or widgets
                active: Theme.liveMode || Theme.widgetsOn || Theme.fxOn
                Background { modelData: perScreen.modelData }
            }
            LazyLoader {
                active: Theme.barLayout === "bevel" || Theme.barLayout === "dock"
                Bar { modelData: perScreen.modelData }
            }
            LazyLoader {
                active: Theme.barLayout === "taskbar"
                BarTaskbar { modelData: perScreen.modelData }
            }
            LazyLoader {
                active: Theme.barLayout === "island"
                BarIsland { modelData: perScreen.modelData }
            }
            LazyLoader {
                // the dock: on the main display, or on every monitor
                active: Theme.barLayout === "dock" && (Theme.sv("dock.allScreens", false) || Ui.primaryScreen === null
                                                        || perScreen.modelData.name === Ui.primaryScreen.name)
                Dock { modelData: perScreen.modelData }
            }
        }
    }

    Launcher {}
    PowerMenu {}
    Notifs {}
    Osd {}
    // Bevel Settings is its own app now (settings.qml); these keep `qs ipc call settings …` working
    IpcHandler {
        target: "settings"
        function toggle(): void { Quickshell.execDetached(["bevelctl", "settings", "toggle"]); }
        function show(): void { Quickshell.execDetached(["bevelctl", "settings", "show"]); }
        function hide(): void { Quickshell.execDetached(["bevelctl", "settings", "hide"]); }
    }
    Loading {}
    Screensaver {}
    TipOfDay {}
    Pet {}
    Opsec {}
    ControlPanel {}
    Flyouts {}
    Switcher {}
    Clipboard {}

    // Keep window geometry fresh for the workspace minimaps.
    Timer {
        id: refresh
        interval: 120
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
        }
    }
    Timer {
        // resizes don't emit events, so poll gently too (only the window maps on the bar need it)
        interval: 2500
        running: Theme.minimaps
        repeat: true
        onTriggered: Hyprland.refreshToplevels()
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "movewindowv2"
                    || n === "changefloatingmode" || n === "workspace" || n === "workspacev2"
                    || n === "activewindowv2" || n === "fullscreen" || n === "createworkspacev2"
                    || n === "destroyworkspacev2" || n === "monitoradded" || n === "monitorremoved") {
                if (n === "monitoradded" || n === "monitorremoved")
                    Hyprland.refreshMonitors();
                refresh.restart();
            }
        }
    }
    Component.onCompleted: {
        Hyprland.refreshMonitors();
        Hyprland.refreshToplevels();
    }
}
