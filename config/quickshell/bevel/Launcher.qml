import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Super+R — the app launcher, in three looks (Settings → Desktop style → Launcher):
//   run   the classic Run box with a scrolling list
//   grid  a Program Manager window full of icons
//   start a Start menu with categories and a side banner
// Type to search · =2*21 calculates · Enter runs anything that isn't an app · Esc closes.
Scope {
    id: root

    IpcHandler {
        target: "launcher"
        function toggle(): void { Ui.launcherOpen = !Ui.launcherOpen; }
        function show(): void { Ui.launcherOpen = true; }
        function hide(): void { Ui.launcherOpen = false; }
    }

    // ---- a tiny calculator (no eval): + - * / % ^ and brackets
    function calc(src) {
        const s = src.replace(/,/g, ".").replace(/\s+/g, "");
        let i = 0;
        function num() {
            const m = s.slice(i).match(/^\d*\.?\d+(e[+-]?\d+)?/i);
            if (!m) throw "num";
            i += m[0].length;
            return parseFloat(m[0]);
        }
        function atom() {
            if (s[i] === "-") { i++; return -atom(); }
            if (s[i] === "+") { i++; return atom(); }
            if (s[i] === "(") { i++; const v = sum(); if (s[i] !== ")") throw "paren"; i++; return v; }
            return num();
        }
        function pow() { const b = atom(); if (s[i] === "^") { i++; return Math.pow(b, pow()); } return b; }
        function prod() {
            let v = pow();
            while (s[i] === "*" || s[i] === "/" || s[i] === "%") {
                const op = s[i++]; const r = pow();
                v = op === "*" ? v * r : op === "/" ? v / r : v % r;
            }
            return v;
        }
        function sum() {
            let v = prod();
            while (s[i] === "+" || s[i] === "-") { const op = s[i++]; const r = prod(); v = op === "+" ? v + r : v - r; }
            return v;
        }
        try {
            const v = sum();
            if (i !== s.length || !isFinite(v)) return null;
            return Math.round(v * 1e10) / 1e10;
        } catch (e) {
            return null;
        }
    }

    readonly property var groups: [
        { name: "Internet", cats: ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging"] },
        { name: "Development", cats: ["Development", "IDE", "TextEditor"] },
        { name: "Graphics", cats: ["Graphics", "Photography", "2DGraphics", "3DGraphics"] },
        { name: "Multimedia", cats: ["AudioVideo", "Audio", "Video", "Player", "Music"] },
        { name: "Office", cats: ["Office", "WordProcessor", "Spreadsheet", "Viewer"] },
        { name: "Games", cats: ["Game"] },
        { name: "System", cats: ["System", "Settings", "TerminalEmulator", "Monitor", "FileManager"] },
        { name: "Accessories", cats: ["Utility", "Accessories", "Archiving", "Calculator"] }
    ]
    function groupOf(e) {
        const c = e.categories || [];
        for (const g of root.groups)
            for (const k of g.cats)
                if (c.indexOf(k) >= 0) return g.name;
        return "Other";
    }

    // built once, in the background a few seconds after login (or on the first Super+R), then only
    // shown and hidden: opening it is instant
    property bool warm: false
    Timer { interval: 3000; running: true; onTriggered: root.warm = true }
    Connections { target: Ui; function onLauncherOpenChanged() { if (Ui.launcherOpen) root.warm = true; } }

    LazyLoader {
        active: root.warm

        PanelWindow {
            // on the monitor you're using (Settings → Windows & display has the main one)
            screen: Ui.focusedScreen
            PopupHold { active: Ui.launcherOpen }
            id: win
            visible: Ui.launcherOpen
            // a fresh start every time it opens
            Connections {
                target: Ui
                function onLauncherOpenChanged() {
                    if (!Ui.launcherOpen) return;
                    win.query = ""; win.sel = 0; win.cat = 0; win.konami = [];
                }
            }
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "bevel-launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            readonly property string style: Theme.launcherStyle
            readonly property int rowH: Theme.fontSize + 14
            property string query: ""
            property int sel: 0
            property int cat: 0           // start menu: selected category

            readonly property var apps: DesktopEntries.applications.values
                .filter(e => !e.noDisplay)
                .sort((a, b) => a.name.localeCompare(b.name))
            readonly property var cats: {
                const have = {};
                for (const e of win.apps) have[root.groupOf(e)] = true;
                return ["All"].concat(root.groups.map(g => g.name).concat(["Other"]).filter(n => have[n]));
            }

            readonly property var results: {
                const q = win.query.trim();
                const ql = q.toLowerCase();
                const out = [];
                if (q.startsWith("=")) {
                    const v = root.calc(q.slice(1));
                    out.push({ special: "calc", value: v, name: v === null ? "= …" : "= " + v,
                               genericName: v === null ? "type a sum, like =2*21" : "Enter copies it", icon: "accessories-calculator" });
                    return out;
                }
                if (ql === "btw" || ql === "i use arch btw")
                    out.push({ special: "btw", name: "I use " + Theme.distro + ", btw.", genericName: "we know", icon: "dialog-information" });
                // a few words that do something silly
                const eggs = {
                    fortune: { name: "Open a fortune cookie", genericName: "wisdom, probably", icon: "help-about" },
                    fetch: { name: "Show off (fastfetch)", genericName: "for the screenshot", icon: "utilities-terminal" },
                    sheep: { name: Theme.sv("fun.pet", "off") === "sheep" ? "Send the sheep home" : "Get a desktop sheep", genericName: "baa", icon: "face-smile" },
                    party: { name: "Sheep party!", genericName: "20 seconds of chaos", icon: "face-laugh" },
                    saver: { name: "Start the screensaver", genericName: Theme.saver, icon: "preferences-desktop-screensaver" }
                };
                for (const k in eggs)
                    if (ql.length >= 3 && k.startsWith(ql))
                        out.push(Object.assign({ special: "egg", egg: k }, eggs[k]));
                let list;
                if (ql === "") {
                    const c = win.cats[win.cat] || "All";
                    list = (win.style === "start" && c !== "All") ? win.apps.filter(e => root.groupOf(e) === c) : win.apps;
                } else {
                    list = [];
                    for (const e of win.apps) {
                        const name = (e.name || "").toLowerCase();
                        const extra = ((e.genericName || "") + " " + (e.comment || "") + " " + (e.keywords || []).join(" ")).toLowerCase();
                        let score = -1;
                        if (name.startsWith(ql)) score = 3;
                        else if (name.split(/[\s\-_]/).some(w => w.startsWith(ql))) score = 2;
                        else if (name.indexOf(ql) >= 0) score = 1;
                        else if (extra.indexOf(ql) >= 0) score = 0;
                        if (score >= 0) list.push({ e: e, score: score });
                    }
                    list.sort((a, b) => b.score - a.score || a.e.name.localeCompare(b.e.name));
                    list = list.map(x => x.e);
                }
                if (q !== "" && list.length === 0 && out.length === 0)
                    out.push({ special: "run", name: "Run: " + q, genericName: "shell command", icon: "system-run" });
                return out.concat(list);
            }
            onResultsChanged: sel = 0

            function launch(item) {
                if (!item) {
                    if (win.query.trim() !== "") Quickshell.execDetached(["sh", "-c", win.query.trim()]);
                } else if (item.special === "calc") {
                    if (item.value === null) return;
                    Quickshell.execDetached(["sh", "-c", "printf %s '" + item.value + "' | wl-copy"]);
                } else if (item.special === "btw") {
                    Quickshell.execDetached(["notify-send", "-a", "Bevel", "I use " + Theme.distro + ", btw.", "Yes. We know. Everyone knows."]);
                } else if (item.special === "egg") {
                    const fortunes = [
                        "There is no place like 127.0.0.1.", "You will update today. It will be fine. Probably.",
                        "A partition you forgot about is still mounted.", "Read the wiki. Then read it again.",
                        "Your next rice will be even better.", "It's not a bug, it's a missing feature flag.",
                        "Today is a good day to back up your dotfiles.", "rm -rf is not a personality.",
                        "The answer is in the man page. It always was.", "Somebody, somewhere, is still using Windows 95. Respect."
                    ];
                    if (item.egg === "fortune")
                        Quickshell.execDetached(["notify-send", "-a", "Bevel", "Fortune cookie", fortunes[Math.floor(Math.random() * fortunes.length)]]);
                    else if (item.egg === "fetch")
                        Quickshell.execDetached(["kitty", "--hold", "fastfetch"]);
                    else if (item.egg === "sheep")
                        Theme.set("fun.pet", Theme.sv("fun.pet", "off") === "sheep" ? "off" : "sheep");
                    else if (item.egg === "party")
                        Ui.sheepParty = true;
                    else if (item.egg === "saver")
                        Quickshell.execDetached(["sh", "-c", "sleep 0.5; qs -c bevel ipc call screensaver start"]);
                } else if (item.special === "run") {
                    Quickshell.execDetached(["sh", "-c", win.query.trim()]);
                } else {
                    item.execute();
                }
                Ui.launcherOpen = false;
            }
            function move(d) {
                if (win.results.length === 0) return;
                win.sel = Math.max(0, Math.min(win.results.length - 1, win.sel + d));
            }
            // ↑ ↑ ↓ ↓ ← → ← → B A
            property var konami: []
            function konamiKey(k) {
                const want = [Qt.Key_Up, Qt.Key_Up, Qt.Key_Down, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_Left, Qt.Key_Right, Qt.Key_B, Qt.Key_A];
                const seq = win.konami.concat([k]).slice(-10);
                win.konami = seq;
                if (seq.length === 10 && seq.every((x, i) => x === want[i])) {
                    Ui.sheepParty = true;
                    Quickshell.execDetached(["notify-send", "-a", "Bevel", "Cheat code accepted", "+30 lives. Also: sheep."]);
                    Ui.launcherOpen = false;
                    return true;
                }
                return false;
            }
            readonly property int gridCols: Math.max(1, Math.floor((Math.min(720, win.width - 80) - 24) / 104))
            readonly property int pageRows: win.style === "grid" ? win.gridCols * 3 : 8

            // click outside closes
            MouseArea { anchors.fill: parent; onClicked: Ui.launcherOpen = false }

            // ======================================================== shared pieces
            component SearchField: Bevel {
                id: sf
                property bool active: false       // only the visible style's field takes the keyboard
                implicitHeight: Theme.fontSize + 14
                sunken: true
                fill: Theme.base
                radius: Theme.radiusSm
                padding: 3
                TextInput {
                    id: ti
                    anchors.fill: parent
                    anchors.leftMargin: 3
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    font.family: Theme.font
                    font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
                    font.pixelSize: Theme.fontSize
                    focus: sf.active
                    Component.onCompleted: if (sf.active) forceActiveFocus()
                    Connections {
                        target: Ui
                        function onLauncherOpenChanged() { if (Ui.launcherOpen && sf.active) { ti.text = ""; ti.forceActiveFocus(); } }
                    }
                    clip: true
                    text: win.query
                    onTextChanged: win.query = text
                    Keys.onPressed: event => {
                        const k = event.key;
                        if (win.konamiKey(k)) { event.accepted = true; return; }
                        const grid = win.style === "grid";
                        if (k === Qt.Key_Escape) Ui.launcherOpen = false;
                        else if (k === Qt.Key_Down) win.move(grid ? win.gridCols : 1);
                        else if (k === Qt.Key_Up) win.move(grid ? -win.gridCols : -1);
                        else if (k === Qt.Key_Tab) win.move(1);
                        else if (k === Qt.Key_Backtab) win.move(-1);
                        else if (k === Qt.Key_PageDown) win.move(win.pageRows);
                        else if (k === Qt.Key_PageUp) win.move(-win.pageRows);
                        else if (grid && k === Qt.Key_Right) win.move(1);
                        else if (grid && k === Qt.Key_Left) win.move(-1);
                        else if (win.style === "start" && win.query === "" && k === Qt.Key_Right) win.cat = Math.min(win.cats.length - 1, win.cat + 1);
                        else if (win.style === "start" && win.query === "" && k === Qt.Key_Left) win.cat = Math.max(0, win.cat - 1);
                        else if (k === Qt.Key_Return || k === Qt.Key_Enter) win.launch(win.results[win.sel]);
                        else return;
                        event.accepted = true;
                    }
                }
            }

            // one row of the list
            component AppRow: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: index === win.sel
                width: ListView.view ? ListView.view.width : 200
                height: win.rowH
                color: current ? Theme.accent : (rowMa.containsMouse ? Theme.face2 : "transparent")
                IconImage {
                    id: icon
                    anchors.left: parent.left; anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: Theme.fontSize + 4
                    source: Quickshell.iconPath(row.modelData.icon || "", "application-x-executable")
                }
                BText {
                    anchors.left: icon.right; anchors.leftMargin: 8
                    anchors.right: kind.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    color: row.current ? Theme.accentText : Theme.text
                    font.bold: !!row.modelData.special
                }
                BText {
                    id: kind
                    anchors.right: parent.right; anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 150)
                    text: row.modelData.genericName || ""
                    color: row.current ? Theme.accentText : Theme.textDim
                    opacity: 0.85
                }
                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: win.sel = row.index
                    onClicked: win.launch(row.modelData)
                }
            }

            // a list that scrolls with the wheel/touchpad and follows the keyboard
            component AppList: MouseArea {
                id: wrap
                property alias view: lv
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    const dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 2;
                    lv.contentY = Math.max(0, Math.min(Math.max(0, lv.contentHeight - lv.height), lv.contentY - dy));
                    wheel.accepted = true;
                }
                ListView {
                    id: lv
                    anchors.fill: parent
                    clip: true
                    interactive: false
                    model: win.results
                    currentIndex: win.sel
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    delegate: AppRow {}
                }
                // scrollbar
                Rectangle {
                    visible: lv.contentHeight > lv.height
                    anchors.right: parent.right
                    y: lv.contentY / Math.max(1, lv.contentHeight) * lv.height
                    width: 5
                    height: Math.max(20, lv.height * lv.height / Math.max(1, lv.contentHeight))
                    color: Theme.lo
                }
            }

            component TitleStrip: Rectangle {
                property string label: ""
                implicitHeight: Theme.fontSize + 10
                color: Theme.accent
                radius: Theme.radiusSm
                BText {
                    anchors.left: parent.left; anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.label; font.bold: true; color: Theme.accentText
                }
                BText {
                    anchors.right: parent.right; anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Super+R"; color: Theme.accentText; opacity: 0.8
                }
            }

            // ======================================================== style: Run box
            Loader {
                anchors.fill: parent
                active: win.style === "run"
                sourceComponent: Item {
                    Bevel {
                        id: runBox
                        x: Theme.gapsOut
                        y: Theme.barTop ? Theme.barHeight + 2 * Theme.gapsOut : win.height - Theme.barHeight - 2 * Theme.gapsOut - height
                        width: 440
                        height: runCol.implicitHeight + 8
                        radius: Theme.radius
                        fillOpacity: Math.max(Theme.panelOpacity, 0.9)
                        padding: 2
                        MouseArea { anchors.fill: parent }      // clicks inside don't close it
                        ColumnLayout {
                            id: runCol
                            anchors.fill: parent
                            spacing: 6
                            TitleStrip { Layout.fillWidth: true; label: "Run" }
                            BText { Layout.leftMargin: 4; text: "Type the name of a program, or =2*21:" }
                            SearchField { Layout.fillWidth: true; Layout.leftMargin: 4; Layout.rightMargin: 4; visible: active; active: win.style === "run" }
                            Bevel {
                                Layout.fillWidth: true
                                Layout.leftMargin: 4
                                Layout.rightMargin: 4
                                implicitHeight: Math.max(1, Math.min(9, win.results.length)) * win.rowH + 6
                                sunken: true
                                fill: Theme.base
                                radius: Theme.radiusSm
                                padding: 1
                                AppList { anchors.fill: parent }
                                BText {
                                    visible: win.results.length === 0
                                    x: 6; height: win.rowH
                                    text: "No apps found"
                                    color: Theme.textDim
                                }
                            }
                            BText {
                                Layout.leftMargin: 4
                                Layout.bottomMargin: 2
                                text: win.results.length + " found · ↑↓ PgUp PgDn · wheel scrolls · Enter run · Esc close"
                                color: Theme.textDim
                                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                            }
                        }
                    }
                }
            }

            // ======================================================== style: Program Manager grid
            Loader {
                anchors.fill: parent
                active: win.style === "grid"
                sourceComponent: Item {
                    Bevel {
                        id: gridBox
                        anchors.centerIn: parent
                        width: Math.min(720, win.width - 80)
                        height: Math.min(520, win.height - 120)
                        radius: Theme.radius
                        fillOpacity: Math.max(Theme.panelOpacity, 0.92)
                        padding: 2
                        MouseArea { anchors.fill: parent }
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 6
                            TitleStrip { Layout.fillWidth: true; label: "Program Manager" }
                            SearchField { Layout.fillWidth: true; Layout.leftMargin: 6; Layout.rightMargin: 6; visible: active; active: win.style === "grid" }
                            Bevel {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.margins: 6
                                sunken: true
                                fill: Theme.base
                                radius: Theme.radiusSm
                                padding: 4
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.NoButton
                                    onWheel: wheel => {
                                        const dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 2;
                                        gv.contentY = Math.max(0, Math.min(Math.max(0, gv.contentHeight - gv.height), gv.contentY - dy));
                                        wheel.accepted = true;
                                    }
                                    GridView {
                                        id: gv
                                        anchors.fill: parent
                                        clip: true
                                        interactive: false
                                        cellWidth: 104
                                        cellHeight: 92
                                        model: win.results
                                        currentIndex: win.sel
                                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                                        delegate: Item {
                                            id: cell
                                            required property var modelData
                                            required property int index
                                            readonly property bool current: index === win.sel
                                            width: 104; height: 92
                                            IconImage {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                y: 8
                                                implicitSize: 40
                                                source: Quickshell.iconPath(cell.modelData.icon || "", "application-x-executable")
                                            }
                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                y: 52
                                                width: Math.min(98, lbl.implicitWidth + 6)
                                                height: lbl.height + 2
                                                color: cell.current ? Theme.accent : "transparent"
                                                border.width: cell.current ? 1 : 0
                                                border.color: Theme.dark
                                                BText {
                                                    id: lbl
                                                    anchors.centerIn: parent
                                                    width: 96
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: cell.modelData.name
                                                    wrapMode: Text.Wrap
                                                    maximumLineCount: 2
                                                    font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                                    color: cell.current ? Theme.accentText : Theme.text
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: win.sel = cell.index
                                                onClicked: win.launch(cell.modelData)
                                            }
                                        }
                                    }
                                }
                            }
                            BText {
                                Layout.leftMargin: 8
                                Layout.bottomMargin: 4
                                text: win.results.length + " programs · arrows move · Enter run · Esc close"
                                color: Theme.textDim
                                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                            }
                        }
                    }
                }
            }

            // ======================================================== style: Start menu
            Loader {
                anchors.fill: parent
                active: win.style === "start"
                sourceComponent: Item {
                    Bevel {
                        id: startBox
                        x: Theme.barLayout === "taskbar" ? 2 : Theme.gapsOut
                        y: Theme.barTop ? Theme.barHeight + 2 * Theme.gapsOut
                                        : win.height - (Theme.barLayout === "taskbar" ? Theme.barHeight + 4 : Theme.barHeight + 2 * Theme.gapsOut) - height - 2
                        width: 500
                        height: Math.min(560, win.height - 120)
                        radius: Theme.radius
                        fillOpacity: Math.max(Theme.panelOpacity, 0.95)
                        padding: 1
                        MouseArea { anchors.fill: parent }
                        RowLayout {
                            anchors.fill: parent
                            spacing: 0
                            // the side banner
                            Rectangle {
                                Layout.fillHeight: true
                                implicitWidth: 30
                                gradient: Gradient {
                                    GradientStop { position: 0; color: Theme.accent2 }
                                    GradientStop { position: 1; color: Theme.accent }
                                }
                                BText {
                                    id: banner
                                    rotation: -90
                                    x: (parent.width - width) / 2
                                    y: parent.height - 10 - width / 2 - height / 2
                                    text: "<b>Bevel</b> " + Theme.distro
                                    textFormat: Text.StyledText
                                    color: Theme.accentText
                                    font.pixelSize: Theme.fontSize + 6
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.margins: 4
                                spacing: 4
                                SearchField { Layout.fillWidth: true; visible: active; active: win.style === "start" }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 4
                                    // categories
                                    Column {
                                        visible: win.query === ""
                                        Layout.preferredWidth: 140
                                        Layout.fillHeight: true
                                        Repeater {
                                            model: win.cats
                                            Rectangle {
                                                id: catRow
                                                required property string modelData
                                                required property int index
                                                width: 140
                                                height: win.rowH
                                                color: win.cat === index ? Theme.accent : (catMa.containsMouse ? Theme.face2 : "transparent")
                                                BText {
                                                    anchors.left: parent.left; anchors.leftMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: catRow.modelData
                                                    color: win.cat === catRow.index ? Theme.accentText : Theme.text
                                                }
                                                BText {
                                                    anchors.right: parent.right; anchors.rightMargin: 6
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "▸"
                                                    color: win.cat === catRow.index ? Theme.accentText : Theme.textDim
                                                }
                                                MouseArea {
                                                    id: catMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onEntered: win.cat = catRow.index
                                                }
                                            }
                                        }
                                    }
                                    Rectangle { visible: win.query === ""; Layout.fillHeight: true; implicitWidth: 1; color: Theme.lo }
                                    Bevel {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        sunken: true
                                        depth: 1
                                        fill: Theme.base
                                        AppList { anchors.fill: parent }
                                    }
                                }
                                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.lo }
                                Repeater {
                                    model: [
                                        { label: "Settings…", icon: "preferences-system", cmd: ["qs", "-c", "bevel", "ipc", "call", "settings", "show"] },
                                        { label: "Shut Down…", icon: "system-shutdown", cmd: ["qs", "-c", "bevel", "ipc", "call", "power", "show"] }
                                    ]
                                    Rectangle {
                                        id: foot
                                        required property var modelData
                                        Layout.fillWidth: true
                                        implicitHeight: win.rowH
                                        color: footMa.containsMouse ? Theme.accent : "transparent"
                                        IconImage {
                                            id: ficon
                                            anchors.left: parent.left; anchors.leftMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            implicitSize: Theme.fontSize + 4
                                            source: Quickshell.iconPath(foot.modelData.icon, "application-x-executable")
                                        }
                                        BText {
                                            anchors.left: ficon.right; anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: foot.modelData.label
                                            color: footMa.containsMouse ? Theme.accentText : Theme.text
                                        }
                                        MouseArea {
                                            id: footMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: { Ui.launcherOpen = false; Quickshell.execDetached(foot.modelData.cmd); }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
