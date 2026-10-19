import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Screensavers from the old days: Starfield, Mystify, Pipes.
// Super+Shift+Z or after some idle minutes (fun.saverMinutes). Any key or mouse move ends it.
Scope {
    id: root
    IpcHandler {
        target: "screensaver"
        function start(): void { root.go(); }
        function stop(): void { Ui.saverOn = false; }
    }
    function go() { if (Theme.saver !== "off") Ui.saverOn = true; }

    // idle detection lives in its own file: if this Quickshell has no IdleMonitor, only that part is skipped
    Loader {
        active: Theme.saver !== "off" && Theme.saverMinutes > 0
        source: "IdleWatch.qml"
    }

    Variants {
        model: Quickshell.screens
        Scope {
            id: scr
            required property var modelData
            LazyLoader {
                active: Ui.saverOn
                PanelWindow {
                    id: win
                    screen: scr.modelData
                    anchors { top: true; bottom: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Ignore
                    color: "black"
                    WlrLayershell.namespace: "bevel-screensaver"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                    property real startX: -1
                    property real startY: -1
                    property double shownAt: Date.now()
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.BlankCursor
                        onPositionChanged: mouse => {
                            if (Date.now() - win.shownAt < 600) return;      // ignore the jitter right after it starts
                            if (win.startX < 0) { win.startX = mouse.x; win.startY = mouse.y; return; }
                            if (Math.abs(mouse.x - win.startX) + Math.abs(mouse.y - win.startY) > 12) Ui.saverOn = false;
                        }
                        onPressed: Ui.saverOn = false
                    }
                    Item {
                        anchors.fill: parent
                        focus: true
                        Keys.onPressed: event => { Ui.saverOn = false; event.accepted = true; }
                    }

                    Canvas {
                        id: cv
                        anchors.fill: parent
                        renderStrategy: Canvas.Threaded
                        property var stars: []
                        property var poly: []
                        property var pipes: []
                        property int frame: 0
                        readonly property string kind: Theme.saver
                        function rnd(a, b) { return a + Math.random() * (b - a); }
                        Component.onCompleted: {
                            for (let i = 0; i < 260; i++)
                                stars.push({ x: rnd(-1, 1), y: rnd(-1, 1), z: rnd(0.05, 1) });
                            for (let s = 0; s < 2; s++) {
                                const p = [];
                                for (let i = 0; i < 4; i++)
                                    p.push({ x: rnd(0, width), y: rnd(0, height), dx: rnd(-4, 4), dy: rnd(-4, 4) });
                                poly.push({ pts: p, trail: [] });
                            }
                        }
                        Timer {
                            interval: 33; running: true; repeat: true
                            onTriggered: { cv.frame++; cv.requestPaint(); }
                        }
                        onPaint: {
                            const g = getContext("2d");
                            const w = width, h = height;
                            if (kind === "mystify") {
                                g.fillStyle = "black"; g.fillRect(0, 0, w, h);
                                const cols = [Theme.accent2, Theme.accent];
                                for (let s = 0; s < poly.length; s++) {
                                    const P = poly[s];
                                    for (const p of P.pts) {
                                        p.x += p.dx; p.y += p.dy;
                                        if (p.x < 0 || p.x > w) p.dx = -p.dx;
                                        if (p.y < 0 || p.y > h) p.dy = -p.dy;
                                    }
                                    P.trail.unshift(P.pts.map(p => ({ x: p.x, y: p.y })));
                                    if (P.trail.length > 7) P.trail.pop();
                                    for (let t = 0; t < P.trail.length; t++) {
                                        if (t % 2) continue;
                                        g.strokeStyle = cols[s]; g.globalAlpha = 1 - t / 8; g.lineWidth = 2;
                                        g.beginPath();
                                        const q = P.trail[t];
                                        g.moveTo(q[0].x, q[0].y);
                                        for (let i = 1; i <= q.length; i++) g.lineTo(q[i % q.length].x, q[i % q.length].y);
                                        g.stroke();
                                    }
                                }
                                g.globalAlpha = 1;
                            } else if (kind === "pipes") {
                                // a slow-growing tangle of chunky pipes in the palette colours
                                if (frame % 900 === 1) { g.fillStyle = "black"; g.fillRect(0, 0, w, h); pipes = []; }
                                const cols = [Theme.accent, Theme.accent2, Theme.face, Theme.lo, Theme.hi];
                                if (pipes.length < 4 && frame % 40 === 1)
                                    pipes.push({ x: Math.floor(rnd(2, w / 24 - 2)) * 24, y: Math.floor(rnd(2, h / 24 - 2)) * 24,
                                                 d: Math.floor(rnd(0, 4)), c: cols[Math.floor(rnd(0, cols.length))] });
                                for (const p of pipes) {
                                    if (Math.random() < 0.2) {
                                        p.d = (p.d + (Math.random() < 0.5 ? 1 : 3)) % 4;
                                        g.fillStyle = p.c; g.beginPath(); g.arc(p.x, p.y, 9, 0, 6.3); g.fill();
                                    }
                                    const nx = p.x + [24, 0, -24, 0][p.d], ny = p.y + [0, 24, 0, -24][p.d];
                                    if (nx < 0 || ny < 0 || nx > w || ny > h) { p.d = (p.d + 2) % 4; continue; }
                                    g.strokeStyle = p.c; g.lineWidth = 12; g.lineCap = "round";
                                    g.beginPath(); g.moveTo(p.x, p.y); g.lineTo(nx, ny); g.stroke();
                                    g.strokeStyle = Qt.lighter(p.c, 1.5); g.lineWidth = 3;
                                    g.beginPath(); g.moveTo(p.x - 2, p.y - 2); g.lineTo(nx - 2, ny - 2); g.stroke();
                                    p.x = nx; p.y = ny;
                                }
                            } else {
                                g.fillStyle = "black"; g.fillRect(0, 0, w, h);
                                const cx = w / 2, cy = h / 2;
                                for (const s of stars) {
                                    s.z -= 0.012;
                                    if (s.z <= 0.02) { s.x = rnd(-1, 1); s.y = rnd(-1, 1); s.z = 1; }
                                    const sx = cx + s.x / s.z * cx * 0.6, sy = cy + s.y / s.z * cy * 0.6;
                                    if (sx < 0 || sy < 0 || sx > w || sy > h) { s.z = 1; continue; }
                                    const size = Math.max(1, (1 - s.z) * 4);
                                    g.fillStyle = s.z < 0.35 ? "white" : Theme.accent2;
                                    g.fillRect(sx, sy, size, size);
                                }
                            }
                        }
                    }
                    Component.onCompleted: shownAt = Date.now()
                }
            }
        }
    }
}
