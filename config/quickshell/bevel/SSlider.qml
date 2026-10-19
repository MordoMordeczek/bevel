import QtQuick
import QtQuick.Layouts

// Label · track · value. Emits moved(value) while dragging; the caller writes it to settings.
RowLayout {
    id: root
    property string text: ""
    property real from: 0
    property real to: 1
    property real step: 0.01
    property real value: 0
    property string suffix: ""
    property int decimals: 0
    property real displayScale: 1
    property int labelWidth: 130
    signal moved(real value)

    property real live: value
    onValueChanged: if (!ma.pressed) live = value

    spacing: 10
    Layout.fillWidth: true

    BText {
        text: root.text
        Layout.preferredWidth: root.labelWidth
    }

    Item {
        id: track
        Layout.fillWidth: true
        implicitHeight: 20

        Bevel {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            sunken: true
            depth: Math.min(2, Theme.bevel)
            fill: Theme.base
            Rectangle {
                height: parent.height
                width: (root.live - root.from) / (root.to - root.from) * parent.width
                color: Theme.accent
            }
        }
        Bevel {
            id: thumb
            width: 11
            height: 20
            x: (root.live - root.from) / (root.to - root.from) * (track.width - width)
            radius: Theme.radiusSm
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            preventStealing: true
            onPressedChanged: Theme.holding = pressed
            onReleased: console.info("bevel: slider " + root.text + " released at " + root.live)
            function upd(mx) {
                let t = Math.max(0, Math.min(1, (mx - thumb.width / 2) / (track.width - thumb.width)));
                let v = root.from + t * (root.to - root.from);
                v = Math.round(v / root.step) * root.step;
                v = Math.max(root.from, Math.min(root.to, v));
                v = Number(v.toFixed(4));
                if (v !== root.live) {
                    root.live = v;
                    root.moved(v);
                }
            }
            onPressed: mouse => upd(mouse.x)
            onPositionChanged: mouse => { if (pressed) upd(mouse.x); }
        }
    }

    BText {
        Layout.preferredWidth: 52
        horizontalAlignment: Text.AlignRight
        text: (root.live * root.displayScale).toFixed(root.decimals) + root.suffix
    }
}
