import Quickshell
import Quickshell.Wayland
import QtQuick

// Bevvy, the desktop sheep (fun.pet). Wanders along the bottom of the screen (on top of a
// bottom taskbar), grazes, naps, and jumps when clicked. Only the sheep itself catches clicks.
// Party mode (type "party" in Super+R, or the Konami code) brings the whole flock for a while.
Scope {
    id: root
    readonly property bool on: Theme.sv("fun.pet", "off") === "sheep" || Ui.sheepParty
    Timer { running: Ui.sheepParty; interval: 20000; onTriggered: Ui.sheepParty = false }

    LazyLoader {
        active: root.on
        PanelWindow {
            id: win
            anchors { bottom: true; left: true; right: true }
            margins.bottom: Theme.barTop ? 0 : (Theme.barLayout === "taskbar" ? Theme.barHeight + 4 : Theme.barHeight + Theme.gapsOut)
            exclusionMode: ExclusionMode.Ignore
            implicitHeight: 70
            color: "transparent"
            WlrLayershell.namespace: "bevel-pet"
            WlrLayershell.layer: WlrLayer.Top
            mask: Region { id: rgn }

            Repeater {
                model: Ui.sheepParty ? 7 : 1
                Sheep {
                    id: sheep
                    required property int index
                    area: win.width
                    Component.onCompleted: {
                        x = Math.random() * (win.width - width);
                        // only the sheep catch clicks; the rest of the strip lets them through
                        try { rgn.regions = rgn.regions.concat([sheepRegion.createObject(rgn, { item: sheep })]); }
                        catch (e) { console.warn("bevel: pet click area: " + e); }
                    }
                }
            }
            Component { id: sheepRegion; Region {} }
        }
    }

    component Sheep: Item {
        id: s
        property real area: 800
        property int dir: Math.random() < 0.5 ? 1 : -1
        property string mode: "walk"     // walk | graze | sleep | jump
        property int frame: 0
        property real lift: 0
        property string say: ""
        readonly property int px: 3
        width: 16 * px
        height: 70
        y: 0

        // . empty  w wool  s wool shadow  f face  e eye  l legs  z closed eye
        readonly property var art: ({
            walk1: ["....wwwww.......", "..wwwwwwwww.....", ".wwwwwwwwwwwff..", "wwwwwwwwwwwffff.",
                    "wwwwwwwwwwwfeff.", "wwwwwwwwwwwfffff", ".wwwwwwwwwwwff..", ".swwwwwwwwws....",
                    "..sssssssss.....", "..l.l....l.l....", "..l.l....l.l....", "..l.l....l.l...."],
            walk2: ["....wwwww.......", "..wwwwwwwww.....", ".wwwwwwwwwwwff..", "wwwwwwwwwwwffff.",
                    "wwwwwwwwwwwfeff.", "wwwwwwwwwwwfffff", ".wwwwwwwwwwwff..", ".swwwwwwwwws....",
                    "..sssssssss.....", "...l.l..l.l.....", "..l...ll...l....", ".l.....l....l..."],
            graze: ["....wwwww.......", "..wwwwwwwww.....", ".wwwwwwwwwww....", "wwwwwwwwwwww....",
                    "wwwwwwwwwwwwff..", "wwwwwwwwwwwffff.", ".wwwwwwwwwwfeff.", ".swwwwwwwwwffff.",
                    "..sssssssss.ff..", "..l.l....l.l....", "..l.l....l.l....", "..l.l....l.l...."],
            sleep: ["................", "................", "................", "....wwwww.......",
                    "..wwwwwwwww.....", ".wwwwwwwwwwwff..", "wwwwwwwwwwwffff.", "wwwwwwwwwwwfzff.",
                    "wwwwwwwwwwwfffff", ".swwwwwwwwwwff..", "..sssssssss.....", "................"]
        })
        readonly property var rows: {
            if (mode === "sleep") return art.sleep;
            if (mode === "graze") return art.graze;
            return (frame % 2) ? art.walk2 : art.walk1;
        }
        readonly property var colours: ({ w: "#f6f6f2", s: "#c9c9c2", f: "#3a3a3a", e: "#ffffff", l: "#3a3a3a", z: "#7a7a7a" })

        Item {
            id: sprite
            width: 16 * s.px; height: 12 * s.px
            y: s.height - height - 2 - s.lift
            transform: Scale { origin.x: sprite.width / 2; xScale: s.dir }
            Repeater {
                model: 16 * 12
                Rectangle {
                    required property int index
                    readonly property string ch: s.rows[Math.floor(index / 16)][index % 16]
                    visible: ch !== "."
                    x: (index % 16) * s.px
                    y: Math.floor(index / 16) * s.px
                    width: s.px; height: s.px
                    color: s.colours[ch] || "transparent"
                }
            }
        }
        // speech bubble
        Rectangle {
            visible: s.say !== ""
            x: (s.width - width) / 2
            y: sprite.y - height - 4
            width: bubble.implicitWidth + 10
            height: bubble.implicitHeight + 4
            color: Theme.base
            border.color: Theme.dark
            BText { id: bubble; anchors.centerIn: parent; text: s.say; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
        }

        Timer {
            interval: 110; running: true; repeat: true
            onTriggered: {
                if (s.mode === "walk") {
                    s.frame++;
                    s.x += s.dir * 3;
                    if (s.x < 0) { s.x = 0; s.dir = 1; }
                    if (s.x > s.area - s.width) { s.x = s.area - s.width; s.dir = -1; }
                    if (Math.random() < 0.006) { s.mode = "graze"; restT.interval = 2500 + Math.random() * 3000; restT.restart(); }
                    else if (Math.random() < 0.002) { s.mode = "sleep"; s.say = "z z z"; restT.interval = 6000 + Math.random() * 8000; restT.restart(); }
                    else if (Math.random() < 0.004) s.dir = -s.dir;
                }
            }
        }
        Timer { id: restT; onTriggered: { s.mode = "walk"; s.say = ""; } }
        Timer { id: sayT; interval: 1400; onTriggered: if (s.mode !== "sleep") s.say = "" }
        SequentialAnimation {
            id: jump
            NumberAnimation { target: s; property: "lift"; to: 26; duration: 180; easing.type: Easing.OutQuad }
            NumberAnimation { target: s; property: "lift"; to: 0; duration: 220; easing.type: Easing.InQuad }
            ScriptAction { script: s.mode = "walk" }
        }
        MouseArea {
            anchors.fill: sprite
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const lines = ["Baa!", "Baaa!", "Meh.", "Hi " + (Quickshell.env("USER") || "") + "!", "I use " + Theme.distro + " btw", "Baa?"];
                s.say = lines[Math.floor(Math.random() * lines.length)];
                sayT.restart();
                restT.stop();
                s.mode = "jump";
                jump.restart();
            }
        }
    }
}
