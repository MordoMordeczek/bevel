import Quickshell
import Quickshell.Wayland
import QtQuick

// Full-screen "please wait" while a wallpaper/colour change is applied (Hyprland).
// Click anywhere to dismiss it early.
Variants {
    model: Quickshell.screens
    Scope {
        id: scope
        required property var modelData
        LazyLoader {
            active: Theme.busy && Theme.loadingScreen
            PanelWindow {
                screen: scope.modelData
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.namespace: "bevel-loading"
                WlrLayershell.layer: WlrLayer.Overlay
                Item {
                    id: content
                    anchors.fill: parent
                    opacity: 0
                    NumberAnimation on opacity { from: 0; to: 1; duration: 140; running: true }
                    Image {
                        anchors.fill: parent
                        source: Qt.resolvedUrl("dither.png")
                        fillMode: Image.Tile
                        smooth: false
                        opacity: 0.55
                    }
                    MouseArea { anchors.fill: parent; onClicked: Theme.busy = false }
                    LoadingDialog { anchors.centerIn: parent }
                }
            }
        }
    }
}
