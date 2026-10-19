import QtQuick

// 9x-style raised / sunken panel (same look as the Quickshell rice)
Item {
    id: b
    property var pal
    property bool sunken: false
    property int depth: 2
    property color fill: pal.face
    default property alias content: inner.data

    readonly property color tl1: sunken ? pal.lo : pal.hi
    readonly property color br1: sunken ? pal.hi : pal.dark
    readonly property color tl2: sunken ? pal.dark : pal.face2
    readonly property color br2: sunken ? pal.face2 : pal.lo

    Rectangle { anchors.fill: parent; color: b.fill; border.width: b.depth === 0 ? 1 : 0; border.color: b.pal.lo }

    Rectangle { visible: b.depth > 0; x: 0; y: 0; width: b.width - 1; height: 1; color: b.tl1 }
    Rectangle { visible: b.depth > 0; x: 0; y: 0; width: 1; height: b.height - 1; color: b.tl1 }
    Rectangle { visible: b.depth > 0; x: 0; y: b.height - 1; width: b.width; height: 1; color: b.br1 }
    Rectangle { visible: b.depth > 0; x: b.width - 1; y: 0; width: 1; height: b.height; color: b.br1 }
    Rectangle { visible: b.depth > 1; x: 1; y: 1; width: b.width - 3; height: 1; color: b.tl2 }
    Rectangle { visible: b.depth > 1; x: 1; y: 1; width: 1; height: b.height - 3; color: b.tl2 }
    Rectangle { visible: b.depth > 1; x: 1; y: b.height - 2; width: b.width - 2; height: 1; color: b.br2 }
    Rectangle { visible: b.depth > 1; x: b.width - 2; y: 1; width: 1; height: b.height - 2; color: b.br2 }

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: Math.max(1, b.depth)
    }
}
