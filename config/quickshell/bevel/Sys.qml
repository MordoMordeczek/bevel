pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick

// System readings for the bar and OSD.
Singleton {
    id: sys

    // ---- audio
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: (sink && sink.audio) ? sink.audio.volume : 0
    readonly property bool muted: (sink && sink.audio) ? sink.audio.muted : false
    PwObjectTracker { objects: [ Pipewire.defaultAudioSink ] }

    // ---- battery
    readonly property var bat: UPower.displayDevice
    readonly property bool hasBattery: bat !== null && bat !== undefined && bat.isLaptopBattery
    readonly property real battery: bat ? (bat.percentage > 1 ? bat.percentage : bat.percentage * 100) : 0
    readonly property bool charging: bat ? (bat.state === UPowerDeviceState.Charging || bat.state === UPowerDeviceState.FullyCharged) : false

    // ---- cpu
    property real cpu: 0
    property var lastCpu: null
    Process {
        id: cpuProc
        command: ["cat", "/proc/stat"]
        stdout: StdioCollector { onStreamFinished: sys.parseCpu(text) }
    }
    function parseCpu(t) {
        const f = t.split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        if (f.length < 5)
            return;
        const idle = f[3] + (f[4] || 0);
        const total = f.reduce((a, b) => a + b, 0);
        if (sys.lastCpu) {
            const dt = total - sys.lastCpu.total;
            const di = idle - sys.lastCpu.idle;
            if (dt > 0)
                sys.cpu = Math.max(0, Math.min(100, (1 - di / dt) * 100));
        }
        sys.lastCpu = { total: total, idle: idle };
    }
    // while the desktop widgets read /proc anyway, take their number instead of reading it twice
    Timer {
        interval: 2000
        running: Theme.showCpu && !Info.active
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuProc.running = true
    }
    Connections { target: Info; function onCpuChanged() { if (Info.active) sys.cpu = Info.cpu; } }

    // ---- network
    property string net: ""
    property bool netUp: false
    property bool wifi: false
    Process {
        id: netProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device"]
        stdout: StdioCollector { onStreamFinished: sys.parseNet(text) }
    }
    function parseNet(t) {
        let found = null;
        for (const line of t.split("\n")) {
            const p = line.split(":");
            if (p.length < 3 || p[1] !== "connected")
                continue;
            if (p[0] === "wifi" || p[0] === "ethernet") {
                found = { type: p[0], name: p.slice(2).join(":") };
                if (p[0] === "ethernet")
                    break;
            }
        }
        sys.netUp = found !== null;
        sys.wifi = found ? found.type === "wifi" : false;
        sys.net = found ? (found.type === "ethernet" ? "wired" : found.name) : "offline";
    }
    Timer {
        interval: 8000
        running: Theme.showNetwork
        repeat: true
        triggeredOnStart: true
        onTriggered: netProc.running = true
    }

    // ---- brightness (read on demand, e.g. after a brightness key)
    property real brightness: 0
    signal brightnessRead()
    Process {
        id: briProc
        command: ["bevelctl", "brightness", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim());
                if (!isNaN(v))
                    sys.brightness = v;
                sys.brightnessRead();
            }
        }
    }
    function readBrightness() { briProc.running = true; }
}
