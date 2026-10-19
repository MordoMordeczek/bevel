import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import QtQuick

// The desktop layer, one per screen: the live (animated) background and the widgets.
// Sits just above the wallpaper and below every window.
PanelWindow {
    id: bg
    required property var modelData
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.liveMode ? Theme.liveCols[2] : "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "bevel-desktop"
    WlrLayershell.keyboardFocus: showWidgets ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // only the widgets take clicks; everything else falls through to the wallpaper
    mask: Region { item: widgetArea }

    readonly property bool primary: Ui.primaryScreen !== null && bg.modelData.name === Ui.primaryScreen.name
    readonly property bool showWidgets: Theme.widgetsOn && (primary || Theme.sv("widgets.allScreens", false))

    // pause while the screensaver is up, or (if you like) on battery. Covered by windows needs no
    // check: Hyprland stops asking a hidden layer for frames, so it costs nothing then anyway.
    readonly property bool onBattery: Theme.sv("wallpaper.live.pauseOnBattery", false) && UPower.onBattery

    Loader {
        anchors.fill: parent
        active: Theme.liveMode
        sourceComponent: LiveBackground {
            running: !Ui.saverOn && !bg.onBattery
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: 600 } }
        }
    }

    // snow, stars, rain… over a picture wallpaper
    Loader {
        anchors.fill: parent
        active: Theme.fxOn
        sourceComponent: FxOverlay {
            running: !Ui.saverOn && !bg.onBattery
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: 600 } }
        }
    }

    // ---- widgets: a Metro-style block in a corner, along an edge or in the middle, clear of the bar
    // where: top-left · top · top-right · left · center · right · bottom-left · bottom · bottom-right
    readonly property string corner: Theme.sv("widgets.corner", "top-right")
    readonly property string hAlign: corner.endsWith("left") ? "left" : (corner.endsWith("right") ? "right" : "center")
    readonly property string vAlign: corner.startsWith("top") ? "top" : (corner.startsWith("bottom") ? "bottom" : "center")
    readonly property int edge: Theme.gapsOut * 2 + 8
    readonly property int barSpace: Theme.barHeight + (Theme.barFloating ? Theme.gapsOut : 0)
    readonly property int topSpace: (Theme.barTop ? barSpace : 0) + edge
    readonly property int bottomSpace: (!Theme.barTop ? barSpace : 0) + edge + (Theme.barLayout === "dock" && Theme.dockPos === "bottom" && !Theme.dockAutohide ? Theme.dockThickness + Theme.gapsOut : 0)

    WidgetGrid {
        id: widgetArea
        visible: bg.showWidgets
        maxCols: Math.max(1, Math.floor((bg.width - 2 * bg.edge + gap) / (cell + gap)))
        toRight: bg.hAlign === "right"
        toBottom: bg.vAlign === "bottom"
        width: implicitWidth
        height: implicitHeight
        x: bg.hAlign === "left" ? bg.edge : (bg.hAlign === "right" ? bg.width - width - bg.edge : Math.round((bg.width - width) / 2))
        y: bg.vAlign === "top" ? bg.topSpace
           : (bg.vAlign === "bottom" ? bg.height - height - bg.bottomSpace
              : Math.round(bg.topSpace + (bg.height - bg.topSpace - bg.bottomSpace - height) / 2))
    }

    // the still frame for the login and lock screens (main display only)
    LiveStill { active: Theme.liveMode && bg.primary }
}
