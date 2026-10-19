import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

// Everything inside the control panel: date and calendar, quick toggles, sound, display,
// battery, Wi-Fi, Bluetooth, media and system info. Used by the Hyprland panel (ControlPanel.qml)
// and the bar menus (Flyouts.qml). System changes go through `bevelctl cp …`.
Item {
    id: root
    signal closeRequested()
    // flyout mode (the bar's clock / battery / sound / network menus): only these parts, all open
    property var only: []
    readonly property bool flyout: only.length > 0
    function has(id) { return !root.flyout || root.only.indexOf(id) >= 0; }
    readonly property real contentHeight: body.implicitHeight + 20
    property bool shown: true
    readonly property bool wayland: (Quickshell.env("WAYLAND_DISPLAY") || "") !== ""

    property var now: new Date()
    Timer { interval: 1000; running: root.shown; repeat: true; onTriggered: root.now = new Date() }
    property real nowFast: Date.now()
    Timer { interval: 100; running: root.shown && root.flyout && (Ui.swStart > 0 || Ui.timerEnd > 0); repeat: true; triggeredOnStart: true; onTriggered: root.nowFast = Date.now() }
    property int calOffset: 0      // months away from today in the calendar

    // ---------------------------------------------------------------- state
    property var st: ({})                 // bevelctl cp status
    property var nets: []                 // Wi-Fi networks
    property var info: ({})               // bevelctl cp sysinfo
    property real bright: -1
    property string askPass: ""           // network waiting for a password
    property string connecting: ""
    property string message: ""
    property var expanded: Ui.cpExpanded
    onExpandedChanged: Ui.cpExpanded = expanded
    readonly property bool dnd: Theme.sv("notifications.dnd", false)

    function toggleSec(k) {
        const e = Object.assign({}, root.expanded);
        e[k] = !e[k];
        root.expanded = e;
        if (k === "wifi" && e[k]) root.scan();
        if (k === "system" && e[k]) sysProc.running = true;
    }
    function setSt(k, v) { const c = Object.assign({}, root.st); c[k] = v; root.st = c; }

    function refresh() { if (!statusProc.running) statusProc.running = true; }
    function scan() { if (!scanProc.running) scanProc.running = true; }

    // one system change at a time, then re-read the status
    property var queue: []
    function act(args) {
        root.queue = root.queue.concat([["bevelctl", "cp"].concat(args)]);
        if (!actProc.running) root.next();
    }
    function next() {
        if (root.queue.length === 0) { refreshSoon.restart(); return; }
        actProc.command = root.queue[0];
        root.queue = root.queue.slice(1);
        actProc.running = true;
    }
    Timer { id: refreshSoon; interval: 400; onTriggered: { root.refresh(); if (root.expanded.wifi) netsQuick.running = true; } }

    Process {
        id: actProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (actProc.command.indexOf("wifi-connect") < 0) return;
                try {
                    const r = JSON.parse(text);
                    root.message = r.ok ? "" : (r.message.indexOf("Secrets were required") >= 0 || r.message.indexOf("password") >= 0
                                                ? "Wrong password?" : "Couldn't connect: " + r.message);
                    if (!r.ok && root.connecting !== "") root.askPass = root.connecting;
                } catch (e) {}
                root.connecting = "";
            }
        }
        onExited: root.next()
    }
    Process {
        id: statusProc
        command: ["bevelctl", "cp", "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.st = JSON.parse(text); Ui.caffeine = !!root.st.caffeine; } catch (e) {} } }
    }
    Process {
        id: scanProc
        command: ["bevelctl", "cp", "wifi-list", "--rescan"]
        stdout: StdioCollector { onStreamFinished: { try { root.nets = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: netsQuick
        command: ["bevelctl", "cp", "wifi-list"]
        stdout: StdioCollector { onStreamFinished: { try { root.nets = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: sysProc
        command: ["bevelctl", "cp", "sysinfo"]
        stdout: StdioCollector { onStreamFinished: { try { root.info = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: briGet
        command: ["bevelctl", "brightness", "get"]
        stdout: StdioCollector { onStreamFinished: { const v = parseInt(text.trim()); if (!isNaN(v)) root.bright = v; } }
    }
    // brightness while dragging: send the newest value whenever the last one is done
    property int briWant: -1
    property int briSent: -1
    function setBright(v) {
        root.bright = v;
        root.briWant = Math.round(v);
        if (!briSet.running) root.sendBright();
    }
    function sendBright() {
        if (root.briWant < 0 || root.briWant === root.briSent) return;
        root.briSent = root.briWant;
        briSet.command = ["bevelctl", "cp", "brightness", String(Math.max(1, root.briSent))];
        briSet.running = true;
    }
    Process { id: briSet; onExited: root.sendBright() }

    Timer {
        interval: 4000
        repeat: true
        running: root.shown
        triggeredOnStart: true
        onTriggered: {
            root.refresh();
            if (root.expanded.system || (root.flyout && root.has("system"))) sysProc.running = true;
        }
    }
    onShownChanged: opened()
    Component.onCompleted: opened()
    function opened() {
        {
            if (root.shown) {
                NotifHistory.seen();
                briGet.running = true;
                root.message = "";
                root.askPass = "";
                if (root.expanded.wifi || (root.flyout && root.has("wifi"))) root.scan();
                if (root.expanded.system || (root.flyout && root.has("system"))) sysProc.running = true;
            }
        }
    }

    // ---------------------------------------------------------------- audio
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var inputs: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    function nodeName(n) { return n ? (n.description || n.nickname || n.name || "?") : "none"; }

    // ---------------------------------------------------------------- battery
    readonly property var bat: UPower.displayDevice
    readonly property bool hasBattery: !!bat && bat.isLaptopBattery
    readonly property var battDev: {
        const l = UPower.devices.values;
        for (let i = 0; i < l.length; i++) if (l[i].isLaptopBattery) return l[i];
        return null;
    }
    function dur(sec) {
        if (!sec || sec <= 0) return "";
        const h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60);
        return h > 0 ? h + " h " + m + " min" : m + " min";
    }
    function bytes(b) {
        if (!b) return "0";
        const g = b / 1073741824;
        return g >= 100 ? Math.round(g) + " GB" : g.toFixed(1) + " GB";
    }

    // ---------------------------------------------------------------- media
    readonly property var player: {
        const l = Mpris.players.values;
        for (let i = 0; i < l.length; i++) if (l[i].isPlaying) return l[i];
        return l.length > 0 ? l[0] : null;
    }

    // ---------------------------------------------------------------- pieces
    // collapsible section with an etched header line
    component Section: ColumnLayout {
        id: sec
        property string title: ""
        property string icon: "gear"
        property string summary: ""
        property string key: ""            // "" = always open
        property string sid: key           // which part this is, for flyouts
        property bool shownIf: true
        property bool flyoutOnly: false    // only in the bar menus, not in the control panel
        visible: shownIf && (flyoutOnly ? root.flyout && root.only.indexOf(sid) >= 0 : root.has(sid))
        default property alias body: secBody.data
        readonly property bool foldable: key !== "" && !root.flyout
        readonly property bool isOpen: !foldable || root.expanded[key] === true
        Layout.fillWidth: true
        spacing: 6
        Item {
            Layout.fillWidth: true
            implicitHeight: hdr.implicitHeight
            RowLayout {
                id: hdr
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 6
                CpIcon { kind: sec.icon; color: Theme.accent }
                BText { text: sec.title; font.bold: true }
                Rectangle {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                    height: 1; color: Theme.lo
                    Rectangle { y: 1; width: parent.width; height: 1; color: Theme.hi }
                }
                BText { text: sec.summary; color: Theme.textDim; font.pixelSize: Math.max(10, Theme.fontSize - 2); Layout.maximumWidth: 190 }
                // the arrow turns as the section slides open
                BText {
                    visible: sec.foldable
                    text: "▸"
                    color: sec.isOpen ? Theme.accent : Theme.textDim
                    rotation: sec.reveal * 90
                    transformOrigin: Item.Center
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: sec.foldable
                cursorShape: sec.foldable ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.toggleSec(sec.key)
            }
        }
        // 0 = folded, 1 = open; the body slides down out from under the header
        property real reveal: isOpen ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Item {
            id: secWrap
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(secBody.implicitHeight * sec.reveal)
            Layout.topMargin: sec.reveal > 0 ? 0 : -sec.spacing     // no gap under a folded header
            visible: sec.reveal > 0.001
            clip: sec.reveal < 0.999
            ColumnLayout {
                id: secBody
                x: 4
                width: secWrap.width - 4
                y: Math.round((sec.reveal - 1) * implicitHeight * 0.6)
                opacity: Math.min(1, sec.reveal * 1.6)
                spacing: 6
            }
        }
    }

    // a Windows 9x spin box: the number (type it), and little up/down arrows on the right
    component Spin: Bevel {
        id: sp
        property int value: 0
        property int step: 1
        property string unit: ""
        signal change(int v)
        implicitHeight: Theme.fontSize + 14
        implicitWidth: 90
        sunken: true
        fill: Theme.base
        radius: Theme.radiusSm
        padding: 2
        TextInput {
            id: spIn
            anchors.left: parent.left
            anchors.right: spArrows.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: sp.value < 10 ? "0" + sp.value : String(sp.value)
            validator: IntValidator { bottom: 0; top: 999 }
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentText
            font.family: Theme.mono
            font.pixelSize: Theme.fontSize + 2
            selectByMouse: true
            onEditingFinished: {
                const n = parseInt(text);
                text = Qt.binding(() => sp.value < 10 ? "0" + sp.value : String(sp.value));     // back to showing the value
                if (!isNaN(n)) sp.change(n);
            }
            BText {
                x: spIn.contentWidth + 4
                anchors.verticalCenter: parent.verticalCenter
                text: sp.unit
                color: Theme.textDim
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => sp.change(sp.value + (wheel.angleDelta.y > 0 ? sp.step : -sp.step))
        }
        Column {
            id: spArrows
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: [1, -1]
                Bevel {
                    id: arBtn
                    required property int modelData
                    width: 16
                    height: Math.floor((sp.height - 4) / 2)
                    depth: 1
                    radius: 0
                    sunken: arMa.pressed
                    Canvas {      // a tiny solid triangle, like the real thing
                        anchors.centerIn: parent
                        width: 7; height: 4
                        rotation: arBtn.modelData > 0 ? 0 : 180
                        onPaint: { const c = getContext("2d"); c.fillStyle = Theme.text; c.beginPath(); c.moveTo(0, 4); c.lineTo(3.5, 0); c.lineTo(7, 4); c.fill(); }
                    }
                    MouseArea {
                        id: arMa
                        anchors.fill: parent
                        onClicked: sp.change(sp.value + arBtn.modelData * sp.step)
                        // hold to keep going
                        onPressAndHold: arRepeat.start()
                        onReleased: arRepeat.stop()
                        Timer { id: arRepeat; interval: 90; repeat: true; onTriggered: sp.change(sp.value + arBtn.modelData * sp.step) }
                    }
                }
            }
        }
    }

    // a quick-toggle tile
    component Tile: Bevel {
        id: tile
        property string label: ""
        property string sub: ""
        property string icon: "gear"
        property bool on: false
        property bool available: true
        property bool slash: false
        signal hit()
        Layout.fillWidth: true
        implicitHeight: 70
        sunken: on || tileMa.pressed
        fill: on ? Theme.accent : Theme.face
        opacity: available ? 1 : 0.45
        depth: Math.min(2, Theme.bevel)
        radius: Theme.radiusSm
        Column {
            anchors.centerIn: parent
            spacing: 2
            CpIcon { anchors.horizontalCenter: parent.horizontalCenter; width: 32; height: 32; kind: tile.icon; off: tile.slash }
            BText { anchors.horizontalCenter: parent.horizontalCenter; text: tile.label; color: tile.on ? Theme.accentText : Theme.text; font.pixelSize: Math.max(10, Theme.fontSize - 2); font.bold: tile.on }
            BText {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, tile.width - 6)
                visible: tile.sub !== ""
                text: tile.sub
                color: tile.on ? Theme.accentText : Theme.textDim
                font.pixelSize: Math.max(9, Theme.fontSize - 4)
            }
        }
        MouseArea { id: tileMa; anchors.fill: parent; enabled: tile.available; cursorShape: Qt.PointingHandCursor; onClicked: tile.hit() }
    }

    // slider without touching the settings file (Theme.holding is for settings sliders)
    component CSlider: Item {
        id: sl
        property real value: 0          // 0..1
        property real live: value
        property bool active: true
        signal moved(real v)
        Layout.fillWidth: true
        implicitHeight: 22
        opacity: active ? 1 : 0.5
        onValueChanged: if (!slMa.pressed) live = value
        Bevel {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 8
            sunken: true; fill: Theme.base; depth: Math.min(2, Theme.bevel)
            Rectangle { height: parent.height - 2; y: 1; x: 1; width: Math.max(0, Math.min(1, sl.live)) * (parent.width - 2); color: Theme.accent }
        }
        Bevel { width: 12; height: 22; x: Math.max(0, Math.min(1, sl.live)) * (sl.width - width); radius: Theme.radiusSm }
        MouseArea {
            id: slMa
            anchors.fill: parent
            enabled: sl.active
            preventStealing: true
            function upd(mx) { sl.live = Math.max(0, Math.min(1, (mx - 6) / (sl.width - 12))); sl.moved(sl.live); }
            onPressed: mouse => upd(mouse.x)
            onPositionChanged: mouse => { if (pressed) upd(mouse.x); }
        }
    }

    // small square icon button
    component IconBtn: Bevel {
        id: ib
        property string icon: "gear"
        property bool on: false
        property bool off: false
        signal hit()
        implicitWidth: 28; implicitHeight: 26
        sunken: on || ibMa.pressed
        fill: on ? Theme.face2 : Theme.face
        depth: Math.min(2, Theme.bevel)
        radius: Theme.radiusSm
        CpIcon { anchors.centerIn: parent; kind: ib.icon; off: ib.off; width: 16; height: 16 }
        MouseArea { id: ibMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ib.hit() }
    }

    // a list row with a button on the right
    component ListRow: Rectangle {
        id: lr
        property string label: ""
        property string sub: ""
        property bool active: false
        property string button: ""
        property string icon: ""
        signal hit()
        signal pressed()
        Layout.fillWidth: true
        implicitHeight: Math.max(30, lrCol.implicitHeight + 8)
        color: active ? Theme.accent : (lrMa.containsMouse ? Theme.face2 : "transparent")
        CpIcon { id: lrIcon; visible: lr.icon !== ""; x: 6; anchors.verticalCenter: parent.verticalCenter; kind: lr.icon; color: lr.active ? Theme.accentText : Theme.text }
        Column {
            id: lrCol
            anchors.left: lr.icon !== "" ? lrIcon.right : parent.left
            anchors.leftMargin: 8
            anchors.right: lrBtn.visible ? lrBtn.left : parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            BText { width: parent.width; text: lr.label; color: lr.active ? Theme.accentText : Theme.text; font.bold: lr.active }
            BText { width: parent.width; visible: lr.sub !== ""; text: lr.sub; color: lr.active ? Theme.accentText : Theme.textDim; font.pixelSize: Math.max(9, Theme.fontSize - 3) }
        }
        MouseArea { id: lrMa; anchors.fill: parent; hoverEnabled: true; onClicked: lr.pressed() }
        SButton {
            id: lrBtn
            visible: lr.button !== ""
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: lr.button
            onClicked: lr.hit()
        }
    }

    // ---------------------------------------------------------------- window
    MouseArea {
        // wheel scrolling (clicks pass through to the controls)
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 2;
            flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY - dy));
        }
        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 10
            contentHeight: body.implicitHeight
            clip: true
            interactive: false

            ColumnLayout {
                id: body
                width: flick.width - (flick.contentHeight > flick.height ? 8 : 0)
                spacing: 12

                // ======================================== date & time
                Bevel {
                    visible: root.has("clock")
                    Layout.fillWidth: true
                    implicitHeight: clockCol.implicitHeight + 16
                    sunken: true
                    fill: Theme.lcdClock ? Theme.lcdBg : Theme.base
                    ColumnLayout {
                        id: clockCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 0
                        Text {
                            text: Qt.formatTime(root.now, Theme.clockFormat === "HH:mm" ? "HH:mm:ss" : "h:mm:ss AP")
                            color: Theme.lcdClock ? Theme.lcd : Theme.text
                            font.family: Theme.lcdClock ? Theme.mono : Theme.font
                            font.pixelSize: 36
                            font.bold: !Theme.lcdClock
                        }
                        BText {
                            text: root.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM yyyy")
                            color: Theme.lcdClock ? Theme.lcd : Theme.text
                            font.pixelSize: Theme.fontSize + 1
                        }
                        BText {
                            readonly property int doy: Math.floor((root.now - new Date(root.now.getFullYear(), 0, 0)) / 86400000)
                            readonly property int week: {
                                const d = new Date(Date.UTC(root.now.getFullYear(), root.now.getMonth(), root.now.getDate()));
                                const day = d.getUTCDay() || 7;
                                d.setUTCDate(d.getUTCDate() + 4 - day);
                                return Math.ceil(((d - new Date(Date.UTC(d.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
                            }
                            text: "Week " + week + "  ·  day " + doy + " of the year"
                            color: Theme.lcdClock ? Theme.lcd : Theme.textDim
                            font.pixelSize: Math.max(10, Theme.fontSize - 2)
                        }
                    }
                }

                Section {
                    title: "Calendar"
                    icon: "calendar"
                    key: "calendar"
                    summary: root.expanded.calendar || root.flyout ? "" : root.now.toLocaleDateString(Qt.locale(), "MMMM")
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        readonly property date shown: new Date(root.now.getFullYear(), root.now.getMonth() + root.calOffset, 1)
                        RowLayout {
                            Layout.fillWidth: true
                            SButton { text: "‹"; implicitWidth: 30; onClicked: root.calOffset-- }
                            BText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.bold: true; text: parent.parent.shown.toLocaleDateString(Qt.locale(), "MMMM yyyy") }
                            SButton { text: "Today"; visible: root.calOffset !== 0; onClicked: root.calOffset = 0 }
                            SButton { text: "›"; implicitWidth: 30; onClicked: root.calOffset++ }
                        }
                        Grid {
                            id: cal
                            columns: 7
                            Layout.fillWidth: true
                            readonly property real cw: width / 7
                            readonly property date first: parent.shown
                            readonly property int lead: (first.getDay() + 6) % 7          // weeks start on Monday
                            readonly property int days: new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate()
                            Repeater {
                                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                                BText { required property string modelData; width: cal.cw; horizontalAlignment: Text.AlignHCenter; text: modelData; color: Theme.textDim; font.bold: true }
                            }
                            Repeater {
                                model: 42
                                Rectangle {
                                    required property int index
                                    readonly property int day: index - cal.lead + 1
                                    readonly property bool inMonth: day >= 1 && day <= cal.days
                                    readonly property bool today: inMonth && root.calOffset === 0 && day === root.now.getDate()
                                    visible: index < Math.ceil((cal.lead + cal.days) / 7) * 7
                                    width: cal.cw
                                    height: Theme.fontSize + 8
                                    color: today ? Theme.accent : "transparent"
                                    BText {
                                        anchors.centerIn: parent
                                        text: parent.inMonth ? parent.day : new Date(cal.first.getFullYear(), cal.first.getMonth(), parent.day).getDate()
                                        color: parent.today ? Theme.accentText : (parent.inMonth ? ((index % 7) >= 5 ? Theme.accent : Theme.text) : Theme.lo)
                                        font.bold: parent.today
                                    }
                                }
                            }
                        }
                    }
                }

                // ======================================== world clocks (clock menu)
                Section {
                    id: worldSec
                    sid: "worldclock"
                    flyoutOnly: true
                    title: "World clock"
                    icon: "globe"
                    readonly property var cities: {
                        const l = Theme.sv("widgets.worldClocks", null) || ["London|Europe/London", "New York|America/New_York", "Tokyo|Asia/Tokyo"];
                        return l.map(s => { const p = String(s).split("|"); return { name: p[0], zone: (p[1] || p[0]).trim() }; });
                    }
                    property var offsets: ({})
                    Process {
                        id: tzProc
                        running: worldSec.visible
                        command: ["bevelctl", "cp", "tz"].concat(worldSec.cities.map(c => c.zone))
                        stdout: StdioCollector { onStreamFinished: { try { worldSec.offsets = JSON.parse(text); } catch (e) {} } }
                    }
                    Repeater {
                        model: worldSec.cities
                        RowLayout {
                            required property var modelData
                            readonly property var off: worldSec.offsets[modelData.zone]
                            readonly property date t: off === undefined || off === null ? root.now
                                : new Date(root.now.getTime() + (off + root.now.getTimezoneOffset()) * 60000)
                            readonly property int dayDiff: (t.getFullYear() * 400 + t.getMonth() * 32 + t.getDate()) - (root.now.getFullYear() * 400 + root.now.getMonth() * 32 + root.now.getDate())
                            Layout.fillWidth: true
                            BText { Layout.fillWidth: true; text: modelData.name }
                            BText { text: dayDiff > 0 ? "tomorrow" : (dayDiff < 0 ? "yesterday" : ""); color: Theme.textDim; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
                            BText { text: Qt.formatTime(t, Theme.clockFormat); font.bold: true }
                        }
                    }
                    BText { Layout.fillWidth: true; text: "Change the cities in Settings → Widgets → World clock."; color: Theme.textDim; font.pixelSize: Math.max(9, Theme.fontSize - 3); wrapMode: Text.Wrap }
                }

                // ======================================== stopwatch & timer (clock menu)
                Section {
                    id: swSec
                    sid: "timer"
                    flyoutOnly: true
                    title: "Stopwatch"
                    icon: "clock"
                    summary: Ui.swStart > 0 ? "running" : (Ui.swActive ? "paused" : "")
                    readonly property real ms: Ui.swElapsed(root.nowFast)
                    Bevel {
                        Layout.fillWidth: true
                        implicitHeight: Theme.fontSize + 22
                        sunken: true
                        fill: Theme.lcdClock ? Theme.lcdBg : Theme.base
                        Text {
                            anchors.centerIn: parent
                            text: Ui.clockText(swSec.ms) + "." + Math.floor(swSec.ms / 100) % 10
                            color: Theme.lcdClock ? Theme.lcd : (Ui.swActive && Ui.swStart === 0 ? Theme.textDim : Theme.text)
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontSize + 10
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        SButton { Layout.fillWidth: true; text: Ui.swStart > 0 ? "Pause" : (Ui.swActive ? "Resume" : "Start"); highlighted: Ui.swStart === 0; onClicked: Ui.swToggle() }
                        SButton { Layout.fillWidth: true; text: "Lap"; opacity: Ui.swStart > 0 ? 1 : 0.5; onClicked: if (Ui.swStart > 0) Ui.swLap() }
                        SButton { Layout.fillWidth: true; text: "Reset"; onClicked: Ui.swReset() }
                    }
                    // the last few laps: number, that lap's time, total
                    Repeater {
                        model: Ui.swLaps.length > 0 ? Ui.swLaps.map((t, i) => ({ n: i + 1, total: t, lap: t - (i > 0 ? Ui.swLaps[i - 1] : 0) })).slice(-4).reverse() : []
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            BText { text: "Lap " + modelData.n; color: Theme.textDim; Layout.preferredWidth: 60 }
                            BText { Layout.fillWidth: true; text: Ui.clockText(modelData.lap) + "." + Math.floor(modelData.lap / 100) % 10; font.family: Theme.mono }
                            BText { text: Ui.clockText(modelData.total) + "." + Math.floor(modelData.total / 100) % 10; color: Theme.textDim; font.family: Theme.mono }
                        }
                    }
                }
                Section {
                    id: tmSec
                    sid: "timer"
                    flyoutOnly: true
                    title: "Timer"
                    icon: "bell"
                    summary: Ui.timerEnd > 0 ? "running" : (Ui.timerPaused > 0 ? "paused" : "")
                    // the "any length" timer, in seconds (remembered)
                    property int customSec: Theme.sv("clock.timerSeconds", Theme.sv("clock.timerMinutes", 5) * 60)
                    readonly property real remain: Ui.timerLeft(root.nowFast)
                    // counting down: time left and a 9x progress bar
                    Bevel {
                        visible: Ui.timerActive
                        Layout.fillWidth: true
                        implicitHeight: Theme.fontSize + 22
                        sunken: true
                        fill: Theme.lcdClock ? Theme.lcdBg : Theme.base
                        Row {
                            anchors.left: parent.left
                            anchors.right: tmText.left
                            anchors.leftMargin: 6
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            height: Math.round(Theme.fontSize * 0.9)
                            spacing: 2
                            readonly property int blocks: Math.max(1, Math.floor((width + 2) / 10))
                            readonly property real frac: Ui.timerTotal > 0 ? tmSec.remain / Ui.timerTotal : 0
                            Repeater {
                                model: parent.blocks
                                Rectangle {
                                    required property int index
                                    width: 8
                                    height: parent.height
                                    color: index < Math.ceil(parent.frac * parent.blocks) ? Theme.accent : "transparent"
                                }
                            }
                        }
                        Text {
                            id: tmText
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: Ui.clockText(Math.ceil(tmSec.remain / 1000) * 1000)
                            color: Theme.lcdClock ? Theme.lcd : (Ui.timerPaused > 0 ? Theme.textDim : Theme.text)
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontSize + 10
                        }
                    }
                    RowLayout {
                        visible: Ui.timerActive
                        Layout.fillWidth: true
                        spacing: 4
                        SButton { Layout.fillWidth: true; implicitWidth: 40; text: Ui.timerEnd > 0 ? "Pause" : "Resume"; highlighted: true; onClicked: Ui.timerToggle() }
                        SButton { Layout.fillWidth: true; implicitWidth: 40; text: "+30 s"; onClicked: Ui.timerAdd(30) }
                        SButton { Layout.fillWidth: true; implicitWidth: 40; text: "+1 min"; onClicked: Ui.timerAdd(60) }
                        SButton { Layout.fillWidth: true; implicitWidth: 40; text: "Cancel"; onClicked: Ui.timerCancel() }
                    }
                    // quick ones
                    RowLayout {
                        visible: !Ui.timerActive
                        Layout.fillWidth: true
                        spacing: 4
                        Repeater {
                            model: [30, 60, 300, 600, 1500]
                            SButton {
                                required property int modelData
                                Layout.fillWidth: true
                                implicitWidth: 40
                                text: modelData < 60 ? modelData + " s" : modelData / 60 + " min"
                                onClicked: Ui.timerStart(modelData)
                            }
                        }
                    }
                    // any length: minutes and seconds, each with a 9x spin box (type, scroll or click the arrows)
                    RowLayout {
                        visible: !Ui.timerActive
                        Layout.fillWidth: true
                        spacing: 4
                        Spin {
                            Layout.fillWidth: true
                            value: Math.floor(tmSec.customSec / 60)
                            unit: "min"
                            onChange: v => tmSec.setSec(Math.max(0, v) * 60 + tmSec.customSec % 60)
                            step: 1
                        }
                        Spin {
                            Layout.fillWidth: true
                            value: tmSec.customSec % 60
                            unit: "s"
                            step: 5
                            // past 59 or below 0 carries into the minutes
                            onChange: v => tmSec.setSec(Math.floor(tmSec.customSec / 60) * 60 + v)
                        }
                        SButton { text: "Start"; highlighted: true; onClicked: if (tmSec.customSec > 0) Ui.timerStart(tmSec.customSec) }
                    }
                    function setSec(t) { if (isNaN(t)) return; customSec = Math.max(1, Math.min(99 * 3600, t)); Theme.setUi("clock.timerSeconds", customSec); }
                    // options
                    SCheck {
                        text: "Show on the bar while running"
                        checked: Theme.sv("clock.onBar", true)
                        onToggled: v => Theme.setUi("clock.onBar", v)
                    }
                    SCheck {
                        text: "Ring when the timer ends"
                        checked: Theme.sv("clock.timerSound", true)
                        onToggled: v => Theme.setUi("clock.timerSound", v)
                    }
                }

                // ======================================== quick toggles
                GridLayout {
                    visible: root.has("tiles")
                    Layout.fillWidth: true
                    columns: 4
                    columnSpacing: 4
                    rowSpacing: 4
                    Tile {
                        label: "Wi-Fi"; icon: "wifi"; slash: !on
                        available: root.st.wifi !== null && root.st.wifi !== undefined
                        on: !!root.st.wifi
                        sub: root.st.netType === "wifi" ? root.st.net : (root.st.wifi ? "on" : "off")
                        onHit: { const v = !root.st.wifi; root.setSt("wifi", v); root.act(["wifi", v ? "on" : "off"]); }
                    }
                    Tile {
                        label: "Bluetooth"; icon: "bt"; slash: !on
                        available: root.st.bt !== null && root.st.bt !== undefined
                        on: !!root.st.bt
                        sub: {
                            const c = (root.st.btDevices || []).filter(d => d.connected);
                            return c.length ? c[0].name : (root.st.bt ? "on" : "off");
                        }
                        onHit: { const v = !root.st.bt; root.setSt("bt", v); root.act(["bt", v ? "on" : "off"]); }
                    }
                    Tile {
                        label: "Airplane"; icon: "plane"
                        on: !!root.st.airplane
                        onHit: { const v = !root.st.airplane; root.setSt("airplane", v); root.act(["airplane", v ? "on" : "off"]); }
                    }
                    Tile {
                        label: "Quiet"; icon: "bell"; slash: on
                        sub: root.dnd ? "no pop-ups" : ""
                        on: root.dnd
                        onHit: Theme.setUi("notifications.dnd", !root.dnd)
                    }
                    Tile {
                        visible: root.wayland
                        label: "Night light"; icon: "moon"
                        on: !!root.st.nightlight
                        sub: on ? Theme.sv("display.nightTemp", 4500) + " K" : ""
                        onHit: { const v = !root.st.nightlight; root.setSt("nightlight", v); root.act(["nightlight", v ? "on" : "off", String(Theme.sv("display.nightTemp", 4500))]); }
                    }
                    Tile {
                        label: "Keep awake"; icon: "cup"
                        on: Ui.caffeine
                        sub: on ? "no lock/sleep" : ""
                        onHit: { const v = !Ui.caffeine; Ui.caffeine = v; root.setSt("caffeine", v); root.act(["caffeine", v ? "on" : "off"]); }
                    }
                    Tile {
                        label: "Mic"; icon: "mic"; slash: !on
                        available: !!(root.source && root.source.audio)
                        on: available && !root.source.audio.muted
                        sub: available ? (on ? Math.round(root.source.audio.volume * 100) + "%" : "muted") : "none"
                        onHit: root.source.audio.muted = !root.source.audio.muted
                    }
                    Tile {
                        label: Theme.liveMode ? "Animation" : "Wallpaper"; icon: "eye"
                        on: Theme.liveMode
                        sub: Theme.liveMode ? (Theme.liveKinds.find(k => k.id === Theme.liveKind) || { name: "" }).name : "picture"
                        onHit: Theme.set("wallpaper.mode", Theme.liveMode ? "image" : "live")
                    }
                }

                // ======================================== notifications
                Section {
                    title: "Notifications"
                    icon: "bell"
                    key: "notifs"
                    summary: NotifHistory.items.length === 0 ? "none" : NotifHistory.items.length + (root.dnd ? " · quiet" : "")
                    Repeater {
                        model: NotifHistory.items.slice(0, 15)
                        Rectangle {
                            id: nrow
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: ncol.implicitHeight + 10
                            color: nMa.containsMouse ? Theme.face2 : "transparent"
                            border.color: modelData.critical ? "#c0392b" : "transparent"
                            Column {
                                id: ncol
                                x: 6; y: 5
                                width: parent.width - 34
                                spacing: 1
                                Row {
                                    spacing: 6
                                    BText { text: nrow.modelData.app || "Notification"; color: Theme.accent; font.bold: true; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
                                    BText { text: NotifHistory.ago(nrow.modelData.time); color: Theme.textDim; font.pixelSize: Math.max(9, Theme.fontSize - 3) }
                                }
                                BText { width: parent.width; text: nrow.modelData.summary; font.bold: true }
                                Text {
                                    width: parent.width
                                    visible: text !== ""
                                    text: nrow.modelData.body
                                    color: Theme.textDim
                                    font.family: Theme.font
                                    font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea { id: nMa; anchors.fill: parent; hoverEnabled: true }
                            BText {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                text: "×"
                                font.bold: true
                                color: Theme.textDim
                                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: NotifHistory.remove(nrow.modelData.id) }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        BText { Layout.fillWidth: true; visible: NotifHistory.items.length === 0; text: "Nothing new."; color: Theme.textDim }
                        BText { Layout.fillWidth: true; visible: NotifHistory.items.length > 15; text: "+ " + (NotifHistory.items.length - 15) + " older"; color: Theme.textDim }
                        Item { Layout.fillWidth: true; visible: NotifHistory.items.length > 0 && NotifHistory.items.length <= 15 }
                        SButton { visible: NotifHistory.items.length > 0; text: "Clear all"; onClicked: NotifHistory.clear() }
                    }
                }

                                // ======================================== sound
                Section {
                    sid: "sound"
                    title: "Sound"
                    icon: "speaker"
                    summary: root.sink && root.sink.audio ? (root.sink.audio.muted ? "muted" : Math.round(root.sink.audio.volume * 100) + "%") : "no output"
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        IconBtn {
                            icon: "speaker"
                            off: !!(root.sink && root.sink.audio && root.sink.audio.muted)
                            onHit: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
                        }
                        CSlider {
                            active: !!(root.sink && root.sink.audio)
                            value: root.sink && root.sink.audio ? root.sink.audio.volume / 1.0 : 0
                            onMoved: v => { if (root.sink && root.sink.audio) { root.sink.audio.muted = false; root.sink.audio.volume = v; } }
                        }
                        BText { Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight; text: root.sink && root.sink.audio ? Math.round(root.sink.audio.volume * 100) + "%" : "–" }
                    }
                    ListRow {
                        label: "Output: " + root.nodeName(root.sink)
                        sub: root.outputs.length > 1 ? (root.expanded.outputs ? "pick one below" : root.outputs.length + " outputs — click to switch") : ""
                        onPressed: if (root.outputs.length > 1) root.toggleSec("outputs")
                    }
                    Repeater {
                        model: root.expanded.outputs ? root.outputs : []
                        ListRow {
                            required property var modelData
                            Layout.leftMargin: 16
                            label: root.nodeName(modelData)
                            active: root.sink === modelData
                            onPressed: { Pipewire.preferredDefaultAudioSink = modelData; root.toggleSec("outputs"); }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: !!(root.source && root.source.audio)
                        IconBtn {
                            icon: "mic"
                            off: !!(root.source && root.source.audio && root.source.audio.muted)
                            onHit: root.source.audio.muted = !root.source.audio.muted
                        }
                        CSlider {
                            value: root.source && root.source.audio ? root.source.audio.volume : 0
                            onMoved: v => { root.source.audio.muted = false; root.source.audio.volume = v; }
                        }
                        BText { Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight; text: root.source && root.source.audio ? Math.round(root.source.audio.volume * 100) + "%" : "–" }
                    }
                    ListRow {
                        visible: !!root.source
                        label: "Input: " + root.nodeName(root.source)
                        sub: root.inputs.length > 1 ? (root.expanded.inputs ? "pick one below" : root.inputs.length + " inputs — click to switch") : ""
                        onPressed: if (root.inputs.length > 1) root.toggleSec("inputs")
                    }
                    Repeater {
                        model: root.expanded.inputs ? root.inputs : []
                        ListRow {
                            required property var modelData
                            Layout.leftMargin: 16
                            label: root.nodeName(modelData)
                            active: root.source === modelData
                            onPressed: { Pipewire.preferredDefaultAudioSource = modelData; root.toggleSec("inputs"); }
                        }
                    }
                }

                // ======================================== media
                Section {
                    sid: "media"
                    shownIf: root.player !== null
                    title: "Now playing"
                    icon: "media"
                    summary: root.player ? (root.player.identity || "") : ""
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Bevel {
                            implicitWidth: 56; implicitHeight: 56
                            sunken: true; fill: Theme.dark
                            Image {
                                anchors.fill: parent
                                source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            CpIcon { anchors.centerIn: parent; visible: !(root.player && root.player.trackArtUrl); kind: "media"; color: Theme.lo }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            BText { Layout.fillWidth: true; font.bold: true; text: root.player ? (root.player.trackTitle || "Unknown track") : "" }
                            BText { Layout.fillWidth: true; color: Theme.textDim; text: root.player ? [root.player.trackArtist, root.player.trackAlbum].filter(x => x).join(" — ") : "" }
                            Row {
                                spacing: 3
                                SButton { text: "⏮"; implicitWidth: 40; onClicked: if (root.player && root.player.canGoPrevious) root.player.previous() }
                                SButton { text: root.player && root.player.isPlaying ? "⏸" : "▶"; implicitWidth: 52; onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying() }
                                SButton { text: "⏭"; implicitWidth: 40; onClicked: if (root.player && root.player.canGoNext) root.player.next() }
                            }
                        }
                    }
                }

                // ======================================== display
                Section {
                    sid: "display"
                    title: "Display"
                    icon: "sun"
                    summary: root.bright >= 0 ? "brightness " + Math.round(root.bright) + "%" : ""
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: root.bright >= 0
                        CpIcon { kind: "sun"; Layout.preferredWidth: 28 }
                        CSlider { value: Math.max(0, root.bright) / 100; onMoved: v => root.setBright(v * 100) }
                        BText { Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight; text: Math.round(root.bright) + "%" }
                    }
                    RowLayout {
                        visible: root.wayland
                        Layout.fillWidth: true
                        spacing: 8
                        CpIcon { kind: "moon"; Layout.preferredWidth: 28 }
                        CSlider {
                            id: warm
                            // 6500 K (off-white) on the left … 2500 K (very warm) on the right
                            value: (6500 - Theme.sv("display.nightTemp", 4500)) / 4000
                            onMoved: v => nightDelay.restart()
                            Timer {
                                id: nightDelay
                                interval: 350
                                onTriggered: {
                                    const k = Math.round((6500 - warm.live * 4000) / 100) * 100;
                                    root.setSt("nightlight", true);
                                    root.act(["nightlight", "on", String(k)]);
                                }
                            }
                        }
                        BText { Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight; text: Math.round((6500 - warm.live * 4000) / 100) * 100 + " K" }
                    }
                    BText {
                        visible: root.wayland
                        Layout.fillWidth: true
                        text: root.st.nightlight === undefined ? "" : "Night light: " + (root.st.nightlight ? "on" : "off") + " — drag the slider to make the screen warmer."
                        color: Theme.textDim
                        font.pixelSize: Math.max(10, Theme.fontSize - 2)
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }
                }

                // ======================================== battery & power
                Section {
                    sid: "battery"
                    shownIf: root.hasBattery || (root.st.profiles || []).length > 0
                    title: "Battery & power"
                    icon: "battery"
                    summary: root.hasBattery ? Math.round(Sys.battery) + "%" + (Sys.charging ? " · charging" : "") : ""
                    ColumnLayout {
                        visible: root.hasBattery
                        Layout.fillWidth: true
                        spacing: 3
                        Bevel {
                            Layout.fillWidth: true
                            implicitHeight: Theme.fontSize + 10
                            sunken: true; fill: Theme.base; padding: 1
                            Row {
                                id: cells
                                anchors.fill: parent
                                spacing: 2
                                readonly property int count: 20
                                readonly property real cw: (width - spacing * (count - 1)) / count
                                Repeater {
                                    model: cells.count
                                    Rectangle {
                                        required property int index
                                        width: cells.cw; height: cells.height
                                        visible: (index + 0.5) / cells.count <= Sys.battery / 100
                                        color: Sys.battery <= 15 && !Sys.charging ? "#c0392b" : Theme.accent
                                    }
                                }
                            }
                            BText { anchors.centerIn: parent; text: Math.round(Sys.battery) + "%"; font.bold: true; style: Text.Outline; styleColor: Theme.base }
                        }
                        BText {
                            Layout.fillWidth: true
                            text: !root.bat ? "" : (Sys.charging
                                  ? (root.bat.state === UPowerDeviceState.FullyCharged ? "Fully charged" : "Charging" + (root.dur(root.bat.timeToFull) ? " — full in " + root.dur(root.bat.timeToFull) : ""))
                                  : "On battery" + (root.dur(root.bat.timeToEmpty) ? " — " + root.dur(root.bat.timeToEmpty) + " left" : ""))
                        }
                        BText {
                            Layout.fillWidth: true
                            color: Theme.textDim
                            font.pixelSize: Math.max(10, Theme.fontSize - 2)
                            text: {
                                const b = root.battDev || root.bat;
                                if (!b) return "";
                                const parts = [];
                                if (b.changeRate) parts.push(Math.abs(b.changeRate).toFixed(1) + " W");
                                if (b.energyCapacity) parts.push(b.energy.toFixed(1) + " / " + b.energyCapacity.toFixed(1) + " Wh");
                                if (root.battDev && root.battDev.healthSupported && root.battDev.healthPercentage > 0) parts.push("health " + Math.round(root.battDev.healthPercentage) + "%");
                                return parts.join("  ·  ");
                            }
                        }
                    }
                    RowLayout {
                        visible: (root.st.profiles || []).length > 0
                        Layout.fillWidth: true
                        spacing: 3
                        BText { text: "Mode"; Layout.preferredWidth: 50 }
                        Repeater {
                            model: root.st.profiles || []
                            SButton {
                                required property string modelData
                                Layout.fillWidth: true
                                text: modelData === "power-saver" ? "Saver" : modelData === "performance" ? "Performance" : "Balanced"
                                checked: root.st.profile === modelData
                                onClicked: { root.setSt("profile", modelData); root.act(["profile", modelData]); }
                            }
                        }
                    }
                }

                // ======================================== Wi-Fi
                Section {
                    title: root.st.netType === "ethernet" ? "Network" : "Wi-Fi"
                    icon: root.st.netType === "ethernet" ? "wired" : "wifi"
                    key: "wifi"
                    summary: root.st.net ? root.st.net : (root.st.wifi === false ? "off" : "not connected")
                    BText {
                        Layout.fillWidth: true
                        visible: !!root.st.net
                        color: Theme.textDim
                        text: "Connected to " + root.st.net + (root.st.ip ? "  ·  " + root.st.ip : "")
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        visible: root.st.wifi !== null && root.st.wifi !== undefined
                        SButton { text: root.st.wifi ? "Turn Wi-Fi off" : "Turn Wi-Fi on"; onClicked: { const v = !root.st.wifi; root.setSt("wifi", v); root.act(["wifi", v ? "on" : "off"]); } }
                        SButton { text: scanProc.running ? "Scanning…" : "Scan"; visible: !!root.st.wifi; onClicked: root.scan() }
                        SButton { text: "Disconnect"; visible: root.st.netType === "wifi"; onClicked: root.act(["wifi-disconnect"]) }
                        Item { Layout.fillWidth: true }
                        SButton { text: "More…"; onClicked: { root.closeRequested(); Quickshell.execDetached(["sh", "-c", "command -v nm-connection-editor >/dev/null && exec nm-connection-editor || exec kitty -e nmtui"]); } }
                    }
                    BText { visible: root.message !== ""; text: root.message; color: "#c0392b"; Layout.fillWidth: true }
                    Repeater {
                        model: root.st.wifi ? root.nets : []
                        ColumnLayout {
                            id: netRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 2
                            ListRow {
                                icon: "wifi"
                                label: netRow.modelData.ssid + (netRow.modelData.secure ? "  🔒" : "")
                                sub: netRow.modelData.signal + "% signal" + (netRow.modelData.known && !netRow.modelData.active ? "  ·  saved" : "") + (netRow.modelData.secure ? "" : "  ·  open network")
                                active: netRow.modelData.active
                                button: netRow.modelData.active ? "" : (root.connecting === netRow.modelData.ssid ? "…" : "Connect")
                                onHit: {
                                    const n = netRow.modelData;
                                    root.message = "";
                                    if (n.secure && !n.known) { root.askPass = n.ssid; return; }
                                    root.connecting = n.ssid;
                                    root.act(["wifi-connect", n.ssid]);
                                }
                            }
                            RowLayout {
                                visible: root.askPass === netRow.modelData.ssid
                                Layout.fillWidth: true
                                Layout.leftMargin: 30
                                spacing: 4
                                Bevel {
                                    Layout.fillWidth: true
                                    implicitHeight: Theme.fontSize + 12
                                    sunken: true; fill: Theme.base; padding: 2
                                    TextInput {
                                        id: pw
                                        anchors.fill: parent
                                        anchors.leftMargin: 4
                                        verticalAlignment: TextInput.AlignVCenter
                                        echoMode: showPw.checked ? TextInput.Normal : TextInput.Password
                                        passwordCharacter: "*"
                                        color: Theme.text
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize
                                        clip: true
                                        onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                                        onAccepted: joinBtn.clicked()
                                        Keys.onEscapePressed: root.askPass = ""
                                        BText { visible: pw.text === ""; text: "Password"; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }
                                SCheck { id: showPw; text: "Show" }
                                SButton {
                                    id: joinBtn
                                    text: "Join"
                                    highlighted: true
                                    onClicked: {
                                        root.connecting = netRow.modelData.ssid;
                                        root.askPass = "";
                                        root.act(["wifi-connect", netRow.modelData.ssid, pw.text]);
                                    }
                                }
                            }
                        }
                    }
                    BText {
                        visible: !!root.st.wifi && root.nets.length === 0
                        text: scanProc.running ? "Looking for networks…" : "No networks found."
                        color: Theme.textDim
                    }
                }

                // ======================================== Bluetooth
                Section {
                    shownIf: root.st.bt !== null && root.st.bt !== undefined
                    title: "Bluetooth"
                    icon: "bt"
                    key: "bt"
                    summary: !root.st.bt ? "off" : ((root.st.btDevices || []).filter(d => d.connected).map(d => d.name).join(", ") || "on")
                    RowLayout {
                        spacing: 4
                        SButton { text: root.st.bt ? "Turn Bluetooth off" : "Turn Bluetooth on"; onClicked: { const v = !root.st.bt; root.setSt("bt", v); root.act(["bt", v ? "on" : "off"]); } }
                        SButton { text: "Pair new…"; onClicked: { root.closeRequested(); Quickshell.execDetached(["sh", "-c", "command -v blueman-manager >/dev/null && exec blueman-manager || exec kitty -e bluetoothctl"]); } }
                    }
                    Repeater {
                        model: root.st.bt ? (root.st.btDevices || []) : []
                        ListRow {
                            required property var modelData
                            icon: "bt"
                            label: modelData.name
                            sub: (modelData.connected ? "connected" : "paired") + (modelData.battery >= 0 ? "  ·  battery " + modelData.battery + "%" : "")
                            active: modelData.connected
                            button: modelData.connected ? "Disconnect" : "Connect"
                            onHit: root.act([modelData.connected ? "bt-disconnect" : "bt-connect", modelData.mac])
                        }
                    }
                    BText { visible: !!root.st.bt && (root.st.btDevices || []).length === 0; text: "No paired devices yet."; color: Theme.textDim }
                }

                // ======================================== system
                Section {
                    title: "System"
                    icon: "cpu"
                    key: "system"
                    summary: root.info.uptime ? "up " + root.dur(root.info.uptime) : ""
                    Repeater {
                        model: [
                            { l: "CPU", v: Sys.cpu / 100, t: Math.round(Sys.cpu) + "%" + (root.info.temp ? "  ·  " + root.info.temp + " °C" : "") },
                            { l: "Memory", v: root.info.memTotal ? root.info.memUsed / root.info.memTotal : 0, t: root.bytes(root.info.memUsed) + " / " + root.bytes(root.info.memTotal) },
                            { l: "Disk", v: root.info.diskTotal ? root.info.diskUsed / root.info.diskTotal : 0, t: root.bytes(root.info.diskUsed) + " / " + root.bytes(root.info.diskTotal) }
                        ]
                        RowLayout {
                            id: sysRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8
                            BText { text: sysRow.modelData.l; Layout.preferredWidth: 64 }
                            Bevel {
                                Layout.fillWidth: true
                                implicitHeight: 12
                                sunken: true; fill: Theme.base; depth: Math.min(2, Theme.bevel)
                                Rectangle { x: 1; y: 1; height: parent.height - 2; width: Math.max(0, Math.min(1, sysRow.modelData.v)) * (parent.width - 2); color: Theme.accent }
                            }
                            BText { text: sysRow.modelData.t; Layout.preferredWidth: 140; horizontalAlignment: Text.AlignRight; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
                        }
                    }
                    BText {
                        Layout.fillWidth: true
                        color: Theme.textDim
                        font.pixelSize: Math.max(10, Theme.fontSize - 2)
                        text: [root.info.distro, root.info.kernel ? "kernel " + root.info.kernel : "", root.info.host,
                               root.info.load ? "load " + root.info.load.join(" ") : ""].filter(x => x).join("  ·  ")
                    }
                    SButton {
                        text: "Task manager…"
                        onClicked: { root.closeRequested(); Quickshell.execDetached(["sh", "-c", "exec kitty --class bevel-btop -e btop"]); }
                    }
                }

                // ======================================== shortcuts
                RowLayout {
                    visible: root.has("footer")
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: [
                            { l: "Settings", i: "gear", c: ["qs", "-c", "bevel", "ipc", "call", "settings", "show"] },
                            { l: "Screenshot", i: "camera", c: ["bevelctl", "shot", "region"] },
                            { l: "Lock", i: "lock", c: ["bevelctl", "lock"] },
                            { l: "Power…", i: "power", c: ["qs", "-c", "bevel", "ipc", "call", "power", "show"] }
                        ]
                        Bevel {
                            id: scBtn
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 30
                            sunken: scMa.pressed
                            depth: Math.min(2, Theme.bevel)
                            radius: Theme.radiusSm
                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                CpIcon { kind: scBtn.modelData.i; width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter }
                                BText { text: scBtn.modelData.l; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
                            }
                            MouseArea {
                                id: scMa
                                anchors.fill: parent
                                onClicked: { root.closeRequested(); Quickshell.execDetached(["sh", "-c", "sleep 0.25; exec \"$@\"", "sh"].concat(scBtn.modelData.c)); }
                            }
                        }
                    }
                }
            }
        }
    }
}
