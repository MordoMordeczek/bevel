pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Everything visual reads from here. Settings come from ~/.config/bevel/settings.json
// (written by bevelctl), colors from ~/.config/bevel/generated/colors.json.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cfgDir: home + "/.config/bevel"

    property var s: ({})
    property var c: ({})

    function g(obj, path, def) {
        let n = obj;
        const parts = path.split(".");
        for (let i = 0; i < parts.length; i++) {
            if (n === undefined || n === null)
                return def;
            n = n[parts[i]];
        }
        return (n === undefined || n === null) ? def : n;
    }
    function sv(path, def) { return g(root.s, path, def); }

    // ---- colors
    readonly property color face: g(c, "face", "#c0c0c0")
    readonly property color face2: g(c, "face2", "#dfdfdf")
    readonly property color hi: g(c, "hi", "#ffffff")
    readonly property color lo: g(c, "lo", "#808080")
    readonly property color dark: g(c, "dark", "#0a0a0a")
    readonly property color base: g(c, "base", "#ffffff")
    readonly property color text: g(c, "text", "#000000")
    readonly property color textDim: g(c, "textDim", "#404040")
    readonly property color accent: g(c, "accent", "#000080")
    readonly property color accent2: g(c, "accent2", "#1084d0")
    readonly property color accentText: g(c, "onAccent", "#ffffff")
    readonly property color termBg: g(c, "termBg", "#000000")
    readonly property color lcdBg: g(c, "lcdBg", "#0b1420")
    readonly property color lcd: g(c, "lcd", "#8fd0ff")
    readonly property string wallpaper: g(c, "wallpaper", "")

    // ---- style
    readonly property int radius: sv("style.rounding", 0)
    readonly property int radiusSm: Math.floor(radius / 2)
    readonly property int bevel: sv("style.bevel", 2)
    readonly property real panelOpacity: sv("style.opacity", 0.96)
    readonly property string font: sv("style.font", "Pixelify Sans")
    readonly property string mono: sv("style.monoFont", "VT323")
    readonly property int fontSize: sv("style.fontSize", 14)
    readonly property bool dither: sv("style.dither", false)
    readonly property bool lcdClock: sv("style.lcdClock", false)

    // ---- desktop layout (Hyprland): bevel | taskbar | island | dock
    readonly property string barLayout: {
        const l = sv("bar.layout", "bevel");
        return ["bevel", "taskbar", "island", "dock"].indexOf(l) >= 0 ? l : "bevel";
    }
    readonly property string launcherStyle: {
        const l = sv("launcher.style", "run");
        return ["run", "grid", "start"].indexOf(l) >= 0 ? l : "run";
    }
    readonly property var dockPinned: sv("dock.pinned", ["kitty", "org.kde.dolphin", "firefox", "code-oss"])
    // the dock (Settings → Desktop style → Dock)
    readonly property int dockSize: Math.max(24, Math.min(72, sv("dock.size", 36)))          // icon size
    readonly property string dockPos: ["bottom", "left", "right"].indexOf(sv("dock.position", "bottom")) >= 0 ? sv("dock.position", "bottom") : "bottom"
    readonly property string dockStyle: sv("dock.style", "panel")       // panel · glass · flat · accent · none
    readonly property bool dockButtons: sv("dock.buttons", true)       // each icon on its own raised button
    readonly property bool dockGrow: sv("dock.grow", true)
    readonly property bool dockRunning: sv("dock.running", true)       // running apps that aren't pinned
    readonly property bool dockAutohide: sv("dock.autohide", false)
    readonly property int dockThickness: dockSize + 22                  // how much screen edge it takes
    function dockPin(id) { const l = dockPinned.slice(); if (l.indexOf(id) < 0) l.push(id); setUi("dock.pinned", l); }
    function dockUnpin(id) { setUi("dock.pinned", dockPinned.filter(x => x !== id)); }
    function dockMove(id, d) {
        const l = dockPinned.slice(), i = l.indexOf(id), j = i + d;
        if (i < 0 || j < 0 || j >= l.length) return;
        l.splice(i, 1); l.splice(j, 0, id);
        setUi("dock.pinned", l);
    }

    // ---- fun
    readonly property bool btw: sv("fun.btw", false)
    readonly property string btwLabel: (sv("fun.btwText", "") || "").trim() !== "" ? sv("fun.btwText", "") : "I use " + distro + " btw"
    readonly property bool tips: sv("fun.tips", true)
    readonly property string saver: sv("fun.screensaver", "starfield")
    readonly property int saverMinutes: sv("fun.saverMinutes", 10)
    readonly property bool loadingScreen: sv("style.loadingScreen", true)
    // your distro: bevelctl puts it in colors.json (with the Settings → Fun overrides and the logo);
    // /etc/os-release is the fallback until it has
    property string osName: "Linux"
    property string osId: "linux"
    readonly property var distroInfo: c && c.distro ? c.distro : ({})
    readonly property string distro: distroInfo.name || osName
    readonly property string distroId: distroInfo.id || osId
    // arch (Bevel's pixel Arch) · system (your distro's logo as pixel art) · generic (a 9x computer) · none
    readonly property string distroLogo: distroInfo.logo || (osId === "arch" ? "arch" : "generic")
    readonly property string distroLogoPng: distroInfo.logoPng ? "file://" + distroInfo.logoPng + "?" + (distroInfo.logoStamp || 0) : ""
    FileView {
        id: osRelease
        path: "/etc/os-release"
        blockLoading: true
        printErrors: false
        onLoaded: root.parseDistro()
    }
    function parseDistro() {
        const t = osRelease.text() || "";
        const m = t.match(/^NAME=["']?([^"'\n]+)["']?/m);
        if (m) root.osName = m[1].replace(/\s+(GNU\/)?Linux$/, "").trim() || "Linux";
        const i = t.match(/^ID=["']?([^"'\n]+)["']?/m);
        if (i) root.osId = i[1].toLowerCase();
    }

    // ---- wallpaper: a picture, or a live (animated) background
    readonly property bool liveMode: sv("wallpaper.mode", "image") === "live"
    readonly property string liveKind: {
        const k = sv("wallpaper.live.kind", "synthwave");
        return liveKinds.some(x => x.id === k) ? k : "synthwave";
    }
    readonly property string liveColor: sv("wallpaper.live.color", "#2a5ea8")
    readonly property string livePalette: sv("wallpaper.live.palette", "night")
    readonly property real liveSpeed: sv("wallpaper.live.speed", 1.0)
    readonly property int livePixel: Math.max(1, sv("wallpaper.live.pixel", 3))
    readonly property bool liveDither: sv("wallpaper.live.dither", false)
    readonly property int liveFps: Math.max(5, Math.min(60, sv("wallpaper.live.fps", 30)))
    readonly property var liveCols: liveColors(liveColor, livePalette)
    // shaders load from a plain file:// path (some Quickshell URL schemes can't be read by ShaderEffect)
    readonly property string liveDir: {
        let r = "";
        try { r = String(Quickshell.shellDir || ""); } catch (e) {}
        if (r === "" || r === "undefined") { try { r = String(Quickshell.shellRoot || ""); } catch (e) {} }
        if (r === "" || r === "undefined") r = root.home + "/.config/quickshell/bevel";
        if (!r.startsWith("file:")) r = "file://" + r;
        return r.replace(/\/$/, "") + "/live/";
    }
    // ---- effects over a picture wallpaper: snow, stars, rain… (Settings → Wallpaper → Effect)
    readonly property var fxKinds: [
        { id: "none", name: "None", about: "Just the picture" },
        { id: "snow", name: "Snow", about: "Flakes drifting down" },
        { id: "stars", name: "Stars", about: "Twinkling, and a shooting star now and then" },
        { id: "rain", name: "Rain", about: "A steady shower" },
        { id: "fireflies", name: "Fireflies", about: "Little lights wandering about" },
        { id: "leaves", name: "Autumn leaves", about: "Orange and red, tumbling" },
        { id: "petals", name: "Blossom", about: "Pink petals on the breeze" },
        { id: "bubbles", name: "Bubbles", about: "Rising slowly" },
        { id: "embers", name: "Embers", about: "Sparks floating up" },
        { id: "confetti", name: "Confetti", about: "Party time" }
    ]
    readonly property string fxKind: {
        if (liveMode) return "none";
        const k = sv("wallpaper.effect.kind", "none");
        return fxKinds.some(x => x.id === k) ? k : "none";
    }
    readonly property bool fxOn: fxKind !== "none"
    readonly property real fxDensity: Math.max(0.2, Math.min(2.5, sv("wallpaper.effect.density", 1.0)))
    readonly property real fxSpeed: sv("wallpaper.effect.speed", 1.0)
    readonly property int fxPixel: Math.max(1, sv("wallpaper.effect.pixel", 2))
    readonly property string fxColorMode: sv("wallpaper.effect.color", "white")      // white · accent · #hex
    readonly property color fxColor: fxColorMode === "accent" ? accent : (fxColorMode === "white" ? "#ffffff" : fxColorMode)

    // still frame for the login screen, lock screen and Firefox (made by LiveStill)
    readonly property string liveStill: home + "/.cache/bevel/live/" + liveKind + "-" + liveColor.replace("#", "") + "-" + livePalette + "-" + livePixel + (liveDither ? "d" : "") + ".png"
    readonly property var liveKinds: [
        { id: "synthwave", name: "Synthwave", about: "A striped sun over a neon grid" },
        { id: "hills", name: "Pixel hills", about: "Scrolling hills under a big sun" },
        { id: "ocean", name: "Sunset sea", about: "The sun setting over shimmering water" },
        { id: "starfield", name: "Starfield", about: "Flying through the stars" },
        { id: "hyperspace", name: "Hyperspace", about: "Jump to lightspeed" },
        { id: "galaxy", name: "Galaxy", about: "A spiral galaxy turning slowly" },
        { id: "aurora", name: "Aurora", about: "Northern lights over a night sky" },
        { id: "clouds", name: "Clouds", about: "A sky with drifting clouds" },
        { id: "snow", name: "Snowfall", about: "Snow settling on the ground" },
        { id: "rain", name: "Rain", about: "Rain, with the odd flash of lightning" },
        { id: "fireflies", name: "Fireflies", about: "Glowing dots over summer grass" },
        { id: "fire", name: "Fire", about: "A crackling fire along the bottom" },
        { id: "waves", name: "Waves", about: "Layered waves rolling by" },
        { id: "lavalamp", name: "Lava lamp", about: "Blobs that merge and split" },
        { id: "bubbles", name: "Bubbles", about: "Bubbles rising to the surface" },
        { id: "plasma", name: "Plasma", about: "The demo-scene classic" },
        { id: "kaleido", name: "Kaleidoscope", about: "Six mirrored slices of colour" },
        { id: "vortex", name: "Vortex", about: "A hypnotic spiral" },
        { id: "tunnel", name: "Tunnel", about: "Down an endless checkered tunnel" },
        { id: "sunburst", name: "Sunburst", about: "Turning rays, game-show style" },
        { id: "checker", name: "Checkerboard", about: "A floor that wobbles and rolls" },
        { id: "truchet", name: "Maze tiles", about: "An endless scrolling maze" },
        { id: "pattern", name: "Desktop patterns", about: "Classic 90s tile patterns, sliding by" },
        { id: "halftone", name: "Halftone", about: "Pulsing newspaper dots" },
        { id: "matrix", name: "Code rain", about: "Falling green-screen glyphs" },
        { id: "equalizer", name: "Equalizer", about: "A hi-fi spectrum analyser" },
        { id: "radar", name: "Radar", about: "A sweeping radar screen" },
        { id: "bounce", name: "Bouncing logo", about: "Will it hit the corner?" }
    ]
    readonly property var livePalettes: [
        { id: "night", name: "Night" }, { id: "dusk", name: "Dusk" }, { id: "neon", name: "Neon" },
        { id: "pastel", name: "Pastel" }, { id: "day", name: "Day" }, { id: "mono", name: "Black & white" }
    ]
    // four shader colours from one colour: c1 main, c2 light, c3 background, c4 highlight
    function liveColors(seed, palette) {
        const c = Qt.color(seed || "#2a5ea8");
        let h = c.hslHue < 0 ? 0.6 : c.hslHue;
        const s = c.hslHue < 0 ? 0 : Math.max(0.35, c.hslSaturation);
        const H = x => ((x % 1) + 1) % 1;
        const L = (hh, ss, ll) => Qt.hsla(H(hh), Math.max(0, Math.min(1, ss)), ll, 1);
        switch (palette) {
        case "dusk": return [L(h, s * 0.8, 0.45), L(h + 0.09, 0.85, 0.63), L(h - 0.08, 0.45, 0.11), L(h + 0.14, 0.9, 0.86)];
        case "neon": return [L(h, 1, 0.5), L(h + 0.5, 1, 0.6), L(h, 0.5, 0.035), L(h + 0.15, 0.9, 0.82)];
        case "pastel": return [L(h, 0.45, 0.62), L(h + 0.12, 0.5, 0.79), L(h, 0.25, 0.22), L(h, 0.45, 0.95)];
        case "day": return [L(h, s, 0.46), L(h, s, 0.66), L(h, 0.45, 0.86), L(h, 0.3, 0.98)];
        case "mono": return [L(h, 0, 0.42), L(h, 0, 0.7), L(h, 0, 0.06), L(h, 0, 0.95)];
        default: return [L(h, s, 0.42), L(h, s, 0.68), L(h, s * 0.35, 0.07), L(h, 0.3, 0.93)];
        }
    }

    // ---- desktop widgets (Hyprland): Metro-style tiles that line up by themselves
    readonly property bool widgetsOn: sv("widgets.enabled", true)
    readonly property var widgetKinds: [
        { id: "clock", name: "Clock", about: "Big time and date (2×2 = analog)", sizes: ["1x1", "2x1", "2x2"] },
        { id: "calendar", name: "Calendar", about: "This month", sizes: ["2x2", "3x2"] },
        { id: "fetch", name: "System info", about: "fastfetch on your desktop", sizes: ["2x1", "3x1", "2x2", "3x2", "4x2", "3x3"] },
        { id: "btw", name: "I use … btw", about: "Let everyone know", sizes: ["1x1", "2x1"] },
        { id: "ascii", name: "ASCII text", about: "Your own text in big block letters", sizes: ["2x1", "3x1", "4x1", "4x2"] },
        { id: "cpu", name: "CPU", about: "Usage with a history graph", sizes: ["1x1", "2x1"] },
        { id: "ram", name: "Memory", about: "RAM (and swap) in use", sizes: ["1x1", "2x1"] },
        { id: "disk", name: "Disk", about: "Space used in your home folder", sizes: ["1x1", "2x1"] },
        { id: "battery", name: "Battery", about: "Charge and time left", sizes: ["1x1", "2x1"] },
        { id: "network", name: "Network", about: "Connection and live speed", sizes: ["2x1"] },
        { id: "media", name: "Now playing", about: "Song, artist and controls", sizes: ["2x1", "2x2"] },
        { id: "weather", name: "Weather", about: "From wttr.in (set a city below)", sizes: ["1x1", "2x1"] },
        { id: "notes", name: "Sticky note", about: "Type anything; it's saved", sizes: ["2x2", "2x1", "3x2"] },
        { id: "uptime", name: "Uptime", about: "How long since you booted", sizes: ["1x1"] },
        { id: "tip", name: "Did you know?", about: "A new tip every hour", sizes: ["2x1", "3x1"] },
        { id: "apps", name: "App tiles", about: "Your pinned apps as tiles", sizes: ["2x1", "4x1", "2x2", "4x2"] },
        { id: "worldclock", name: "World clock", about: "The time in other cities", sizes: ["2x1", "2x2", "3x1"] },
        { id: "rss", name: "News ticker", about: "Headlines from a feed (Arch news by default)", sizes: ["4x1", "3x1", "2x2", "3x2"] },
        { id: "visualizer", name: "Visualizer", about: "Bars that dance to your music (needs cava)", sizes: ["2x1", "3x1", "4x1", "2x2"] },
        { id: "pomodoro", name: "Pomodoro timer", about: "25 minutes of focus, then a break", sizes: ["1x1", "2x1"] },
        { id: "minesweeper", name: "Minesweeper", about: "The real game. Right-click flags a mine", sizes: ["2x2", "3x3", "4x3"] },
        { id: "trash", name: "Recycle Bin", about: "Your trash. Right-click to empty it", sizes: ["1x1"], icon: true },
        { id: "computer", name: "My Computer", about: "Opens your files", sizes: ["1x1"], icon: true },
        { id: "homefolder", name: "Home folder", about: "Your home folder", sizes: ["1x1"], icon: true },
        { id: "documents", name: "My Documents", about: "~/Documents", sizes: ["1x1"], icon: true },
        { id: "downloads", name: "Downloads", about: "~/Downloads", sizes: ["1x1"], icon: true },
        { id: "terminalicon", name: "Terminal", about: "Opens kitty", sizes: ["1x1"], icon: true }
    ]
    readonly property var widgetList: {
        const l = sv("widgets.list", null);
        if (Array.isArray(l)) return l;
        return [{ id: "clock", size: "2x1" }, { id: "calendar", size: "2x2" }, { id: "fetch", size: "3x2" },
                { id: "cpu", size: "2x1" }, { id: "ram", size: "1x1" }, { id: "disk", size: "1x1" }, { id: "btw", size: "2x1" }];
    }

    // ---- "please wait" while colours change (wallpaper, accent…). Changes are quick now, so it only
    // appears if one takes longer than a moment, and goes as soon as it's done.
    property bool busy: false
    property bool pendingBusy: false
    property bool busyWanted: false
    function startBusy() {
        root.busyWanted = true;
        busyEnd.stop();
        if (!root.busy) busyShow.restart();
        busyTimeout.restart();
    }
    function endBusy() {
        root.busyWanted = false;
        busyShow.stop();
        if (root.busy) busyEnd.restart();
    }
    Timer { id: busyShow; interval: 700; onTriggered: if (root.busyWanted) root.busy = true }
    Timer { id: busyEnd; interval: 250; onTriggered: root.busy = false }
    Timer { id: busyTimeout; interval: 15000; onTriggered: { root.busyWanted = false; root.busy = false; } }

    // ---- bar
    readonly property bool barTop: barLayout === "taskbar" ? false : (barLayout === "dock" ? true : sv("bar.position", "top") !== "bottom")
    readonly property int barHeight: sv("bar.height", 30)
    readonly property string barFont: sv("bar.font", "JetBrains Mono")
    readonly property int barFontSize: sv("bar.fontSize", 13)
    readonly property bool barBold: sv("bar.bold", true)
    readonly property bool barFloating: sv("bar.floating", true)
    readonly property int workspaces: sv("bar.workspaces", 5)
    readonly property bool minimaps: sv("bar.minimaps", true)
    readonly property bool windowTitle: sv("bar.windowTitle", true)
    readonly property bool showCpu: sv("bar.cpu", true)
    readonly property bool showNetwork: sv("bar.network", true)
    readonly property bool showVolume: sv("bar.volume", true)
    readonly property bool showBattery: sv("bar.battery", true)
    readonly property bool clockSeconds: sv("bar.clockSeconds", false)
    readonly property string clockFormat: sv("bar.clockFormat", "HH:mm")
    readonly property bool showDate: sv("bar.showDate", false)

    readonly property int gapsOut: sv("windows.gapsOut", 8)
    readonly property string layoutName: sv("windows.layout", "dwindle")

    // ---- what's on the bar, and where (Settings → Bar → Items). Saved per layout:
    // bar.items.<layout> = { left: [...], center: [...], right: [...] }
    readonly property var barModuleInfo: [
        { id: "start", name: "Start button" }, { id: "workspaces", name: "Workspaces" }, { id: "title", name: "Window title" },
        { id: "tasks", name: "Window buttons" }, { id: "media", name: "Now playing" }, { id: "tray", name: "Tray icons" },
        { id: "btw", name: "btw badge" }, { id: "cpu", name: "CPU" }, { id: "memory", name: "Memory" }, { id: "network", name: "Network" },
        { id: "volume", name: "Volume" }, { id: "battery", name: "Battery" }, { id: "notifs", name: "Notifications" },
        { id: "control", name: "Control panel" }, { id: "clock", name: "Clock" }, { id: "sep", name: "Separator", many: true },
        { id: "space", name: "Gap", many: true }
    ]
    function barDefaults(layout) {
        let d;
        if (layout === "taskbar") d = { left: ["start", "sep", "tasks"], center: [], right: ["tray", "btw", "cpu", "network", "volume", "battery", "control", "clock"] };
        else if (layout === "island") d = { left: ["workspaces", "title"], center: ["clock"], right: ["btw", "cpu", "network", "volume", "battery", "control"] };
        else d = { left: ["workspaces", "sep", "title"], center: [], right: ["btw", "cpu", "network", "volume", "battery", "control", "sep", "clock"] };
        // the older on/off switches still count
        const off = [];
        if (!sv("bar.windowTitle", true)) off.push("title");
        if (!sv("bar.cpu", true)) off.push("cpu");
        if (!sv("bar.network", true)) off.push("network");
        if (!sv("bar.volume", true)) off.push("volume");
        if (!sv("bar.battery", true)) off.push("battery");
        if (!sv("bar.controlButton", false)) off.push("control");
        const f = l => l.filter(x => off.indexOf(x) < 0);
        return { left: f(d.left), center: f(d.center), right: f(d.right) };
    }
    function barItemsFor(layout) {
        const all = sv("bar.items", null);
        const mine = all ? all[layout === "dock" ? "bevel" : layout] : null;
        if (mine && (mine.left || mine.center || mine.right))
            return { left: mine.left || [], center: mine.center || [], right: mine.right || [] };
        return barDefaults(layout);
    }
    readonly property var barItems: barItemsFor(barLayout)
    function setBarItems(v) { setUi("bar.items." + (barLayout === "dock" ? "bevel" : barLayout), v); }
    readonly property int notifTimeout: sv("notifications.timeout", 5000)
    readonly property int osdTimeout: sv("osd.timeout", 1400)

    // ---- loading
    // settings.json is only ever WRITTEN by bevelctl (`bevelctl patch`, under a lock). The shell and
    // the settings window send just the keys they change, and show them right away by laying the
    // not-yet-saved changes over what the file says. Nothing can overwrite someone else's change.
    FileView {
        id: settingsFile
        path: root.cfgDir + "/settings.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: { reload(); root.parseSettings(); }
    }
    FileView {
        id: colorsFile
        path: root.cfgDir + "/generated/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: { reload(); root.parseColors(); }
    }
    // bevelctl pings this after every change, so we never depend on file watching alone
    IpcHandler {
        target: "theme"
        function busy(): void { root.startBusy(); }
        function reload(): void {
            settingsFile.reload(); colorsFile.reload();
            root.parseSettings(); root.parseColors();
            if (!patchProc.running) root.endBusy();
        }
    }

    property var fileS: ({})          // what settings.json says
    property var pending: ({})        // changed here, not sent yet   ("dotted.key": value)
    property var inflight: ({})       // sent, bevelctl is saving them
    property bool needApply: false

    // true while a slider is being dragged: preview live, save on release
    property bool holding: false
    onHoldingChanged: if (!holding) flushTimer.restart()

    function setPath(obj, key, value) {
        let n = obj;
        const parts = key.split(".");
        for (let i = 0; i < parts.length - 1; i++) {
            if (typeof n[parts[i]] !== "object" || n[parts[i]] === null || Array.isArray(n[parts[i]]))
                n[parts[i]] = {};
            n = n[parts[i]];
        }
        n[parts[parts.length - 1]] = value;
    }
    function overlay() {
        const copy = JSON.parse(JSON.stringify(root.fileS));
        for (const k in root.inflight) root.setPath(copy, k, root.inflight[k]);
        for (const k in root.pending) root.setPath(copy, k, root.pending[k]);
        root.s = copy;
    }
    function parseSettings() {
        try {
            const t = settingsFile.text();
            if (t && t.length > 2)
                root.fileS = JSON.parse(t);
        } catch (e) {
            console.warn("bevel: could not parse settings.json: " + e);
            return;
        }
        if (!patchProc.running && Object.keys(root.inflight).length > 0) root.confirm();
        else root.overlay();
    }
    function parseColors() {
        try {
            const t = colorsFile.text();
            if (t && t.length > 2)
                root.c = JSON.parse(t);
        } catch (e) {
            console.warn("bevel: could not parse colors.json: " + e);
        }
    }
    Component.onCompleted: { parseSettings(); parseColors(); parseDistro(); }

    // files may not exist yet on the very first start — keep trying until they do
    Timer {
        interval: 3000
        repeat: true
        running: Object.keys(root.c).length === 0 || Object.keys(root.fileS).length === 0
        onTriggered: {
            settingsFile.reload(); colorsFile.reload();
            root.parseSettings(); root.parseColors();
        }
    }

    // ---- writing
    function queue(key, value, apply) {
        const p = Object.assign({}, root.pending);
        p[key] = value;
        if ((key.startsWith("style.") || key.startsWith("windows.") || key === "bar.floating") && key !== "style.preset"
                && !key.startsWith("style.font") && key !== "style.monoFont")
            p["style.preset"] = "custom";
        root.pending = p;
        if (apply) root.needApply = true;
        if (apply && root.loadingScreen && (key.startsWith("colors.") || ["wallpaper.path", "wallpaper.mode", "wallpaper.live.color",
                "wallpaper.live.palette", "style.font"].indexOf(key) >= 0))
            root.pendingBusy = true;
        root.overlay();                       // UI updates right away
        if (!root.holding) flushTimer.restart();
    }
    // a change that needs the theme regenerated (colours, fonts, bar, Hyprland…)
    function set(key, value) {
        console.info("bevel: set " + key + " = " + JSON.stringify(value));
        root.queue(key, value, true);
    }
    // UI-only settings (sort order, favourites, toggles the shell reads itself): saved, nothing regenerated
    function setUi(key, value) { root.queue(key, value, false); }

    Timer { id: flushTimer; interval: 250; onTriggered: root.flush() }
    function flush() {
        if (root.holding || patchProc.running) return;            // sent when the slider/patch is done
        const keys = Object.keys(root.pending);
        if (keys.length === 0 && !root.needApply) return;
        const batch = root.pending;
        root.inflight = Object.assign({}, root.inflight, batch);
        root.pending = {};
        const apply = root.needApply;
        root.needApply = false;
        if (root.pendingBusy) root.startBusy();
        root.pendingBusy = false;
        patchProc.command = ["bevelctl", "patch", JSON.stringify(batch)].concat(apply ? ["--apply"] : []);
        patchProc.running = true;
    }
    function flushNow() { flushTimer.stop(); root.flush(); }
    // regenerate everything without changing a setting (e.g. a new still frame was saved)
    function requestApply() { root.needApply = true; flushTimer.restart(); }

    // picking a wallpaper
    function setWallpaper(path) {
        const recent = [path].concat((sv("wallpaper.recent", []) || []).filter(p => p !== path)).slice(0, 30);
        root.queue("wallpaper.recent", recent, false);
        root.queue("wallpaper.mode", "image", false);
        root.set("wallpaper.path", path);
    }

    // drop sent changes from the overlay once settings.json shows them (or after a few seconds)
    function confirm() {
        const left = {};
        for (const k in root.inflight)
            if (JSON.stringify(root.g(root.fileS, k, null)) !== JSON.stringify(root.inflight[k]))
                left[k] = root.inflight[k];
        root.inflight = left;
        root.overlay();
    }
    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: {
            settingsFile.reload();
            try { const t = settingsFile.text(); if (t && t.length > 2) root.fileS = JSON.parse(t); } catch (e) {}
            if (!patchProc.running) root.inflight = {};
            root.overlay();
        }
    }

    property double applyStarted: 0
    Process {
        id: patchProc
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("bevel: bevelctl said: " + text.trim())
        }
        onRunningChanged: {
            if (running) {
                root.applyStarted = Date.now();
                return;
            }
            // saved: read the file back (now it has our keys), drop them from the overlay
            settingsFile.reload();
            colorsFile.reload();
            try { const t = settingsFile.text(); if (t && t.length > 2) root.fileS = JSON.parse(t); } catch (e) {}
            root.confirm();
            if (Object.keys(root.inflight).length > 0) confirmTimer.restart();
            root.parseColors();
            if (Object.keys(root.pending).length > 0 || root.needApply) root.flush();
            else root.endBusy();
        }
    }

    function run(args) { root.flushNow(); Quickshell.execDetached(args); }
}
