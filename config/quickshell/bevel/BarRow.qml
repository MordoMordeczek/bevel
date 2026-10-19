import QtQuick

// A bar's contents in three groups — left, centre, right — from Theme.barItems.
// The centre group stays in the middle of the bar; the window title and window buttons
// take whatever room is left in their group.
Item {
    id: br
    property var items: Theme.barItems
    property var bar: null
    property real originX: 0
    property var hmon: null
    property bool compact: false
    property int spacing: 10
    // islands: each group gets its own block, so they report their sizes and the bar draws them
    readonly property alias leftW: leftG.width
    readonly property alias centerW: centerG.width
    readonly property alias rightW: rightG.width
    readonly property alias centerX: centerG.x

    readonly property real centerFixed: centerG.fixed
    // room each group may use, from the fixed (non-stretching) widths of the others
    readonly property real sideRoom: br.items.center.length > 0 ? (width - centerFixed) / 2 - spacing * 2 : width
    readonly property real leftRoom: br.items.center.length > 0 ? sideRoom : width - rightG.fixed - spacing * 2
    readonly property real rightRoom: br.items.center.length > 0 ? sideRoom : width - leftG.fixed - spacing * 2
    readonly property real centerRoom: width - 2 * Math.max(leftG.fixed, rightG.fixed) - spacing * 4

    Group {
        id: leftG
        ids: br.items.left
        room: br.leftRoom
        anchors.left: parent.left
    }
    Group {
        id: centerG
        ids: br.items.center
        room: br.centerRoom
        x: Math.max(leftG.width + br.spacing, Math.min(br.width - rightG.width - br.spacing - width, Math.round((br.width - width) / 2)))
    }
    Group {
        id: rightG
        ids: br.items.right
        room: br.rightRoom
        anchors.right: parent.right
    }

    component Group: Row {
        id: g
        property var ids: []
        property real room: 200
        height: br.height
        spacing: br.spacing
        // the width of everything that doesn't stretch, and how many things do
        readonly property real fixed: {
            let w = 0, n = 0;
            for (let i = 0; i < g.children.length; i++) {
                const c = g.children[i];
                if (c.mid === undefined || !c.shown) continue;
                n++;
                if (!c.flex) w += c.implicitWidth;
            }
            return w + Math.max(0, n - 1) * g.spacing;
        }
        readonly property int flexCount: g.ids.filter(x => x === "title" || x === "tasks").length
        Repeater {
            model: g.ids
            BarModule {
                required property string modelData
                mid: modelData
                bar: br.bar
                originX: br.originX
                hmon: br.hmon
                compact: br.compact
                height: g.height
                flexW: Math.max(40, (g.room - g.fixed) / Math.max(1, g.flexCount))
            }
        }
    }
}
