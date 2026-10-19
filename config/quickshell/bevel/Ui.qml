pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick

// Shared on/off state between shell parts (e.g. the taskbar's Start button opens the launcher).
Singleton {
    property bool launcherOpen: false
    property bool saverOn: false
    property bool tipOpen: false
    property bool sheepParty: false
    property bool opsec: false        // set true to start the OPSEC easter egg
    property bool controlOpen: false  // the control panel (Super+A)
    property bool caffeine: false     // "keep awake": no screensaver either
    // the bar menus: which one is open ("clock", "battery", "sound", "network", "system", "notifs") and where
    property string flyout: ""
    property real flyoutX: -1         // centre of the bar item it hangs from (screen x), -1 = by the clock
    property var flyoutScreen: null
    property var barAnchors: ({})     // screen name → { menu → x of its bar item's centre }, filled in by the bars
    function anchorsFor(screen) { return (screen && barAnchors[screen.name]) || {}; }

    // ---- which screen things open on
    // the main display: Settings → Windows & display (widgets, notifications, the pet live there)
    readonly property var primaryScreen: {
        const want = Theme.sv("display.primary", "");
        const l = Quickshell.screens;
        for (let i = 0; i < l.length; i++) if (l[i].name === want) return l[i];
        return l.length > 0 ? l[0] : null;
    }
    // the monitor you're working on (keyboard focus). Frozen while a popup is open, so the launcher
    // or a menu doesn't jump to the other screen when the pointer wanders over there.
    property var focusedScreen: null
    property int popups: 0
    function syncScreen() {
        if (popups > 0 && focusedScreen !== null) return;
        const fm = Hyprland.focusedMonitor;
        const n = fm ? fm.name : "";
        const l = Quickshell.screens;
        let pick = null;
        for (let i = 0; i < l.length; i++) if (l[i].name === n) pick = l[i];
        focusedScreen = pick || primaryScreen;
    }
    onPopupsChanged: if (popups <= 0) { popups = 0; syncScreen(); }
    Connections { target: Hyprland; function onFocusedMonitorChanged() { Ui.syncScreen(); } }
    Connections { target: Quickshell; function onScreensChanged() { Ui.focusedScreen = null; Ui.syncScreen(); } }
    Component.onCompleted: syncScreen()

    // stopwatch + timer (clock menu, and a little readout on the bar while they run);
    // kept here so closing the menu doesn't stop them
    property real swStart: 0          // ms since epoch while running
    property real swAcc: 0            // ms counted before the last start
    property var swLaps: []           // total time at each lap, newest last
    readonly property bool swActive: swStart > 0 || swAcc > 0
    function swElapsed(now) { return swAcc + (swStart > 0 ? now - swStart : 0); }
    function swToggle() { if (swStart > 0) { swAcc += Date.now() - swStart; swStart = 0; } else swStart = Date.now(); }
    function swLap() { if (swActive) swLaps = swLaps.concat([swElapsed(Date.now())]); }
    function swReset() { swAcc = 0; swStart = 0; swLaps = []; }

    property real timerEnd: 0         // ms since epoch while counting down
    property real timerPaused: 0      // ms left while paused
    property real timerTotal: 0       // what it was set to (for the progress bar)
    readonly property bool timerActive: timerEnd > 0 || timerPaused > 0
    function timerLeft(now) { return timerEnd > 0 ? Math.max(0, timerEnd - now) : timerPaused; }
    function timerStart(sec) { timerTotal = sec * 1000; timerPaused = 0; timerEnd = Date.now() + sec * 1000; }
    function timerToggle() {
        if (timerEnd > 0) { timerPaused = Math.max(1, timerEnd - Date.now()); timerEnd = 0; }
        else if (timerPaused > 0) { timerEnd = Date.now() + timerPaused; timerPaused = 0; }
    }
    function timerAdd(sec) {
        if (timerEnd > 0) timerEnd += sec * 1000;
        else if (timerPaused > 0) timerPaused += sec * 1000;
        else { timerStart(sec); return; }
        timerTotal += sec * 1000;
    }
    function timerCancel() { timerEnd = 0; timerPaused = 0; timerTotal = 0; }
    // "m:ss", or "h:mm:ss" past an hour
    function clockText(ms) {
        const t = Math.floor(ms / 1000), h = Math.floor(t / 3600), m = Math.floor(t / 60) % 60, s = t % 60;
        return (h > 0 ? h + ":" + ("0" + m).slice(-2) : m) + ":" + ("0" + s).slice(-2);
    }
    Timer {
        interval: 250
        repeat: true
        running: timerEnd > 0
        onTriggered: if (Date.now() >= timerEnd) {
            timerEnd = 0;
            timerTotal = 0;
            Quickshell.execDetached(["notify-send", "-a", "Bevel", "-i", "alarm-clock", "Time's up!", "Your timer has finished."]);
            if (Theme.sv("clock.timerSound", true))
                Quickshell.execDetached(["sh", "-c", "f=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga; command -v canberra-gtk-play >/dev/null && canberra-gtk-play -i alarm-clock-elapsed || { command -v pw-play >/dev/null && [ -e $f ] && pw-play $f; }"]);
        }
    }
    property var cpExpanded: ({ calendar: false, wifi: false, bt: false, system: false, outputs: false, inputs: false, notifs: true })
}
