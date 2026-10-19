import Quickshell
import Quickshell.Io
import QtQuick

// Saves a still frame of the live background (once per look) for the places that can't
// animate: login screen, lock screen and Firefox's new tab.
// Put one in any window; it renders off-screen at full HD, saves, then runs `bevelctl apply`.
Item {
    id: root
    property bool active: Theme.liveMode
    readonly property string target: Theme.liveStill
    property string done: ""
    property bool rendering: false
    x: -20000; y: -20000
    width: 1920; height: 1080

    onTargetChanged: if (root.active) check.restart()
    onActiveChanged: if (root.active) check.restart()
    Component.onCompleted: if (root.active) check.restart()

    Timer { id: check; interval: 700; onTriggered: if (root.done !== root.target && !root.rendering) exists.running = true }
    Process {
        id: exists
        command: ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && test -s \"$1\"", "sh", root.target]
        onExited: code => {
            if (code === 0) {
                root.done = root.target;
            } else {
                root.rendering = true;
            }
        }
    }
    LiveBackground {
        id: frame
        anchors.fill: parent
        visible: root.rendering
        running: false
        time: 6.0
    }
    Timer {
        // give the shader a frame to draw, then save (retry while the window is still opening)
        id: grabTimer
        interval: 350
        running: root.rendering
        property int tries: 0
        onTriggered: {
            const file = root.target;
            const ok = frame.Window.window && frame.Window.window.visible && frame.grabToImage(r => {
                if (r.saveToFile(file)) {
                    root.done = file;
                    console.info("bevel: saved live still " + file);
                    Theme.requestApply();
                }
                root.rendering = false;
                grabTimer.tries = 0;
                if (root.target !== file) check.restart();
            });
            if (!ok) {
                if (++grabTimer.tries < 40) grabTimer.restart();
                else { root.rendering = false; grabTimer.tries = 0; }
            }
        }
    }
}
