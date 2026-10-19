import Quickshell
import Quickshell.Wayland
import QtQuick

// Starts the screensaver after fun.saverMinutes of no input (needs Quickshell's IdleMonitor).
IdleMonitor {
    enabled: !Ui.caffeine
    respectInhibitors: true      // videos and games that block idle keep it away
    timeout: Theme.saverMinutes * 60
    onIsIdleChanged: if (isIdle && Theme.saver !== "off") Ui.saverOn = true
}
