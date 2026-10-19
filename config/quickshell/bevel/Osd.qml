import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Volume / brightness pop-up. Volume follows PipeWire by itself;
// brightness keys call `qs -c bevel ipc call osd brightness`.
Scope {
    id: root
    property string kind: "volume"
    property bool shown: false
    property bool ready: false
    readonly property real level: kind === "volume" ? (Sys.muted ? 0 : Sys.volume) : Sys.brightness / 100

    function show(k) {
        if (!ready)
            return;
        kind = k;
        shown = true;
        hideTimer.restart();
    }

    Timer { interval: 2000; running: true; onTriggered: root.ready = true }   // ignore start-up noise
    Timer { id: hideTimer; interval: Theme.osdTimeout; onTriggered: root.shown = false }

    Connections {
        target: (Sys.sink && Sys.sink.audio) ? Sys.sink.audio : null
        function onVolumeChanged() { root.show("volume"); }
        function onMutedChanged() { root.show("volume"); }
    }
    Connections {
        target: Sys
        function onBrightnessRead() { root.show("brightness"); }
    }

    IpcHandler {
        target: "osd"
        function brightness(): void { Sys.readBrightness(); }
        function volume(): void { root.show("volume"); }
    }

    PanelWindow {
        screen: Ui.focusedScreen
        visible: root.shown
        anchors.bottom: true
        margins.bottom: 64
        exclusiveZone: 0
        implicitWidth: 260
        implicitHeight: Theme.fontSize + 24
        color: "transparent"
        mask: Region {}
        WlrLayershell.namespace: "bevel-osd"
        WlrLayershell.layer: WlrLayer.Overlay

        Bevel {
            anchors.fill: parent
            radius: Theme.radius
            padding: 6

            RowLayout {
                anchors.fill: parent
                spacing: 8
                PixelIcon {
                    kind: root.kind === "volume" ? (Sys.muted ? "mute" : "volume") : "bright"
                    level: root.level
                }
                // segmented 9x-style meter
                Bevel {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.fontSize + 4
                    sunken: true
                    fill: Theme.base
                    depth: Math.min(2, Theme.bevel)
                    padding: 1
                    Row {
                        id: blocks
                        anchors.fill: parent
                        spacing: 2
                        readonly property int count: 17
                        readonly property real bw: (width - spacing * (count - 1)) / count
                        Repeater {
                            model: blocks.count
                            Rectangle {
                                required property int index
                                width: blocks.bw
                                height: blocks.height
                                color: Theme.accent
                                visible: (index + 0.5) / blocks.count <= Math.min(1, root.level)
                            }
                        }
                    }
                }
                BText {
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignRight
                    text: root.kind === "volume" && Sys.muted ? "mute" : Math.round(root.level * 100) + "%"
                }
            }
        }
    }
}
