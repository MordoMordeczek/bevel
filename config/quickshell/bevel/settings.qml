//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell
import QtQuick

// Standalone Bevel settings window (Super+I runs it next to the shell).
// Start with: bevelctl settings   (or qs -p ~/.config/quickshell/bevel/settings.qml)
ShellRoot {
    Opsec {
        id: opsec
        onPhaseChanged: if (opsec.phase === "" && !sw.open) idleQuit.restart()
    }
    SettingsWindow {
        id: sw
        Component.onCompleted: sw.open = true
        // closing only hides it, so Super+I opens it again at once; after a quarter of an hour
        // unused it quits to give the memory back (and not while the OPSEC window is up)
        onOpenChanged: if (sw.open) idleQuit.stop(); else idleQuit.restart()
    }
    Timer {
        id: idleQuit
        interval: 15 * 60 * 1000
        onTriggered: if (!sw.open && opsec.phase === "") Qt.quit()
    }
}
