import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Settings → Windows & display → Displays, like the old Display Properties: a picture of how
// your monitors sit, then the picked one's resolution, refresh rate, size (scale), where it is
// and whether it's the main display. Changes that move pictures around ask "Keep these settings?"
// and go back by themselves after 15 seconds, in case a screen went black.
ColumnLayout {
    id: de
    Layout.fillWidth: true
    spacing: 8

    property var mons: []
    property string sel: ""
    readonly property var cfgAll: Theme.sv("display.monitors", {}) || {}
    readonly property string primary: {
        const p = Theme.sv("display.primary", "");
        if (p !== "" && mons.some(m => m.name === p)) return p;
        return mons.length > 0 ? mons[0].name : "";
    }
    readonly property var cur: mons.find(m => m.name === de.sel) || (mons.length > 0 ? mons[0] : null)
    readonly property var cfg: cur ? (cfgAll[cur.name] || {}) : ({})
    readonly property int enabledCount: mons.filter(m => !m.disabled).length

    // ---- keep or go back
    property var backup: null
    property int countdown: 0
    Timer {
        interval: 1000
        repeat: true
        running: de.countdown > 0
        onTriggered: { de.countdown--; if (de.countdown === 0) de.revert(); }
    }
    function change(name, patch) {
        const all = JSON.parse(JSON.stringify(de.cfgAll));
        const c = Object.assign({}, all[name] || {}, patch);
        for (const k in c) if (c[k] === null) delete c[k];
        all[name] = c;
        if (de.countdown === 0) de.backup = JSON.parse(JSON.stringify(de.cfgAll));
        de.countdown = 15;
        Theme.set("display.monitors", all);
        reread.restart();
    }
    function keep() { de.countdown = 0; de.backup = null; }
    function revert() {
        de.countdown = 0;
        if (de.backup !== null) Theme.set("display.monitors", de.backup);
        de.backup = null;
        reread.restart();
    }

    Process {
        id: list
        command: ["bevelctl", "displays"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { de.mons = JSON.parse(text); } catch (e) { de.mons = []; }
                if (de.sel === "" || !de.mons.some(m => m.name === de.sel)) {
                    const f = de.mons.find(m => m.focused);
                    de.sel = f ? f.name : (de.mons.length > 0 ? de.mons[0].name : "");
                }
            }
        }
    }
    Timer { id: reread; interval: 2500; onTriggered: list.running = true }

    // ---- "Keep these display settings?"
    Bevel {
        visible: de.countdown > 0
        Layout.fillWidth: true
        implicitHeight: keepRow.implicitHeight + 16
        fill: Theme.accent
        radius: Theme.radiusSm
        RowLayout {
            id: keepRow
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8
            BText {
                Layout.fillWidth: true
                text: "Keep these display settings? Going back in " + de.countdown + " s."
                color: Theme.accentText
                font.bold: true
                wrapMode: Text.Wrap
            }
            SButton { text: "Keep"; highlighted: true; onClicked: de.keep() }
            SButton { text: "Go back"; onClicked: de.revert() }
        }
    }

    BText {
        visible: de.mons.length === 0
        text: "Reading monitors…"
        color: Theme.textDim
    }

    // ---- the arrangement, drawn to scale; click one to set it up
    Bevel {
        visible: de.mons.length > 0
        Layout.fillWidth: true
        implicitHeight: 150
        sunken: true
        fill: Theme.dark
        radius: Theme.radiusSm
        Item {
            id: area
            anchors.fill: parent
            anchors.margins: 10
            readonly property var shown: de.mons.filter(m => !m.disabled && (m.mirrorOf === "none" || !m.mirrorOf))
            readonly property var box: {
                let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
                for (const m of area.shown) {
                    const w = m.width / (m.scale || 1), h = m.height / (m.scale || 1);
                    x0 = Math.min(x0, m.x); y0 = Math.min(y0, m.y); x1 = Math.max(x1, m.x + w); y1 = Math.max(y1, m.y + h);
                }
                return area.shown.length > 0 ? { x: x0, y: y0, w: x1 - x0, h: y1 - y0 } : { x: 0, y: 0, w: 1, h: 1 };
            }
            readonly property real k: Math.min(width / Math.max(1, box.w), height / Math.max(1, box.h))
            Repeater {
                model: area.shown
                Bevel {
                    id: scr
                    required property var modelData
                    required property int index
                    readonly property real lw: modelData.width / (modelData.scale || 1)
                    readonly property real lh: modelData.height / (modelData.scale || 1)
                    x: Math.round((area.width - area.box.w * area.k) / 2 + (modelData.x - area.box.x) * area.k) + 2
                    y: Math.round((area.height - area.box.h * area.k) / 2 + (modelData.y - area.box.y) * area.k) + 2
                    width: Math.max(20, Math.round(lw * area.k) - 4)
                    height: Math.max(14, Math.round(lh * area.k) - 4)
                    radius: Theme.radiusSm
                    fill: scr.modelData.name === de.sel ? Theme.accent : Theme.face
                    Column {
                        anchors.centerIn: parent
                        BText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (de.mons.findIndex(m => m.name === scr.modelData.name) + 1) + (scr.modelData.name === de.primary ? " ★" : "")
                            font.pixelSize: Theme.fontSize + 8
                            font.bold: true
                            color: scr.modelData.name === de.sel ? Theme.accentText : Theme.text
                        }
                        BText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: scr.modelData.name
                            font.pixelSize: Math.max(9, Theme.fontSize - 3)
                            color: scr.modelData.name === de.sel ? Theme.accentText : Theme.textDim
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: de.sel = scr.modelData.name }
                }
            }
        }
    }
    // switched-off and mirrored ones can't be drawn above; list them so they can be picked
    Flow {
        visible: de.mons.some(m => m.disabled || (m.mirrorOf && m.mirrorOf !== "none"))
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: de.mons.filter(m => m.disabled || (m.mirrorOf && m.mirrorOf !== "none"))
            SButton {
                required property var modelData
                text: modelData.name + (modelData.disabled ? " (off)" : " (same picture)")
                checked: modelData.name === de.sel
                onClicked: de.sel = modelData.name
            }
        }
    }

    // ---- the picked monitor
    ColumnLayout {
        id: pick
        visible: de.cur !== null
        Layout.fillWidth: true
        spacing: 8

        BText {
            Layout.fillWidth: true
            text: de.cur ? (de.mons.findIndex(m => m.name === de.cur.name) + 1) + ".  " + de.cur.name + (de.cur.description ? "  ·  " + de.cur.description : "") : ""
            font.bold: true
            elide: Text.ElideRight
        }
        RowLayout {
            spacing: 12
            visible: de.mons.length > 1
            SCheck {
                text: "Use this display"
                checked: de.cur ? !de.cur.disabled && de.cfg.enabled !== false : true
                // the main one, or the last one on, can't be switched off
                enabled: de.cur ? (de.cur.name !== de.primary && (de.cur.disabled || de.enabledCount > 1)) : false
                opacity: enabled ? 1 : 0.5
                onToggled: v => de.change(de.cur.name, { enabled: v ? null : false })
            }
            SButton {
                visible: de.cur && de.cur.name !== de.primary
                text: "Make this my main display"
                onClicked: Theme.set("display.primary", de.cur.name)
            }
            BText {
                visible: de.cur && de.cur.name === de.primary
                text: "★ Main display (widgets, the dock and new pop-ups start here)"
                color: Theme.textDim
            }
        }

        // resolution, then the refresh rates that resolution has
        readonly property var resList: {
            if (!de.cur) return [];
            const seen = [], out = [];
            for (const md of de.cur.modes) {
                const r = md.split("@")[0];
                if (seen.indexOf(r) < 0) { seen.push(r); out.push(r); }
            }
            out.sort((a, b) => { const pa = a.split("x"), pb = b.split("x"); return pb[0] * pb[1] - pa[0] * pa[1]; });
            return out.slice(0, 6);
        }
        readonly property string curRes: {
            const md = de.cfg.mode || "";
            if (/^\d+x\d+/.test(md)) return md.split("@")[0];
            return de.cur ? de.cur.width + "x" + de.cur.height : "";
        }
        SChoice {
            visible: de.cur && de.cur.modes.length > 0
            text: "Resolution"
            model: [{ label: "Best", value: "preferred" }].concat(pick.resList.map(r => ({ label: r.replace("x", "×"), value: r })))
            current: (de.cfg.mode || "preferred") === "preferred" ? "preferred" : pick.curRes
            onPicked: v => {
                if (v === "preferred") { de.change(de.cur.name, { mode: null }); return; }
                // keep the refresh rate if this resolution has it, else its fastest
                const rates = de.cur.modes.filter(m => m.split("@")[0] === v).map(m => parseInt(m.split("@")[1]));
                const want = de.cfg.mode && de.cfg.mode.indexOf("@") > 0 ? parseInt(de.cfg.mode.split("@")[1]) : de.cur.refresh;
                const r = rates.indexOf(want) >= 0 ? want : Math.max.apply(null, rates);
                de.change(de.cur.name, { mode: v + "@" + r });
            }
        }
        SChoice {
            readonly property var rates: de.cur ? de.cur.modes.filter(m => m.split("@")[0] === pick.curRes).map(m => parseInt(m.split("@")[1])).sort((a, b) => b - a) : []
            visible: rates.length > 1
            text: "Refresh rate"
            model: rates.map(r => ({ label: r + " Hz", value: r }))
            current: de.cfg.mode && de.cfg.mode.indexOf("@") > 0 ? parseInt(de.cfg.mode.split("@")[1]) : (de.cur ? de.cur.refresh : 60)
            onPicked: v => de.change(de.cur.name, { mode: pick.curRes + "@" + v })
        }
        SChoice {
            visible: de.cur !== null
            text: "Size (scale)"
            model: {
                const m = [{ label: "auto", value: "auto" }];
                if (!de.cur) return m;
                const nice = de.cur.options.filter(o => o <= 2.5 && (Math.abs(o * 20 - Math.round(o * 20)) < 1e-6 || Math.abs(o * 3 - Math.round(o * 3)) < 1e-6));
                for (const o of nice)
                    m.push({ label: (Math.round(o * 1000) / 1000) + "", value: o });
                return m;
            }
            current: de.cfg.scale !== undefined ? de.cfg.scale : Theme.sv("display.scale", 1)
            onPicked: v => de.change(de.cur.name, { scale: v })
        }
        SChoice {
            visible: de.cur !== null && de.mons.length > 1 && de.cur.name !== de.primary
            text: "Where is it?"
            model: [{ label: "Right of the main one", value: "auto-right" }, { label: "Left", value: "auto-left" },
                    { label: "Above", value: "auto-up" }, { label: "Below", value: "auto-down" }, { label: "Same picture", value: "mirror" }]
            current: de.cfg.mirror ? "mirror" : (de.cfg.position || "auto-right")
            onPicked: v => de.change(de.cur.name, v === "mirror" ? { mirror: de.primary, position: null } : { position: v, mirror: null })
        }
        BText {
            Layout.fillWidth: true
            text: "Smaller scale = more space, smaller everything; only scales your screen can do cleanly are listed. "
                  + "Super+Ctrl+←/→ moves between monitors, Super+Ctrl+Shift+←/→ takes the window along, Super+Alt+←/→ moves the whole workspace."
                  + " If a screen ever stays black: bevelctl displays reset"
            color: Theme.textDim
            font.pixelSize: Math.max(10, Theme.fontSize - 2)
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideNone
        }
    }
}
