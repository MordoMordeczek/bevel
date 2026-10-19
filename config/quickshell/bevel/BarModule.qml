import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

// One thing on the bar, picked by id (the list is Theme.barModuleInfo). The status ones open
// their own menu when clicked: clock → calendar & clocks, battery → power, volume → sound…
Item {
    id: m
    property string mid: ""
    property var bar: null              // the bar's PanelWindow (tray menus, which screen)
    property real originX: 0            // where the bar window starts on its screen
    property var hmon: null
    property bool compact: false
    property real flexW: 220            // room for the window title / window buttons
    readonly property bool flex: mid === "title" || mid === "tasks"
    readonly property string menu: ({ clock: "clock", battery: "battery", volume: "sound", network: "network", cpu: "system",
                                      memory: "system", notifs: "notifs", media: "sound" })[mid] || ""
    readonly property bool menuOpen: menu !== "" && Ui.flyout === menu && Ui.flyoutScreen === (bar ? bar.screen : null)

    // some only show up when there is something to show
    readonly property bool shown: {
        switch (mid) {
        case "btw": return Theme.btw;
        case "tray": return SystemTray.items.values.length > 0;
        case "media": return m.player !== null && (m.player.trackTitle || "") !== "";
        case "volume": return Sys.sink !== null;
        case "battery": return Sys.hasBattery;
        default: return true;
        }
    }
    implicitWidth: shown && loader.item ? loader.item.implicitWidth + (menu !== "" ? 8 : 0) : 0
    implicitHeight: parent ? parent.height : Theme.barHeight
    width: flex ? Math.max(0, Math.min(implicitWidth, flexW)) : implicitWidth
    height: implicitHeight
    visible: shown

    function centreX() { return m.originX + m.mapToItem(null, m.width / 2, 0).x; }
    function openMenu() {
        if (m.menu === "") return;
        if (m.menuOpen) { Ui.flyout = ""; return; }
        Ui.flyoutScreen = m.bar ? m.bar.screen : null;
        Ui.flyoutX = m.centreX();
        Ui.flyout = m.menu;
    }
    // remember where our menu hangs, so a desktop widget can open it in the same place
    Timer {
        interval: 2500
        repeat: true
        running: m.menu !== "" && m.visible
        triggeredOnStart: true
        onTriggered: {
            const scr = m.bar && m.bar.screen ? m.bar.screen.name : "";
            const all = Object.assign({}, Ui.barAnchors);
            const a = Object.assign({}, all[scr] || {});
            const x = m.centreX();
            if (a[m.menu] === x) return;
            a[m.menu] = x;
            all[scr] = a;
            Ui.barAnchors = all;
        }
    }

    // pressed-in look while its menu is open, a light one on hover
    Bevel {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        visible: m.menu !== "" && (m.menuOpen || hover.containsMouse) && m.mid !== "clock"
        sunken: true
        depth: 1
        fill: m.menuOpen ? Theme.face2 : "transparent"
        radius: Theme.radiusSm
        opacity: m.menuOpen ? 1 : 0.7
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        enabled: m.menu !== ""
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: m.menu !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                if (m.mid === "volume" && Sys.sink && Sys.sink.audio) Sys.sink.audio.muted = !Sys.sink.audio.muted;
                else if (m.mid === "media" && m.player) m.player.togglePlaying();
                return;
            }
            m.openMenu();
        }
        onWheel: wheel => {
            if (m.mid !== "volume" || !Sys.sink || !Sys.sink.audio) return;
            const a = Sys.sink.audio;
            a.volume = Math.max(0, Math.min(1.5, a.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
        }
    }

    readonly property var player: {
        const l = Mpris.players.values;
        for (let i = 0; i < l.length; i++) if (l[i].isPlaying) return l[i];
        return l.length > 0 ? l[0] : null;
    }

    Loader {
        id: loader
        anchors.verticalCenter: parent.verticalCenter
        x: m.menu !== "" ? 4 : 0
        width: m.flex ? m.width : implicitWidth
        sourceComponent: ({
            start: startC, workspaces: wsC, title: titleC, tasks: tasksC, tray: trayC, media: mediaC, btw: btwC,
            cpu: cpuC, memory: memC, network: netC, volume: volC, battery: batC, notifs: notifC, control: ctlC,
            clock: clockC, sep: sepC, space: spaceC
        })[m.mid] || null
    }

    // ------------------------------------------------------------------ the modules
    Component {
        id: startC
        Bevel {
            id: start
            implicitWidth: startRow.implicitWidth + 16
            height: m.height - 2
            y: 1
            sunken: Ui.launcherOpen || startMa.pressed
            radius: Theme.radiusSm
            Row {
                id: startRow
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: start.sunken ? 1 : 0
                anchors.verticalCenterOffset: start.sunken ? 1 : 0
                spacing: 5
                Grid {     // four little panes, the Bevel logo
                    anchors.verticalCenter: parent.verticalCenter
                    columns: 2; spacing: 1
                    Rectangle { width: 6; height: 6; color: Theme.accent; border.color: Theme.dark }
                    Rectangle { width: 6; height: 6; color: Theme.accent2; border.color: Theme.dark }
                    Rectangle { width: 6; height: 6; color: Theme.face2; border.color: Theme.dark }
                    Rectangle { width: 6; height: 6; color: Theme.lo; border.color: Theme.dark }
                }
                BarText { text: "Start"; font.bold: true }
            }
            MouseArea { id: startMa; anchors.fill: parent; onClicked: Ui.launcherOpen = !Ui.launcherOpen }
        }
    }
    Component {
        id: wsC
        Row {
            id: wsRow
            spacing: 3
            height: m.height - 4
            readonly property int maxWs: {
                let x = 0;
                const list = Hyprland.workspaces.values;
                for (let i = 0; i < list.length; i++)
                    if (list[i].id > x && list[i].id < 100) x = list[i].id;
                return x;
            }
            // several monitors: each bar lists the workspaces on its own monitor (Settings → Bar)
            readonly property bool perMon: {
                const md = Theme.sv("bar.workspacesMode", "auto");
                return m.hmon !== null && (md === "monitor" || (md === "auto" && Quickshell.screens.length > 1));
            }
            readonly property var ids: {
                if (!wsRow.perMon) {
                    const r = [];
                    for (let i = 1; i <= Math.max(Theme.workspaces, wsRow.maxWs); i++) r.push(i);
                    return r;
                }
                const mine = Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor && w.monitor.name === m.hmon.name).map(w => w.id);
                const act = m.hmon.activeWorkspace;
                if (act && act.id > 0 && mine.indexOf(act.id) < 0) mine.push(act.id);
                return mine.sort((a, b) => a - b);
            }
            Repeater {
                model: wsRow.ids
                Minimap {
                    required property int modelData
                    wsId: modelData
                    hmon: m.hmon
                    height: wsRow.height
                    width: implicitWidth
                }
            }
        }
    }
    Component {
        id: titleC
        Item {
            implicitWidth: tText.implicitWidth + (lay.visible ? lay.implicitWidth + 6 : 0)     // natural size; the bar may give less
            Row {
                id: tRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                BarText {
                    id: tText
                    width: Math.min(implicitWidth, Math.max(20, m.width - (lay.visible ? lay.implicitWidth + 6 : 0)))
                    // the focused window; on another monitor's bar, the window last used there
                    text: {
                        if (m.hmon && Quickshell.screens.length > 1 && Hyprland.focusedMonitor && Hyprland.focusedMonitor.name !== m.hmon.name) {
                            const w = m.hmon.activeWorkspace && m.hmon.activeWorkspace.lastIpcObject ? m.hmon.activeWorkspace.lastIpcObject : null;
                            return w && w.windows > 0 && w.lastwindowtitle ? w.lastwindowtitle : "Desktop";
                        }
                        return Hyprland.activeToplevel && Hyprland.activeToplevel.title ? Hyprland.activeToplevel.title : "Desktop";
                    }
                    font.bold: true
                }
                BarText { id: lay; text: "· " + Theme.layoutName; color: Theme.textDim; visible: !m.compact }
            }
        }
    }
    Component {
        id: tasksC
        RowLayout {
            id: tasks
            spacing: 3
            // several monitors: each taskbar shows the windows on its own screen (Settings → Bar)
            readonly property bool perScreen: m.bar !== null && m.bar.screen && Quickshell.screens.length > 1 && Theme.sv("bar.tasksPerScreen", true)
            readonly property var list: ToplevelManager.toplevels.values.filter(t => {
                if (!tasks.perScreen) return true;
                const sc = t.screens || [];
                if (sc.length === 0) return true;
                for (let i = 0; i < sc.length; i++) if (sc[i] && sc[i].name === m.bar.screen.name) return true;
                return false;
            })
            implicitWidth: list.length * 173
            height: m.height - 2
            Repeater {
                model: tasks.list
                Bevel {
                    id: task
                    required property var modelData
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Layout.maximumWidth: 170
                    Layout.preferredWidth: 170
                    sunken: modelData.activated
                    fill: modelData.activated ? Theme.face2 : Theme.face
                    radius: Theme.radiusSm
                    Dither { anchors.fill: parent; visible: task.modelData.activated; opacity: 0.25 }
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 5 + (task.sunken ? 1 : 0)
                        anchors.topMargin: task.sunken ? 1 : 0
                        spacing: 5
                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: Theme.barFontSize + 2
                            source: {
                                const id = (task.modelData.appId || "").toLowerCase();
                                const e = DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(id) : null;
                                return Quickshell.iconPath(e && e.icon ? e.icon : id, "application-x-executable");
                            }
                        }
                        BarText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: task.width - Theme.barFontSize - 20
                            text: task.modelData.title || task.modelData.appId || "Window"
                            font.bold: task.modelData.activated
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: task.modelData.activate() }
                }
            }
            Item { Layout.fillWidth: true }
        }
    }
    Component {
        id: trayC
        Row {
            spacing: 8
            Repeater {
                model: SystemTray.items.values
                IconImage {
                    id: trayIcon
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: Theme.barFontSize + 2
                    source: modelData.icon
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton && trayIcon.modelData.hasMenu && m.bar)
                                trayIcon.modelData.display(m.bar, trayIcon.mapToItem(null, 0, 0).x, Theme.barTop ? m.bar.height : 0);
                            else
                                trayIcon.modelData.activate();
                        }
                    }
                }
            }
        }
    }
    Component {
        id: mediaC
        Row {
            spacing: 5
            PixelIcon { kind: "volume"; level: m.player && m.player.isPlaying ? 1 : 0; anchors.verticalCenter: parent.verticalCenter }
            BarText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 200)
                text: m.player ? (m.player.trackArtist ? m.player.trackArtist + " – " : "") + (m.player.trackTitle || "") : ""
            }
        }
    }
    Component { id: btwC; BtwBadge {} }
    Component {
        id: cpuC
        Row {
            spacing: 4
            PixelIcon { kind: "cpu"; anchors.verticalCenter: parent.verticalCenter }
            BarText { anchors.verticalCenter: parent.verticalCenter; text: Math.round(Sys.cpu) + "%" }
        }
    }
    Component {
        id: memC
        Row {
            spacing: 4
            Component.onCompleted: Info.users++
            Component.onDestruction: Info.users--
            CpIcon { kind: "ram"; width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter }
            BarText {
                anchors.verticalCenter: parent.verticalCenter
                text: Info.sys.memTotal ? "RAM " + Math.round(Info.sys.memUsed / Info.sys.memTotal * 100) + "%" : "RAM"
            }
        }
    }
    Component {
        id: netC
        Row {
            spacing: 4
            PixelIcon { anchors.verticalCenter: parent.verticalCenter; kind: !Sys.netUp ? "wifi-off" : (Sys.wifi ? "wifi" : "wired") }
            BarText { anchors.verticalCenter: parent.verticalCenter; visible: !m.compact && text !== ""; text: Sys.net; width: Math.min(implicitWidth, 120) }
        }
    }
    Component {
        id: volC
        Row {
            spacing: 4
            PixelIcon { anchors.verticalCenter: parent.verticalCenter; kind: Sys.muted ? "mute" : "volume"; level: Sys.volume }
            BarText { anchors.verticalCenter: parent.verticalCenter; text: Sys.muted ? "mute" : Math.round(Sys.volume * 100) + "%" }
        }
    }
    Component {
        id: batC
        Row {
            spacing: 4
            PixelIcon { anchors.verticalCenter: parent.verticalCenter; kind: "battery"; level: Sys.battery / 100 }
            BarText { anchors.verticalCenter: parent.verticalCenter; text: Math.round(Sys.battery) + "%" + (Sys.charging ? "+" : "") }
        }
    }
    Component {
        id: notifC
        Row {
            spacing: 4
            CpIcon { kind: Theme.sv("notifications.dnd", false) ? "bell-off" : "bell"; width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
                visible: NotifHistory.unseen > 0
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(16, nb.implicitWidth + 8); height: 16
                radius: 8
                color: "#c0392b"
                Text { id: nb; anchors.centerIn: parent; text: NotifHistory.unseen > 99 ? "99+" : NotifHistory.unseen; color: "white"; font.pixelSize: 10; font.bold: true }
            }
        }
    }
    Component {
        id: ctlC
        Bevel {
            implicitWidth: cpRow.implicitWidth + 12
            height: Math.max(18, Theme.barFontSize + 8)
            sunken: Ui.controlOpen || cpMa.pressed
            fill: Ui.controlOpen ? Theme.face2 : Theme.face
            depth: Math.min(2, Theme.bevel)
            radius: Theme.radiusSm
            Row {
                id: cpRow
                anchors.centerIn: parent
                spacing: 4
                CpIcon { kind: "gear"; width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter }
                BarText { visible: !m.compact; text: "Control"; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    visible: NotifHistory.unseen > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(16, badgeText.implicitWidth + 8); height: 16
                    radius: 8
                    color: "#c0392b"
                    Text { id: badgeText; anchors.centerIn: parent; text: NotifHistory.unseen > 99 ? "99+" : NotifHistory.unseen; color: "white"; font.pixelSize: 10; font.bold: true }
                }
            }
            MouseArea {
                id: cpMa
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { Ui.flyout = ""; Ui.controlOpen = !Ui.controlOpen; }
            }
        }
    }
    Component {
        id: clockC
        Clock {
            height: m.height - 4
            pressed: m.menuOpen
        }
    }
    Component {
        id: sepC
        Item {
            implicitWidth: 2
            height: m.height
            Rectangle { y: 5; width: 1; height: parent.height - 10; color: Theme.lo }
            Rectangle { x: 1; y: 5; width: 1; height: parent.height - 10; color: Theme.hi }
        }
    }
    Component { id: spaceC; Item { implicitWidth: 14 } }
}
