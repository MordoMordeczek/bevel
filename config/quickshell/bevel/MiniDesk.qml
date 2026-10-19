import QtQuick

// A tiny live mock-up of a desktop layout / launcher, in the current colours (Settings previews).
Rectangle {
    id: m
    property string layout: "bevel"     // bevel | taskbar | island | dock
    property string launcher: ""        // "" | run | grid | start
    property string power: ""           // "" | dialog | tiles | dropdown
    implicitWidth: 240
    implicitHeight: 150
    clip: true
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.darker(Theme.accent, 1.6) }
        GradientStop { position: 1; color: Qt.darker(Theme.lo, 1.3) }
    }
    readonly property bool barOnTop: layout !== "taskbar"
    readonly property int barH: 9

    component Win: Rectangle {
        property bool active: false
        color: Theme.face
        border.color: Theme.dark
        Rectangle { x: 1; y: 1; width: parent.width - 2; height: 5; color: parent.active ? Theme.accent : Theme.lo }
        Rectangle { x: 3; y: 9; width: parent.width - 6; height: parent.height - 12; color: Theme.base; opacity: 0.9 }
    }
    component Pill: Rectangle { color: Theme.face; border.color: Theme.dark; height: m.barH }

    // windows (tiled, under the bars)
    Win { visible: m.launcher === "" && m.power === ""; x: 8; y: m.barOnTop ? 20 : 8; width: m.width * 0.5 - 12; height: m.height - 36; active: true }
    Win { visible: m.launcher === "" && m.power === ""; x: m.width * 0.5 + 2; y: m.barOnTop ? 20 : 8; width: m.width * 0.5 - 10; height: m.height - 36 - (m.layout === "dock" ? 16 : 0) }

    // ---- bars
    Pill { visible: m.layout === "bevel"; x: 4; y: 4; width: m.width - 8
        Row { x: 3; y: 2; spacing: 2; Repeater { model: 4; Rectangle { width: 8; height: 5; color: index === 0 ? Theme.accent : Theme.lo } } }
        Rectangle { anchors.right: parent.right; anchors.rightMargin: 3; y: 2; width: 18; height: 5; color: Theme.base; border.color: Theme.lo } }
    Rectangle { visible: m.layout === "taskbar"; x: 0; y: m.height - 11; width: m.width; height: 11; color: Theme.face; border.color: Theme.hi
        Rectangle { x: 2; y: 2; width: 18; height: 7; color: Theme.face2; border.color: Theme.dark }
        Rectangle { x: 24; y: 2; width: 34; height: 7; color: Theme.face2; border.color: Theme.lo }
        Rectangle { x: 61; y: 2; width: 34; height: 7; color: Theme.face; border.color: Theme.lo }
        Rectangle { anchors.right: parent.right; anchors.rightMargin: 2; y: 2; width: 26; height: 7; color: "transparent"; border.color: Theme.lo } }
    Pill { visible: m.layout === "island"; x: 4; y: 4; width: 40
        Row { x: 3; y: 2; spacing: 2; Repeater { model: 3; Rectangle { width: 8; height: 5; color: index === 0 ? Theme.accent : Theme.lo } } } }
    Pill { visible: m.layout === "island"; x: m.width / 2 - 14; y: 4; width: 28 }
    Pill { visible: m.layout === "island"; x: m.width - 48; y: 4; width: 44 }
    Pill { visible: m.layout === "dock"; x: 4; y: 4; width: m.width - 8; height: 7 }
    Pill { visible: m.layout === "dock"; x: m.width / 2 - 40; y: m.height - 16; width: 80; height: 13
        Row { anchors.centerIn: parent; spacing: 3; Repeater { model: 6; Rectangle { width: 8; height: 8; color: [Theme.accent, Theme.accent2, Theme.lo, Theme.face2, Theme.accent, Theme.text][index] } } } }

    // ---- shut-down menus
    Image { visible: m.power === "dialog" || m.power === "tiles"; anchors.fill: parent; source: Qt.resolvedUrl("dither.png"); fillMode: Image.Tile; opacity: 0.8 }
    Rectangle { visible: m.power === "dialog"; anchors.centerIn: parent; width: 100; height: 70; color: Theme.face; border.color: Theme.dark
        Rectangle { x: 1; y: 1; width: parent.width - 2; height: 7; color: Theme.accent }
        Column { x: 34; y: 14; spacing: 4; Repeater { model: 5; Row { spacing: 3
            Rectangle { width: 5; height: 5; radius: 3; color: Theme.base; border.color: Theme.lo }
            Rectangle { width: 36; height: 5; color: index === 4 ? Theme.accent : Theme.lo } } } }
        Rectangle { x: 6; y: 16; width: 22; height: 15; color: Theme.accent; border.color: Theme.dark } }
    Row { visible: m.power === "tiles"; anchors.centerIn: parent; spacing: 5
        Repeater { model: 5; Rectangle { width: 26; height: 30; color: index === 4 ? Theme.accent : Theme.face; border.color: Theme.dark
            Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: "transparent"; border.width: 2; border.color: index === 4 ? Theme.accentText : Theme.text } } } }
    Pill { visible: m.power === "dropdown"; x: 4; y: 4; width: m.width - 8 }
    Rectangle { visible: m.power === "dropdown"; x: m.width - 70; y: 16; width: 66; height: 60; color: Theme.face; border.color: Theme.dark
        Rectangle { x: 1; y: 1; width: parent.width - 2; height: 7; color: Theme.accent }
        Column { x: 4; y: 11; spacing: 3; Repeater { model: 5; Rectangle { width: 58; height: 6; color: index === 1 ? Theme.accent : Theme.face2 } } } }

    // ---- launchers
    Rectangle { visible: m.launcher === "run"; x: 6; y: 16; width: 92; height: 70; color: Theme.face; border.color: Theme.dark
        Rectangle { x: 1; y: 1; width: parent.width - 2; height: 6; color: Theme.accent }
        Rectangle { x: 4; y: 11; width: parent.width - 8; height: 7; color: Theme.base; border.color: Theme.lo }
        Column { x: 4; y: 21; spacing: 2; Repeater { model: 6; Rectangle { width: 84; height: 5; color: index === 1 ? Theme.accent : Theme.base } } } }
    Rectangle { visible: m.launcher === "grid"; x: m.width / 2 - 70; y: 18; width: 140; height: 110; color: Theme.face; border.color: Theme.dark
        Rectangle { x: 1; y: 1; width: parent.width - 2; height: 6; color: Theme.accent }
        Rectangle { x: 4; y: 10; width: parent.width - 8; height: 96; color: Theme.base; border.color: Theme.lo
            Grid { x: 6; y: 6; columns: 6; spacing: 8; Repeater { model: 18; Rectangle { width: 12; height: 12; color: [Theme.accent, Theme.accent2, Theme.lo][index % 3] } } } } }
    Rectangle { visible: m.launcher === "start"; x: 2; y: m.height - 100; width: 100; height: 88; color: Theme.face; border.color: Theme.dark
        Rectangle { x: 1; y: 1; width: 9; height: parent.height - 2
            gradient: Gradient { GradientStop { position: 0; color: Theme.accent2 } GradientStop { position: 1; color: Theme.accent } } }
        Column { x: 14; y: 6; spacing: 4; Repeater { model: 8; Rectangle { width: 80; height: 6; color: index === 2 ? Theme.accent : Theme.face2 } } } }
    Rectangle { visible: m.launcher === "start"; x: 0; y: m.height - 10; width: m.width; height: 10; color: Theme.face; border.color: Theme.hi
        Rectangle { x: 2; y: 2; width: 18; height: 6; color: Theme.face2; border.color: Theme.dark } }
}
