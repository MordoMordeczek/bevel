import QtQuick

// The desktop widgets, packed Metro-style: first fit, left to right, top to bottom, mirrored
// when they hang from the right or bottom. implicitWidth/Height = the size of the whole block.
Item {
    id: g
    property int cell: Theme.sv("widgets.cell", 110)
    property int gap: Theme.sv("widgets.gap", 8)
    property int maxCols: 40                       // how many columns fit on the screen
    property bool toRight: false                   // tiles grow leftwards
    property bool toBottom: false                  // tiles grow upwards
    readonly property string arrange: Theme.sv("widgets.arrange", "grid")
    readonly property var list: Theme.widgetList.filter(it => Theme.widgetKinds.some(k => k.id === it.id))
    readonly property var sizes: list.map(it => String(it.size || "1x1").split("x").map(n => Math.max(1, parseInt(n) || 1)))
    readonly property int cols: {
        if (arrange === "row") return Math.max(1, Math.min(maxCols, sizes.reduce((a, s) => a + s[0], 0)));
        if (arrange === "column") return Math.max(1, sizes.reduce((a, s) => Math.max(a, s[0]), 1));
        return Math.max(1, Math.min(maxCols, Theme.sv("widgets.cols", 4)));
    }
    readonly property var packed: {
        const occ = [];
        const out = [];
        const free = (r, c, w, h) => {
            for (let y = r; y < r + h; y++)
                for (let x = c; x < c + w; x++)
                    if (occ[y] && occ[y][x]) return false;
            return true;
        };
        for (let i = 0; i < list.length; i++) {
            const w = Math.min(g.cols, sizes[i][0]), h = sizes[i][1];
            let done = false;
            for (let r = 0; !done && r < 80; r++) {
                for (let c = 0; c + w <= g.cols; c++) {
                    if (free(r, c, w, h)) {
                        for (let y = r; y < r + h; y++) {
                            occ[y] = occ[y] || [];
                            for (let x = c; x < c + w; x++) occ[y][x] = true;
                        }
                        out.push({ kind: list[i].id, cfg: list[i], x: c, y: r, w: w, h: h, index: i });
                        done = true;
                        break;
                    }
                }
            }
        }
        return out;
    }
    readonly property int rows: packed.reduce((m, p) => Math.max(m, p.y + p.h), 0)
    readonly property int usedCols: packed.reduce((m, p) => Math.max(m, p.x + p.w), 0)
    implicitWidth: Math.max(1, usedCols * cell + Math.max(0, usedCols - 1) * gap)
    implicitHeight: Math.max(1, rows * cell + Math.max(0, rows - 1) * gap)

    Repeater {
        model: g.visible ? g.packed : []
        DeskWidget {
            required property var modelData
            kind: modelData.kind
            cfg: modelData.cfg
            cw: modelData.w
            ch: modelData.h
            index: modelData.index
            width: modelData.w * g.cell + (modelData.w - 1) * g.gap
            height: modelData.h * g.cell + (modelData.h - 1) * g.gap
            x: g.toRight ? g.implicitWidth - (modelData.x + modelData.w) * (g.cell + g.gap) + g.gap : modelData.x * (g.cell + g.gap)
            y: g.toBottom ? g.implicitHeight - (modelData.y + modelData.h) * (g.cell + g.gap) + g.gap : modelData.y * (g.cell + g.gap)
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: 300 } }
            Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        }
    }
}
