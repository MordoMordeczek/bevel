import QtQuick

// A 9x-style panel: raised or sunken, with 0–2 pixel bevel lines.
// Lines are drawn as separate edges so a translucent fill stays clean.
Item {
    id: b

    property bool sunken: false
    property int depth: Theme.bevel
    property color fill: Theme.face
    property real fillOpacity: 1
    property int radius: 0
    property int padding: 0
    default property alias content: inner.data

    readonly property color tl1: sunken ? Theme.lo : Theme.hi
    readonly property color br1: sunken ? Theme.hi : Theme.dark
    readonly property color tl2: sunken ? Theme.dark : Theme.face2
    readonly property color br2: sunken ? Theme.face2 : Theme.lo
    readonly property int r: Math.max(0, radius)

    Rectangle {
        anchors.fill: parent
        radius: b.r
        color: Qt.rgba(b.fill.r, b.fill.g, b.fill.b, b.fill.a * b.fillOpacity)
        border.width: (b.depth === 0 || b.r > 0) ? 1 : 0
        border.color: Theme.lo
    }

    // outer lines
    Rectangle { visible: b.depth > 0; x: b.r; y: 0; width: b.width - 2 * b.r - 1; height: 1; color: b.tl1 }
    Rectangle { visible: b.depth > 0; x: 0; y: b.r; width: 1; height: b.height - 2 * b.r - 1; color: b.tl1 }
    Rectangle { visible: b.depth > 0; x: b.r; y: b.height - 1; width: b.width - 2 * b.r; height: 1; color: b.br1 }
    Rectangle { visible: b.depth > 0; x: b.width - 1; y: b.r; width: 1; height: b.height - 2 * b.r; color: b.br1 }
    // inner lines
    Rectangle { visible: b.depth > 1; x: Math.max(1, b.r); y: 1; width: b.width - 2 * Math.max(1, b.r) - 1; height: 1; color: b.tl2 }
    Rectangle { visible: b.depth > 1; x: 1; y: Math.max(1, b.r); width: 1; height: b.height - 2 * Math.max(1, b.r) - 1; color: b.tl2 }
    Rectangle { visible: b.depth > 1; x: Math.max(1, b.r); y: b.height - 2; width: b.width - 2 * Math.max(1, b.r) - 1; height: 1; color: b.br2 }
    Rectangle { visible: b.depth > 1; x: b.width - 2; y: Math.max(1, b.r); width: 1; height: b.height - 2 * Math.max(1, b.r) - 1; color: b.br2 }

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: Math.max(1, b.depth) + b.padding
    }
}
