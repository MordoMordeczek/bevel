import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "blockfont.js" as Block

// One desktop widget tile. kind = Theme.widgetKinds id, cw/ch = size in grid cells.
// Looks: window (little 9x window) · panel (raised 9x panel) · tiles (flat Metro colours) · glass
Item {
    id: w
    property string kind: "clock"
    property int cw: 2
    property int ch: 1
    property int index: 0
    property var cfg: ({})
    readonly property string look: Theme.sv("widgets.style", "tiles")
    readonly property real alpha: Theme.sv("widgets.opacity", 0.95)
    readonly property bool light: look === "window" || look === "panel"     // dark text on grey
    readonly property color fg: light ? Theme.text : "#ffffff"
    readonly property color dim: light ? Theme.textDim : Qt.rgba(1, 1, 1, 0.7)
    readonly property color hiCol: light ? Theme.accent : "#ffffff"
    readonly property var meta: Theme.widgetKinds.find(k => k.id === kind) || { name: kind }
    readonly property int titleH: look === "window" ? Theme.fontSize + 8 : 0
    readonly property real u: Math.min(width / cw, (height - titleH) / ch)      // one cell, for font sizes

    // metro: each tile gets one of four shades of your accent
    readonly property color tileColor: {
        const a = Theme.accent;
        switch (index % 5) {
        case 0: return a;
        case 1: return Qt.darker(a, 1.35);
        case 2: return Qt.darker(Theme.accent2, 1.55);
        case 3: return Qt.darker(a, 1.75);
        default: return Qt.darker(Theme.accent2, 1.2);
        }
    }

    // ---- frame
    Bevel {
        anchors.fill: parent
        visible: w.light
        radius: Theme.radius
        fillOpacity: w.alpha
    }
    Rectangle {
        anchors.fill: parent
        visible: w.look === "tiles"
        color: Qt.rgba(w.tileColor.r, w.tileColor.g, w.tileColor.b, w.alpha)
        radius: Theme.radiusSm
        border.color: hover.containsMouse ? Qt.rgba(1, 1, 1, 0.55) : "transparent"
        border.width: 2
    }
    Rectangle {
        anchors.fill: parent
        visible: w.look === "glass"
        color: Qt.rgba(0, 0, 0, 0.42 * w.alpha + 0.1)
        radius: Theme.radius
        border.color: Qt.rgba(1, 1, 1, hover.containsMouse ? 0.4 : 0.16)
    }
    Rectangle {
        // 9x title bar
        visible: w.look === "window"
        x: 3; y: 3
        width: parent.width - 6
        height: w.titleH - 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.accent }
            GradientStop { position: 1; color: Theme.accent2 }
        }
        BText {
            anchors.fill: parent
            anchors.leftMargin: 5
            text: w.meta.name
            color: Theme.accentText
            font.bold: true
            font.pixelSize: Math.max(10, Theme.fontSize - 2)
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: w.clickCmd.length > 0 || w.menu !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            // the clock, calendar, battery… widgets open the same menu as the bar item
            if (w.menu !== "") {
                if ((Quickshell.env("WAYLAND_DISPLAY") || "") !== "") {
                    Ui.controlOpen = false;
                    Ui.flyoutScreen = null;
                    Ui.flyoutX = -1;
                    Ui.flyout = Ui.flyout === w.menu ? "" : w.menu;
                } else Quickshell.execDetached(["bevelctl", "flyout", w.menu]);
            } else if (w.clickCmd.length > 0) Quickshell.execDetached(w.clickCmd);
        }
    }
    readonly property string menu: ({ clock: "clock", calendar: "clock", worldclock: "clock", battery: "battery", network: "network",
                                      cpu: "system", ram: "system", disk: "system", uptime: "system", media: "sound", visualizer: "sound" })[kind] || ""
    readonly property var clickCmd: {
        switch (kind) {
        case "clock": case "calendar": return ["bevelctl", "controlpanel"];
        case "cpu": case "ram": case "disk": case "uptime": return ["kitty", "--class", "bevel-btop", "-e", "btop"];
        case "fetch": case "btw": return ["kitty", "--hold", "fastfetch"];
        case "computer": return ["sh", "-c", "command -v dolphin >/dev/null && exec dolphin / || exec xdg-open /"];
        case "homefolder": return ["xdg-open", Theme.home];
        case "documents": return ["sh", "-c", "mkdir -p \"$HOME/Documents\"; exec xdg-open \"$HOME/Documents\""];
        case "downloads": return ["sh", "-c", "mkdir -p \"$HOME/Downloads\"; exec xdg-open \"$HOME/Downloads\""];
        case "terminalicon": return ["kitty"];
        case "trash": return ["sh", "-c", "command -v dolphin >/dev/null && exec dolphin trash:/ || exec xdg-open \"$HOME/.local/share/Trash/files\""];
        case "network": case "battery": return ["bevelctl", "controlpanel", "show"];
        default: return [];
        }
    }

    // ---- content
    Item {
        id: body
        anchors.fill: parent
        anchors.topMargin: w.titleH + (w.light ? 6 : 8)
        anchors.leftMargin: w.light ? 8 : 10
        anchors.rightMargin: w.light ? 8 : 10
        anchors.bottomMargin: w.light ? 6 : 8
        clip: true
        Loader {
            anchors.fill: parent
            sourceComponent: ({ clock: clockC, calendar: calC, fetch: fetchC, btw: btwC, ascii: asciiC, cpu: cpuC, ram: ramC,
                                disk: diskC, battery: batC, network: netC, media: mediaC, weather: weatherC, notes: notesC,
                                uptime: uptimeC, tip: tipC, apps: appsC, worldclock: worldC, rss: rssC, visualizer: visC,
                                pomodoro: pomoC, minesweeper: minesC, trash: iconC, computer: iconC, homefolder: iconC,
                                documents: iconC, downloads: iconC, terminalicon: iconC })[w.kind] || null
        }
    }

    // a label in the tile's corner, Metro style
    component Caption: BText {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        color: w.dim
        font.pixelSize: Math.max(10, Theme.fontSize - 2)
    }
    component Meter: Item {
        property real value: 0
        implicitHeight: 8
        Rectangle { anchors.fill: parent; color: w.light ? Theme.base : Qt.rgba(1, 1, 1, 0.18); border.color: w.light ? Theme.lo : "transparent" }
        Rectangle { x: 1; y: 1; height: parent.height - 2; width: Math.max(0, Math.min(1, parent.value)) * (parent.width - 2); color: w.hiCol }
    }

    property var now: new Date()
    Timer { interval: 1000; running: w.kind === "clock" || w.kind === "calendar" || w.kind === "uptime"; repeat: true; onTriggered: w.now = new Date() }

    // ================================================================ clock
    Component {
        id: clockC
        Item {
            readonly property bool analog: w.cw >= 2 && w.ch >= 2
            readonly property bool h12: Theme.clockFormat !== "HH:mm"
            Column {
                visible: !parent.analog
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                    text: Qt.formatTime(w.now, parent.parent.h12 ? "h:mm" : "HH:mm")
                    color: w.fg
                    font.family: Theme.lcdClock ? Theme.mono : Theme.font
                    font.pixelSize: Math.round(w.u * (w.cw >= 2 ? 0.46 : 0.36))
                    font.bold: !Theme.lcdClock
                }
                BText {
                    text: w.cw >= 2 ? w.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM") : w.now.toLocaleDateString(Qt.locale(), "ddd d")
                    color: w.dim
                    font.pixelSize: Math.max(10, Math.round(w.u * 0.13))
                }
            }
            Canvas {
                id: face
                visible: parent.analog
                width: Math.min(parent.width, parent.height - 22)
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                property var t: w.now
                onTChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    const r = width / 2 - 2, cx = width / 2, cy = height / 2;
                    c.fillStyle = w.light ? Theme.base : Qt.rgba(1, 1, 1, 0.08);
                    c.beginPath(); c.arc(cx, cy, r, 0, Math.PI * 2); c.fill();
                    c.strokeStyle = w.fg; c.lineWidth = 2;
                    c.beginPath(); c.arc(cx, cy, r, 0, Math.PI * 2); c.stroke();
                    for (let i = 0; i < 12; i++) {
                        const a = i * Math.PI / 6, l = i % 3 === 0 ? 0.8 : 0.88;
                        c.fillStyle = w.fg;
                        c.fillRect(cx + Math.sin(a) * r * l - 2, cy - Math.cos(a) * r * l - 2, 4, 4);
                    }
                    const hand = (a, len, wd, col) => {
                        c.strokeStyle = col; c.lineWidth = wd; c.lineCap = "square";
                        c.beginPath(); c.moveTo(cx, cy); c.lineTo(cx + Math.sin(a) * len, cy - Math.cos(a) * len); c.stroke();
                    };
                    const d = face.t;
                    hand((d.getHours() % 12 + d.getMinutes() / 60) * Math.PI / 6, r * 0.5, 4, w.fg);
                    hand((d.getMinutes() + d.getSeconds() / 60) * Math.PI / 30, r * 0.72, 3, w.fg);
                    hand(d.getSeconds() * Math.PI / 30, r * 0.8, 1, w.light ? Theme.accent : Theme.accent2);
                }
            }
            BText {
                visible: parent.analog
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(w.now, parent.h12 ? "h:mm AP" : "HH:mm") + "  ·  " + w.now.toLocaleDateString(Qt.locale(), "ddd d MMM")
                color: w.dim
            }
        }
    }

    // ================================================================ calendar
    Component {
        id: calC
        ColumnLayout {
            spacing: 2
            BText {
                text: w.now.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                color: w.fg
                font.bold: true
            }
            Grid {
                id: cg
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                readonly property real cw: width / 7
                readonly property real rh: height / 7
                readonly property date first: new Date(w.now.getFullYear(), w.now.getMonth(), 1)
                readonly property int lead: (first.getDay() + 6) % 7
                readonly property int days: new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate()
                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    BText { required property string modelData; width: cg.cw; height: cg.rh; horizontalAlignment: Text.AlignHCenter; text: modelData; color: w.dim; font.bold: true; font.pixelSize: Math.max(9, Math.min(Theme.fontSize, cg.rh * 0.7)) }
                }
                Repeater {
                    model: 42
                    Rectangle {
                        required property int index
                        readonly property int day: index - cg.lead + 1
                        readonly property bool inMonth: day >= 1 && day <= cg.days
                        readonly property bool today: inMonth && day === w.now.getDate()
                        width: cg.cw; height: cg.rh
                        color: today ? (w.light ? Theme.accent : "#ffffff") : "transparent"
                        BText {
                            anchors.centerIn: parent
                            text: parent.inMonth ? parent.day : ""
                            color: parent.today ? (w.light ? Theme.accentText : w.tileColor) : w.fg
                            font.bold: parent.today
                            font.pixelSize: Math.max(9, Math.min(Theme.fontSize, cg.rh * 0.7))
                        }
                    }
                }
            }
        }
    }

    // ================================================================ system info (fastfetch)
    // Compact, like the real thing: logo on the left, user@host, then as many lines as fit.
    Component {
        id: fetchC
        Item {
            id: ff
            Component.onCompleted: Info.users++
            Component.onDestruction: Info.users--
            readonly property var f: Info.fetch
            readonly property var s: Info.sys
            readonly property bool ready: Object.keys(f).length > 0
            readonly property bool isArch: ((f.os || Theme.distro) + "").toLowerCase().indexOf("arch") >= 0
            readonly property bool mono: Theme.accent.hslSaturation < 0.08        // black & white looks
            function shortCpu(c) {
                return (c || "").replace(/\((R|TM)\)/g, "").replace(/ with .*Graphics/, "").replace(/^(AMD|Intel) /, "")
                    .replace(/ (CPU|Processor)/g, "").replace(/\s+/g, " ").trim();
            }
            function shortGpu(g) {
                return (g || "").replace(/^(NVIDIA|AMD|ATI|Intel\(R\)|Intel) /, "").replace(/ \[Discrete\]| \[Integrated\]/, "").trim();
            }
            // most useful first; the tile shows as many as fit
            readonly property var rows: [
                ["OS", f.osPretty], ["Kernel", (f.kernel || "").replace(/-arch\d+-\d+$/, "")], ["Uptime", s.uptime ? Info.dur(s.uptime) : ""],
                ["Pkgs", (f.packages || "").replace(" (pacman)", "")], ["WM", f.wm], ["CPU", shortCpu(f.cpu)],
                ["Memory", s.memTotal ? Info.bytes(s.memUsed) + " / " + Info.bytes(s.memTotal) : ""], ["GPU", shortGpu((f.gpu || [])[0])], ["Shell", f.shell],
                ["Disk", s.diskTotal ? Info.bytes(s.diskUsed) + " / " + Info.bytes(s.diskTotal) : ""],
                ["Term", f.terminal], ["Display", f.display], ["Theme", f.theme], ["Font", f.font], ["Host", f.host]
            ].filter(r => r[1])
            readonly property int fs: Math.max(13, Math.min(16, Math.round(height / 11)))
            readonly property int lineH: Math.round(fs * 1.2)
            readonly property int fit: Math.max(1, Math.floor((height - lineH * 1.6 - 8 - lineH * 0.9) / lineH))
            readonly property bool showLogo: width >= 260 && height >= 70
            // whole multiples of the 32px art keep it crisp
            readonly property int logoSize: {
                const m = Math.min(height - 6, width * 0.3);
                return m >= 64 ? Math.floor(m / 32) * 32 : Math.max(32, Math.floor(m / 16) * 16);
            }

            ArchLogo {
                id: logo
                visible: ff.showLogo && ff.isArch
                anchors.verticalCenter: parent.verticalCenter
                x: 2
                width: ff.logoSize; height: ff.logoSize
                // Arch blue, or white on the coloured tiles where blue would clash
                tint: ff.mono || w.look === "tiles" ? w.fg : "transparent"
            }
            PixIcon {
                visible: ff.showLogo && !ff.isArch
                anchors.centerIn: logo
                kind: "monitor"
                zoom: Math.max(1, Math.floor(ff.logoSize / 16))
            }
            Column {
                id: info
                anchors.left: ff.showLogo ? logo.right : parent.left
                anchors.leftMargin: ff.showLogo ? Math.round(ff.fs * 1.1) : 2
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                // user@host, then a rule as long as it — the fastfetch header
                Text {
                    id: who
                    readonly property string u: (ff.f.user || (Theme.distro.toLowerCase() + "@bevel"))
                    textFormat: Text.StyledText
                    text: "<b>" + u.split("@")[0] + "</b>" + (u.indexOf("@") >= 0 ? "<font color='" + w.dim + "'>@</font><b>" + u.split("@").slice(1).join("@") + "</b>" : "")
                    color: w.hiCol
                    font.family: Theme.mono
                    font.pixelSize: ff.fs + 1
                    width: parent.width
                    elide: Text.ElideRight
                    height: Math.round(ff.lineH * 1.15)
                    verticalAlignment: Text.AlignVCenter
                }
                Rectangle { width: Math.min(parent.width, who.contentWidth); height: 1; color: w.dim }
                Item { width: 1; height: 4 }
                Text {
                    visible: !ff.ready
                    text: "Collecting system info…"
                    color: w.dim
                    font.family: Theme.mono
                    font.pixelSize: ff.fs
                    height: ff.lineH
                }
                Repeater {
                    model: ff.ready ? ff.rows.slice(0, ff.fit) : []
                    Row {
                        required property var modelData
                        width: info.width
                        height: ff.lineH
                        Text {
                            id: key
                            width: Math.round(ff.fs * 3.9)
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: modelData[0]
                            color: w.hiCol
                            font.family: Theme.mono
                            font.pixelSize: ff.fs
                            font.bold: true
                        }
                        Text {
                            width: parent.width - key.width
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: modelData[1]
                            color: w.fg
                            font.family: Theme.mono
                            font.pixelSize: ff.fs
                            elide: Text.ElideRight
                        }
                    }
                }
                Item { width: 1; height: Math.round(ff.lineH * 0.3) }
                // the 8 terminal colours, like fastfetch's colour blocks
                Row {
                    visible: ff.ready
                    Repeater {
                        model: [0, 1, 2, 3, 4, 5, 6, 7]
                        Rectangle {
                            required property int modelData
                            width: Math.round(ff.fs * 1.2); height: Math.round(ff.fs * 0.7)
                            color: Theme.c.ansi ? Theme.c.ansi["color" + modelData] : Theme.accent
                        }
                    }
                }
            }
        }
    }

    // ================================================================ I use … btw
    Component {
        id: btwC
        Item {
            readonly property string distro: Theme.distro
            RowLayout {
                anchors.fill: parent
                spacing: 8
                ArchLogo {
                    visible: w.cw >= 2 && parent.parent.distro.toLowerCase().indexOf("arch") >= 0
                    Layout.preferredWidth: w.u * 0.6 >= 64 ? Math.floor(w.u * 0.6 / 32) * 32 : 32
                    Layout.preferredHeight: Layout.preferredWidth
                    tint: Theme.accent.hslSaturation < 0.08 || w.look === "tiles" ? w.fg : "transparent"
                }
                PixIcon {
                    visible: w.cw >= 2 && parent.parent.distro.toLowerCase().indexOf("arch") < 0
                    kind: "monitor"
                    zoom: Math.max(1, Math.floor(w.u * 0.5 / 16))
                }
                Column {
                    Layout.fillWidth: true
                    BText { text: "I use"; color: w.dim; font.pixelSize: Math.max(10, w.u * 0.14) }
                    BText { width: parent.width; text: parent.parent.parent.distro; color: w.fg; font.bold: true; font.pixelSize: Math.max(12, w.u * (w.cw >= 2 ? 0.3 : 0.24)) }
                    BText { text: "btw."; color: w.hiCol; font.pixelSize: Math.max(10, w.u * 0.16) }
                }
            }
        }
    }

    // ================================================================ ASCII text
    Component {
        id: asciiC
        Canvas {
            // the text in a 5x5 block font, drawn as crisp squares (block · shade · dots · hash)
            readonly property string txt: w.cfg.text || Theme.sv("widgets.asciiText", "BEVEL")
            readonly property string sty: Theme.sv("widgets.asciiStyle", "block")
            readonly property var lines: Block.render(txt, "hash").split("\n")
            onTxtChanged: requestPaint()
            onStyChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const c = getContext("2d");
                c.reset();
                const rows = lines.length;
                const cols = lines.reduce((m, l) => Math.max(m, l.length), 1);
                const px = Math.max(1, Math.floor(Math.min(width / cols, height / rows)));
                const ox = Math.floor((width - cols * px) / 2), oy = Math.floor((height - rows * px) / 2);
                for (let y = 0; y < rows; y++) {
                    for (let x = 0; x < lines[y].length; x++) {
                        const on = lines[y][x] === "#";
                        const X = ox + x * px, Y = oy + y * px;
                        if (sty === "shade" && !on && lines[y].length > 0) {
                            c.fillStyle = Qt.rgba(w.fg.r, w.fg.g, w.fg.b, 0.12);
                            c.fillRect(X, Y, px - 1, px - 1);
                        }
                        if (!on) continue;
                        c.fillStyle = sty === "shade" ? w.hiCol : w.fg;
                        if (sty === "dots") {
                            c.beginPath(); c.arc(X + px / 2, Y + px / 2, px * 0.42, 0, Math.PI * 2); c.fill();
                        } else if (sty === "hash") {
                            c.font = "bold " + Math.round(px * 1.1) + "px '" + Theme.mono + "'";
                            c.textAlign = "center"; c.textBaseline = "middle";
                            c.fillText("#", X + px / 2, Y + px / 2);
                        } else {
                            c.fillRect(X, Y, px - (px > 3 ? 1 : 0), px - (px > 3 ? 1 : 0));
                        }
                    }
                }
            }
        }
    }

    // ================================================================ CPU
    Component {
        id: cpuC
        Item {
            Component.onCompleted: Info.users++
            Component.onDestruction: Info.users--
            Canvas {
                id: graph
                anchors.fill: parent
                anchors.topMargin: w.u * 0.38
                anchors.bottomMargin: 18
                visible: w.cw >= 2
                property var h: Info.cpuHistory
                onHChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    const n = 40, bw = width / n;
                    c.fillStyle = w.light ? Theme.accent : Qt.rgba(1, 1, 1, 0.75);
                    for (let i = 0; i < h.length; i++) {
                        const v = h[h.length - 1 - i] / 100;
                        const bh = Math.max(1, Math.round(v * height / 3) * 3);
                        c.fillRect(Math.floor(width - (i + 1) * bw), height - bh, Math.ceil(bw) - 1, bh);
                    }
                }
            }
            Text { text: Math.round(Info.cpu) + "%"; color: w.fg; font.family: Theme.font; font.bold: true; font.pixelSize: w.u * 0.3 }
            Caption { text: "CPU" + (Info.sys.temp ? "  ·  " + Info.sys.temp + " °C" : "") }
        }
    }

    // ================================================================ RAM / disk
    Component {
        id: ramC
        Item {
            Component.onCompleted: Info.users++
            Component.onDestruction: Info.users--
            readonly property real frac: Info.sys.memTotal ? Info.sys.memUsed / Info.sys.memTotal : 0
            Column {
                width: parent.width
                spacing: 4
                Text { text: Math.round(parent.parent.frac * 100) + "%"; color: w.fg; font.bold: true; font.pixelSize: w.u * 0.3; font.family: Theme.font }
                Meter { width: parent.width; value: parent.parent.frac }
                BText { width: parent.width; text: Info.bytes(Info.sys.memUsed) + " / " + Info.bytes(Info.sys.memTotal); color: w.dim; font.pixelSize: Math.max(9, Theme.fontSize - 3) }
                BText { visible: w.cw >= 2 && Info.sys.swapTotal > 0; text: "swap " + Info.bytes(Info.sys.swapUsed) + " / " + Info.bytes(Info.sys.swapTotal); color: w.dim; font.pixelSize: Math.max(9, Theme.fontSize - 3) }
            }
            Caption { text: "Memory" }
        }
    }
    Component {
        id: diskC
        Item {
            Component.onCompleted: Info.users++
            Component.onDestruction: Info.users--
            readonly property real frac: Info.sys.diskTotal ? Info.sys.diskUsed / Info.sys.diskTotal : 0
            Column {
                width: parent.width
                spacing: 4
                Text { text: Math.round(parent.parent.frac * 100) + "%"; color: w.fg; font.bold: true; font.pixelSize: w.u * 0.3; font.family: Theme.font }
                Meter { width: parent.width; value: parent.parent.frac }
                BText { width: parent.width; text: Info.bytes(Info.sys.diskTotal - Info.sys.diskUsed) + " free"; color: w.dim; font.pixelSize: Math.max(9, Theme.fontSize - 3) }
            }
            Caption { text: "Disk" }
        }
    }

    // ================================================================ battery
    Component {
        id: batC
        Item {
            readonly property var b: UPower.displayDevice
            Column {
                width: parent.width
                spacing: 4
                Row {
                    spacing: 6
                    PixIcon { kind: "battery"; zoom: 2; anchors.verticalCenter: parent.verticalCenter; visible: w.cw >= 2 }
                    Text { text: Sys.hasBattery ? Math.round(Sys.battery) + "%" : "AC"; color: w.fg; font.bold: true; font.pixelSize: w.u * 0.3; font.family: Theme.font }
                }
                Meter { width: parent.width; value: Sys.battery / 100; visible: Sys.hasBattery }
                BText {
                    width: parent.width
                    color: w.dim
                    font.pixelSize: Math.max(9, Theme.fontSize - 3)
                    text: !Sys.hasBattery ? "no battery" : (Sys.charging ? "charging" : (parent.parent.b && parent.parent.b.timeToEmpty > 0 ? Info.dur(parent.parent.b.timeToEmpty) + " left" : "on battery"))
                }
            }
            Caption { text: "Battery" }
        }
    }

    // ================================================================ network
    Component {
        id: netC
        Item {
            Component.onCompleted: Info.users++
            Component.onDestruction: Info.users--
            RowLayout {
                anchors.fill: parent
                spacing: 10
                PixIcon { kind: Sys.netUp ? (Sys.wifi ? "wifi" : "network") : "wifi-off"; zoom: 2; Layout.alignment: Qt.AlignTop }
                Column {
                    Layout.fillWidth: true
                    BText { width: parent.width; text: Sys.net; color: w.fg; font.bold: true }
                    Text { text: "↓ " + Info.bytes(Info.rxRate) + "/s"; color: w.fg; font.family: Theme.mono; font.pixelSize: Theme.fontSize + 3 }
                    Text { text: "↑ " + Info.bytes(Info.txRate) + "/s"; color: w.dim; font.family: Theme.mono; font.pixelSize: Theme.fontSize + 3 }
                }
            }
        }
    }

    // ================================================================ media
    Component {
        id: mediaC
        Item {
            readonly property var p: {
                const l = Mpris.players.values;
                for (let i = 0; i < l.length; i++) if (l[i].isPlaying) return l[i];
                return l.length > 0 ? l[0] : null;
            }
            RowLayout {
                anchors.fill: parent
                spacing: 10
                Rectangle {
                    visible: w.ch >= 2 || w.cw >= 3
                    Layout.preferredWidth: Math.min(parent.height, w.u * 0.9)
                    Layout.preferredHeight: Layout.preferredWidth
                    color: Qt.rgba(0, 0, 0, 0.3)
                    Image { anchors.fill: parent; source: parent.parent.parent.p && parent.parent.parent.p.trackArtUrl ? parent.parent.parent.p.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                    PixIcon { anchors.centerIn: parent; kind: "music"; zoom: 2; visible: !(parent.parent.parent.p && parent.parent.parent.p.trackArtUrl) }
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    readonly property var p: parent.parent.p
                    BText { width: parent.width; text: parent.p ? (parent.p.trackTitle || "Unknown") : "Nothing playing"; color: w.fg; font.bold: true }
                    BText { width: parent.width; text: parent.p ? (parent.p.trackArtist || parent.p.identity || "") : ""; color: w.dim; font.pixelSize: Math.max(9, Theme.fontSize - 2) }
                    Row {
                        spacing: 14
                        visible: !!parent.p
                        Repeater {
                            model: [{ t: "⏮", f: "previous" }, { t: "⏯", f: "togglePlaying" }, { t: "⏭", f: "next" }]
                            Text {
                                required property var modelData
                                text: modelData.t
                                color: w.fg
                                font.pixelSize: Theme.fontSize + 6
                                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: { const pl = parent.parent.parent.p; if (pl) pl[parent.modelData.f](); } }
                            }
                        }
                    }
                }
            }
        }
    }

    // ================================================================ weather
    Component {
        id: weatherC
        Item {
            Component.onCompleted: Info.wantWeather = true
            readonly property var wx: Info.weather
            readonly property string icon: {
                const c = wx.code || 0;
                if (c === 113) return (new Date().getHours() >= 20 || new Date().getHours() < 6) ? "moon" : "sun";
                if ([179, 182, 185, 227, 230, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377, 392, 395].indexOf(c) >= 0) return "snow";
                if (c >= 176 && c !== 248 && c !== 260) return "rain";
                return "cloud";
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -8
                spacing: 12
                PixIcon { kind: parent.parent.icon; zoom: w.cw >= 2 ? 3 : 2; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: parent.parent.parent.wx.temp !== undefined ? parent.parent.parent.wx.temp + "°C" : (parent.parent.parent.wx.error ? "--" : "…")
                        color: w.fg; font.bold: true; font.pixelSize: w.u * 0.3; font.family: Theme.font
                    }
                    BText {
                        visible: w.cw >= 2
                        width: body.width - 70
                        text: parent.parent.parent.wx.error ? "can't reach wttr.in" : (parent.parent.parent.wx.desc || "")
                        color: w.dim
                        font.pixelSize: Math.max(10, Theme.fontSize - 2)
                    }
                }
            }
            Caption { text: Info.weather.place || "Weather" }
        }
    }

    // ================================================================ sticky note
    Component {
        id: notesC
        Item {
            FileView {
                id: noteFile
                path: Theme.cfgDir + "/notes.txt"
                printErrors: false
                blockLoading: true
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                visible: w.look === "tiles" || w.look === "glass"
                color: "#fff3a0"
                opacity: 0.0
            }
            TextEdit {
                id: ed
                anchors.fill: parent
                text: noteFile.text()
                color: w.fg
                wrapMode: TextEdit.Wrap
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
                selectByMouse: true
                selectionColor: Theme.accent
                onTextChanged: saveNote.restart()
                Timer { id: saveNote; interval: 800; onTriggered: noteFile.setText(ed.text) }
            }
            BText {
                visible: ed.text === "" && !ed.activeFocus
                text: "Click to write a note…"
                color: w.dim
            }
        }
    }

    // ================================================================ uptime
    Component {
        id: uptimeC
        Item {
            Component.onCompleted: Info.users++
            Component.onDestruction: Info.users--
            Text { width: parent.width; text: Info.dur(Info.sys.uptime) || "…"; color: w.fg; font.bold: true; font.pixelSize: w.u * 0.2; font.family: Theme.font; wrapMode: Text.Wrap }
            Caption { text: "Up for" }
        }
    }

    // ================================================================ did you know?
    Component {
        id: tipC
        Item {
            readonly property var tips: [
                "Super+A opens the control panel.", "Super+R, then type =12*7 to calculate.",
                "Right-click a wallpaper to make it a favourite.", "Super+Shift+W picks a random favourite wallpaper.",
                "Type \"party\" in Super+R.", "Super+Shift+Z starts the screensaver.",
                "Bigger pixels make the animated background lighter on the GPU.", "Super+I → Widgets rearranges these tiles.",
                "Super+Esc locks the screen.", "bevelctl live list shows every animation.",
                "The first computer mouse was made of wood.", "Windows 95 needed only 4 MB of RAM.",
                "The first web page went online in 1991.", "Ctrl+Alt+Del was meant only for developers."
            ]
            readonly property int pick: Math.floor(Date.now() / 3600000) % tips.length
            Row {
                anchors.fill: parent
                spacing: 8
                PixIcon { kind: "bell"; zoom: 2 }
                Column {
                    width: parent.width - 40
                    BText { text: "Did you know?"; color: w.hiCol; font.bold: true }
                    BText { width: parent.width; text: parent.parent.parent.tips[parent.parent.parent.pick]; color: w.fg; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight }
                }
            }
        }
    }

    // ================================================================ app tiles
    Component {
        id: appsC
        Grid {
            id: ag
            columns: w.cw
            rows: w.ch
            spacing: 6
            readonly property real tw: (width - spacing * (columns - 1)) / columns
            readonly property real th: (height - spacing * (rows - 1)) / rows
            Repeater {
                model: (Theme.sv("widgets.apps", null) || Theme.dockPinned).slice(0, w.cw * w.ch)
                Rectangle {
                    id: at
                    required property string modelData
                    required property int index
                    readonly property var e: DesktopEntries.byId(modelData) || DesktopEntries.byId(modelData.toLowerCase()) || (DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(modelData) : null)
                    width: ag.tw; height: ag.th
                    color: atMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, w.light ? 0 : 0.06)
                    border.color: w.light ? (atMa.containsMouse ? Theme.accent : "transparent") : "transparent"
                    IconImage {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -8
                        implicitSize: Math.min(parent.width, parent.height) * 0.45
                        source: at.e ? Quickshell.iconPath(at.e.icon || "application-x-executable", "application-x-executable") : ""
                    }
                    BText {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 6
                        horizontalAlignment: Text.AlignHCenter
                        text: at.e ? at.e.name : at.modelData
                        color: w.fg
                        font.pixelSize: Math.max(9, Theme.fontSize - 3)
                    }
                    MouseArea { id: atMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (at.e) at.e.execute() }
                }
            }
        }
    }

    // ================================================================ desktop icons
    Component {
        id: iconC
        Item {
            id: ic
            readonly property var map: ({ trash: "trash", computer: "monitor", homefolder: "folder", documents: "note",
                                          downloads: "download", terminalicon: "terminal" })
            property int count: 0
            readonly property bool isTrash: w.kind === "trash"
            property bool askEmpty: false
            Process {
                id: trashProc
                command: ["bevelctl", "cp", "trash"]
                stdout: StdioCollector { onStreamFinished: { try { ic.count = JSON.parse(text).count; } catch (e) {} } }
            }
            Timer { interval: 5000; repeat: true; running: ic.isTrash; triggeredOnStart: true; onTriggered: if (!trashProc.running) trashProc.running = true }
            PixIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.max(0, (parent.height - height - label.height - 4) / 2)
                kind: ic.isTrash && ic.count > 0 ? "trash-full" : (ic.map[w.kind] || "folder")
                tint: w.light ? "transparent" : "#ffffff"
                zoom: Math.max(1, Math.floor(Math.min(parent.width, parent.height - 24) / 16))
                width: 16 * zoom; height: 16 * zoom
            }
            BText {
                id: label
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: w.meta.name + (ic.isTrash && ic.count > 0 && w.cw > 1 ? " (" + ic.count + ")" : "")
                color: w.fg
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                enabled: ic.isTrash
                onClicked: ic.askEmpty = ic.count > 0
            }
            Rectangle {
                visible: ic.askEmpty
                anchors.fill: parent
                anchors.margins: -4
                color: Theme.face
                border.color: Theme.dark
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    BText { anchors.horizontalCenter: parent.horizontalCenter; text: "Empty " + ic.count + " item" + (ic.count === 1 ? "" : "s") + "?"; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        SButton { implicitWidth: 40; text: "Yes"; onClicked: { ic.askEmpty = false; trashProc.command = ["bevelctl", "cp", "trash", "empty"]; trashProc.running = true; } }
                        SButton { implicitWidth: 40; text: "No"; onClicked: ic.askEmpty = false }
                    }
                }
            }
        }
    }

    // ================================================================ world clock
    Component {
        id: worldC
        Item {
            id: wc
            readonly property var cities: {
                const l = Theme.sv("widgets.worldClocks", null) || ["London|Europe/London", "New York|America/New_York", "Tokyo|Asia/Tokyo"];
                return l.map(s => { const p = String(s).split("|"); return { name: p[0], zone: (p[1] || p[0]).trim() }; });
            }
            property var offsets: ({})
            Process {
                id: tzProc
                command: ["bevelctl", "cp", "tz"].concat(wc.cities.map(c => c.zone))
                stdout: StdioCollector { onStreamFinished: { try { wc.offsets = JSON.parse(text); } catch (e) {} } }
            }
            onCitiesChanged: retz.restart()
            Component.onCompleted: retz.restart()
            Timer { id: retz; interval: 300; onTriggered: if (!tzProc.running) tzProc.running = true }
            Timer { interval: 3600000; repeat: true; running: true; onTriggered: tzProc.running = true }
            readonly property int rowsShown: Math.max(1, Math.min(cities.length, Math.floor(height / 30)))
            Column {
                anchors.fill: parent
                spacing: 0
                Repeater {
                    model: wc.cities.slice(0, wc.rowsShown)
                    Item {
                        required property var modelData
                        width: parent.width
                        height: wc.height / wc.rowsShown
                        readonly property var off: wc.offsets[modelData.zone]
                        readonly property date t: off === undefined || off === null ? w.now
                            : new Date(w.now.getTime() + (off + w.now.getTimezoneOffset()) * 60000)
                        readonly property int dayDiff: Math.round((new Date(t.getFullYear(), t.getMonth(), t.getDate()) - new Date(w.now.getFullYear(), w.now.getMonth(), w.now.getDate())) / 86400000)
                        BText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * 0.5
                            text: modelData.name + (parent.dayDiff > 0 ? "  +1" : (parent.dayDiff < 0 ? "  −1" : ""))
                            color: w.dim
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.formatTime(parent.t, Theme.clockFormat === "HH:mm" ? "HH:mm" : "h:mm AP")
                            color: (parent.t.getHours() >= 7 && parent.t.getHours() < 21) ? w.fg : w.dim
                            font.family: Theme.font
                            font.bold: true
                            font.pixelSize: Math.min(parent.height * 0.62, w.u * 0.26)
                        }
                    }
                }
            }
        }
    }

    // ================================================================ news ticker
    Component {
        id: rssC
        Item {
            id: rs
            readonly property string url: Theme.sv("widgets.rssUrl", "") || "https://archlinux.org/feeds/news/"
            property var items: []
            property string err: ""
            readonly property bool ticker: w.ch === 1
            Process {
                id: rssProc
                command: ["bevelctl", "cp", "rss", rs.url]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            const j = JSON.parse(text);
                            if (Array.isArray(j)) { rs.items = j; rs.err = ""; } else rs.err = j.error || "no feed";
                        } catch (e) { rs.err = "no feed"; }
                    }
                }
            }
            onUrlChanged: refetch.restart()
            Component.onCompleted: refetch.restart()
            Timer { id: refetch; interval: 300; onTriggered: if (!rssProc.running) rssProc.running = true }
            Timer { interval: 1800000; repeat: true; running: true; onTriggered: rssProc.running = true }
            PixIcon { id: rsIcon; kind: "globe"; zoom: 2; anchors.verticalCenter: rs.ticker ? parent.verticalCenter : undefined; tint: "transparent" }
            // one row: a scrolling marquee
            Item {
                visible: rs.ticker
                anchors.left: rsIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                clip: true
                Text {
                    id: marquee
                    anchors.verticalCenter: parent.verticalCenter
                    text: rs.err !== "" ? "Can't load the news feed" : (rs.items.length ? rs.items.map(i => i.title).join("     ◆     ") : "Loading the news…")
                    color: w.fg
                    font.family: Theme.font
                    font.pixelSize: Math.max(13, Math.min(w.u * 0.24, 22))
                    NumberAnimation on x {
                        running: rs.ticker && marquee.width > 0 && rs.items.length > 0
                        from: marquee.parent.width
                        to: -marquee.width
                        duration: Math.max(8000, (marquee.width + marquee.parent.width) * 18)
                        loops: Animation.Infinite
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (rs.items.length) Quickshell.execDetached(["xdg-open", rs.items[0].link || rs.url])
                }
            }
            // bigger: a list of headlines
            Column {
                visible: !rs.ticker
                anchors.top: rsIcon.bottom
                anchors.topMargin: 6
                width: parent.width
                spacing: 4
                BText { visible: rs.err !== ""; text: "Can't load the news feed"; color: w.dim }
                Repeater {
                    model: rs.ticker ? [] : rs.items.slice(0, Math.max(1, Math.floor((rs.height - 40) / (Theme.fontSize + 10))))
                    BText {
                        required property var modelData
                        width: parent.width
                        text: "◆ " + modelData.title
                        color: titleMa.containsMouse ? w.hiCol : w.fg
                        MouseArea { id: titleMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["xdg-open", parent.modelData.link]) }
                    }
                }
            }
            BText {
                visible: !rs.ticker
                anchors.left: rsIcon.right
                anchors.leftMargin: 8
                anchors.verticalCenter: rsIcon.verticalCenter
                text: "News"
                font.bold: true
                color: w.hiCol
            }
        }
    }

    // ================================================================ music visualizer (cava)
    Component {
        id: visC
        Item {
            id: vz
            readonly property int bars: Math.max(8, Math.min(48, w.cw * 10))
            property var levels: []
            property bool missing: false
            readonly property bool playing: {
                const l = Mpris.players.values;
                for (let i = 0; i < l.length; i++) if (l[i].isPlaying) return true;
                return false;
            }
            Process {
                id: cavaProc
                command: ["bevelctl", "cp", "cava", String(vz.bars)]
                running: vz.playing && w.visible
                stdout: SplitParser {
                    onRead: data => {
                        const v = data.split(";").filter(x => x !== "").map(Number);
                        if (v.length) vz.levels = v;
                    }
                }
                onExited: code => { if (code !== 0 && vz.playing) vz.missing = true; vz.levels = []; }
            }
            Row {
                anchors.fill: parent
                anchors.bottomMargin: 2
                spacing: 2
                visible: !vz.missing
                Repeater {
                    model: vz.bars
                    Item {
                        required property int index
                        width: (vz.width - (vz.bars - 1) * 2) / vz.bars
                        height: parent.height
                        readonly property real lv: vz.levels.length > index ? vz.levels[index] / 100 : 0.03
                        Column {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            spacing: 2
                            readonly property int segs: Math.max(1, Math.round(parent.lv * Math.floor(parent.height / 6)))
                            Repeater {
                                model: parent.segs
                                Rectangle {
                                    required property int index
                                    width: parent.width
                                    height: 4
                                    color: index < 2 && parent.segs > 6 ? (w.light ? Theme.accent2 : "#ffffff") : (w.light ? Theme.accent : Qt.rgba(1, 1, 1, 0.8))
                                }
                            }
                        }
                    }
                }
            }
            BText {
                anchors.centerIn: parent
                visible: vz.missing || !vz.playing
                text: vz.missing ? "Install cava for the visualizer" : "♪ Play some music"
                color: w.dim
            }
        }
    }

    // ================================================================ pomodoro
    Component {
        id: pomoC
        Item {
            id: po
            readonly property int focusMin: Theme.sv("widgets.pomodoroFocus", 25)
            readonly property int breakMin: Theme.sv("widgets.pomodoroBreak", 5)
            property string phase: "focus"       // focus | break
            property int remain: focusMin * 60
            property bool runningNow: false
            property int done: 0
            onFocusMinChanged: if (!runningNow && phase === "focus") remain = focusMin * 60
            Timer {
                interval: 1000; repeat: true; running: po.runningNow
                onTriggered: {
                    po.remain--;
                    if (po.remain <= 0) {
                        if (po.phase === "focus") {
                            po.done++;
                            po.phase = "break"; po.remain = po.breakMin * 60;
                            Quickshell.execDetached(["notify-send", "-a", "Pomodoro", "Time for a break", "Nice work! Take " + po.breakMin + " minutes."]);
                        } else {
                            po.phase = "focus"; po.remain = po.focusMin * 60;
                            Quickshell.execDetached(["notify-send", "-a", "Pomodoro", "Back to work", po.focusMin + " minutes of focus."]);
                        }
                    }
                }
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -6
                spacing: 10
                PixIcon { visible: w.cw >= 2; kind: "tomato"; zoom: 3; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: Math.floor(po.remain / 60) + ":" + String(po.remain % 60).padStart(2, "0")
                        color: w.fg
                        font.family: Theme.font
                        font.bold: true
                        font.pixelSize: w.u * (w.cw >= 2 ? 0.34 : 0.3)
                    }
                    BText {
                        text: (po.phase === "focus" ? "Focus" : "Break") + (po.runningNow ? "" : " · paused") + (po.done ? "  ·  " + "●".repeat(Math.min(po.done, 8)) : "")
                        color: w.dim
                        font.pixelSize: Math.max(10, Theme.fontSize - 2)
                    }
                }
            }
            Caption { text: po.runningNow ? "click: pause" : "click: start · right: reset" }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) { po.runningNow = false; po.phase = "focus"; po.remain = po.focusMin * 60; po.done = 0; }
                    else po.runningNow = !po.runningNow;
                }
            }
        }
    }

    // ================================================================ minesweeper
    Component {
        id: minesC
        Item {
            id: ms
            readonly property int cols: w.cw >= 4 ? 16 : (w.cw >= 3 ? 12 : 9)
            readonly property int rows: w.ch >= 3 ? (w.cw >= 4 ? 12 : 12) : 9
            readonly property int mines: cols === 16 ? 30 : (cols === 12 ? 22 : 10)
            property var board: []      // {mine, n, open, flag}
            property string game: "new"   // new | play | won | lost
            property int flags: 0
            property int secs: 0
            readonly property real cs: Math.floor(Math.min(width / cols, (height - 34) / rows))
            Timer { interval: 1000; repeat: true; running: ms.game === "play"; onTriggered: ms.secs++ }
            function reset() {
                const b = [];
                for (let i = 0; i < cols * rows; i++) b.push({ mine: false, n: 0, open: false, flag: false });
                board = b; game = "new"; flags = 0; secs = 0;
            }
            function nb(i) {
                const r = Math.floor(i / cols), c = i % cols, out = [];
                for (let dr = -1; dr <= 1; dr++) for (let dc = -1; dc <= 1; dc++) {
                    if (!dr && !dc) continue;
                    const rr = r + dr, cc = c + dc;
                    if (rr >= 0 && rr < rows && cc >= 0 && cc < cols) out.push(rr * cols + cc);
                }
                return out;
            }
            function place(safe) {
                const b = board.map(x => Object.assign({}, x));
                const avoid = [safe].concat(nb(safe));
                let n = 0;
                while (n < mines) {
                    const i = Math.floor(Math.random() * cols * rows);
                    if (b[i].mine || avoid.indexOf(i) >= 0) continue;
                    b[i].mine = true; n++;
                }
                for (let i = 0; i < b.length; i++) b[i].n = nb(i).filter(j => b[j].mine).length;
                board = b;
            }
            function open(i) {
                if (game === "won" || game === "lost") return;
                if (game === "new") { place(i); game = "play"; }
                const b = board.map(x => Object.assign({}, x));
                if (b[i].flag || b[i].open) return;
                if (b[i].mine) {
                    for (const x of b) if (x.mine) x.open = true;
                    b[i].boom = true;
                    board = b; game = "lost"; return;
                }
                const stack = [i];
                while (stack.length) {
                    const k = stack.pop();
                    if (b[k].open || b[k].flag) continue;
                    b[k].open = true;
                    if (b[k].n === 0) for (const j of nb(k)) if (!b[j].open) stack.push(j);
                }
                board = b;
                if (b.filter(x => !x.open).length === mines) { game = "won"; flags = mines; }
            }
            function flag(i) {
                if (game === "won" || game === "lost" || board[i].open) return;
                const b = board.slice(); b[i] = Object.assign({}, b[i], { flag: !b[i].flag });
                board = b; flags += b[i].flag ? 1 : -1;
            }
            Component.onCompleted: reset()
            onColsChanged: reset()
            onRowsChanged: reset()
            readonly property var numColors: ["", "#0000ff", "#008000", "#ff0000", "#000080", "#800000", "#008080", "#000000", "#808080"]

            Column {
                anchors.centerIn: parent
                spacing: 4
                // counter · face · timer
                Item {
                    width: ms.cs * ms.cols
                    height: 28
                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        width: 46; height: 24; color: "#000000"
                        Text { anchors.centerIn: parent; text: String(Math.max(0, ms.mines - ms.flags)).padStart(3, "0"); color: "#ff2020"; font.family: Theme.mono; font.pixelSize: 22 }
                    }
                    Bevel {
                        anchors.centerIn: parent
                        width: 26; height: 26
                        fill: "#c0c0c0"
                        sunken: faceMa.pressed
                        Text {
                            anchors.centerIn: parent
                            text: ms.game === "lost" ? "x_x" : (ms.game === "won" ? "B)" : ":)")
                            font.family: Theme.mono; font.pixelSize: 14; font.bold: true; color: "#000000"
                        }
                        MouseArea { id: faceMa; anchors.fill: parent; onClicked: ms.reset() }
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: 46; height: 24; color: "#000000"
                        Text { anchors.centerIn: parent; text: String(Math.min(999, ms.secs)).padStart(3, "0"); color: "#ff2020"; font.family: Theme.mono; font.pixelSize: 22 }
                    }
                }
                Grid {
                    columns: ms.cols
                    Repeater {
                        model: ms.board.length
                        Item {
                            id: cellI
                            required property int index
                            readonly property var c: ms.board[index] || {}
                            width: ms.cs; height: ms.cs
                            Rectangle { anchors.fill: parent; visible: !!cellI.c.open; color: cellI.c.boom ? "#ff0000" : "#c0c0c0"; border.color: "#808080"; border.width: 1 }
                            Bevel { anchors.fill: parent; visible: !cellI.c.open; fill: "#c0c0c0"; depth: 2; radius: 0 }
                            Text {
                                anchors.centerIn: parent
                                visible: !!cellI.c.open && !cellI.c.mine && cellI.c.n > 0
                                text: cellI.c.n || ""
                                color: ms.numColors[cellI.c.n || 0]
                                font.family: Theme.font; font.bold: true; font.pixelSize: ms.cs * 0.7
                            }
                            PixIcon { anchors.centerIn: parent; visible: !!cellI.c.open && !!cellI.c.mine; kind: "mine"; width: ms.cs - 4; height: ms.cs - 4 }
                            PixIcon { anchors.centerIn: parent; visible: !cellI.c.open && !!cellI.c.flag; kind: "flag"; width: ms.cs - 4; height: ms.cs - 4 }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => mouse.button === Qt.RightButton ? ms.flag(cellI.index) : ms.open(cellI.index)
                            }
                        }
                    }
                }
            }
        }
    }

}
