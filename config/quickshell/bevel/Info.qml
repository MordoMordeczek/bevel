pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Readings for the desktop widgets. Polls only while something on screen uses them.
Singleton {
    id: info
    property int users: 0                 // widgets that need live numbers
    readonly property bool active: users > 0

    property var sys: ({})                // bevelctl cp sysinfo: memory, disk, uptime, temp, load
    property var fetch: ({})              // bevelctl cp fetch: os, host, cpu, gpu, packages…
    property var cpuHistory: []           // last 40 CPU readings (0–100)
    property real cpu: 0
    property real rxRate: 0               // bytes/s, all interfaces except lo
    property real txRate: 0
    property var weather: ({})

    // ---- one quick read of /proc every 2 seconds (CPU, network, memory, uptime, disk, temperature):
    // a single tiny shell instead of several programs, and no Python
    property var lastCpu: null
    property var lastNet: null
    property int tick: 0
    Process {
        id: pollProc
        command: ["sh", "-c", "head -1 /proc/stat; echo @; cat /proc/net/dev; echo @; cat /proc/meminfo; echo @; cat /proc/uptime /proc/loadavg; echo @; "
                  + "df -B1 --output=size,used \"$HOME\" 2>/dev/null | tail -1; echo @; cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: info.parse(text) }
    }
    function parse(t) {
        const part = t.split("@\n");
        info.parseCpu(part[0] || "");
        info.parseNet(part[1] || "");
        const s = Object.assign({}, info.sys);
        const mem = {};
        for (const l of (part[2] || "").split("\n")) { const m = l.match(/^(\w+):\s+(\d+)/); if (m) mem[m[1]] = Number(m[2]) * 1024; }
        if (mem.MemTotal) {
            s.memTotal = mem.MemTotal; s.memUsed = mem.MemTotal - (mem.MemAvailable || 0);
            s.swapTotal = mem.SwapTotal || 0; s.swapUsed = (mem.SwapTotal || 0) - (mem.SwapFree || 0);
        }
        const ul = (part[3] || "").split("\n");
        if (ul[0]) s.uptime = Math.floor(Number(ul[0].split(" ")[0]));
        if (ul[1]) s.load = ul[1].split(" ").slice(0, 3);
        const d = (part[4] || "").trim().split(/\s+/);
        if (d.length >= 2 && !isNaN(Number(d[0]))) { s.diskTotal = Number(d[0]); s.diskUsed = Number(d[1]); }
        const temps = (part[5] || "").split("\n").map(Number).filter(x => x > 0);
        s.temp = temps.length > 0 ? Math.round(Math.max.apply(null, temps) / 1000) : null;
        info.sys = s;
    }
    function parseCpu(t) {
        const f = t.split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        if (f.length < 5) return;
        const idle = f[3] + (f[4] || 0);
        const total = f.reduce((a, b) => a + b, 0);
        if (info.lastCpu) {
            const dt = total - info.lastCpu.total;
            if (dt > 0) info.cpu = Math.max(0, Math.min(100, (1 - (idle - info.lastCpu.idle) / dt) * 100));
            info.cpuHistory = info.cpuHistory.concat([info.cpu]).slice(-40);
        }
        info.lastCpu = { total: total, idle: idle };
    }
    function parseNet(t) {
        let rx = 0, tx = 0;
        for (const line of t.split("\n").slice(2)) {
            const p = line.trim().split(/[:\s]+/);
            if (p.length < 10 || p[0] === "lo") continue;
            rx += Number(p[1]); tx += Number(p[9]);
        }
        const now = Date.now();
        if (info.lastNet) {
            const dt = (now - info.lastNet.t) / 1000;
            if (dt > 0) {
                info.rxRate = Math.max(0, (rx - info.lastNet.rx) / dt);
                info.txRate = Math.max(0, (tx - info.lastNet.tx) / dt);
            }
        }
        info.lastNet = { rx: rx, tx: tx, t: now };
    }
    // kernel, host name, distro: they don't change, read them once
    Process {
        id: sysProc
        command: ["bevelctl", "cp", "sysinfo"]
        stdout: StdioCollector { onStreamFinished: { try { info.sys = Object.assign(JSON.parse(text), info.sys); } catch (e) {} } }
    }
    Process {
        id: fetchProc
        command: ["bevelctl", "cp", "fetch"]
        stdout: StdioCollector { onStreamFinished: { try { info.fetch = JSON.parse(text); } catch (e) {} } }
    }
    // weather from wttr.in (only when the weather widget is on)
    property string weatherCity: Theme.sv("widgets.weatherCity", "")
    property bool wantWeather: false
    Process {
        id: weatherProc
        command: ["sh", "-c", "curl -fsm 12 \"https://wttr.in/$1?format=j1\" 2>/dev/null", "sh", encodeURIComponent(info.weatherCity)]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    const c = j.current_condition[0];
                    const a = (j.nearest_area || [{}])[0];
                    info.weather = {
                        temp: c.temp_C, feels: c.FeelsLikeC, desc: (c.weatherDesc[0] || {}).value || "",
                        code: Number(c.weatherCode), humidity: c.humidity, wind: c.windspeedKmph,
                        place: info.weatherCity !== "" ? info.weatherCity : ((a.areaName || [{}])[0].value || "")
                    };
                } catch (e) { info.weather = { error: true }; }
            }
        }
    }
    onWeatherCityChanged: if (wantWeather) weatherProc.running = true
    onWantWeatherChanged: if (wantWeather) weatherProc.running = true
    Timer { interval: 1800000; repeat: true; running: info.wantWeather; onTriggered: weatherProc.running = true }

    Timer {
        interval: 2000
        repeat: true
        running: info.active
        triggeredOnStart: true
        onTriggered: if (!pollProc.running) pollProc.running = true
    }
    onActiveChanged: if (active) {
        if (Object.keys(fetch).length === 0) fetchProc.running = true;
        if (!info.sys.kernel) sysProc.running = true;
    }
    function refreshFetch() { fetchProc.running = true; }

    function bytes(b) {
        if (!b) return "0 B";
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; }
        return (b >= 100 || i === 0 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }
    function dur(sec) {
        if (!sec) return "";
        const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
        return (d > 0 ? d + "d " : "") + (h > 0 || d > 0 ? h + "h " : "") + m + "m";
    }
}
