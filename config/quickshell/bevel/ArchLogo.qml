import QtQuick

// The Arch Linux logo as 32x32 pixel art (fetch + "btw" widgets), in Arch blue with a
// light left edge and a dark right edge, 9x style. Set tint to draw it in one colour.
Canvas {
    id: lg
    property color tint: "transparent"
    readonly property int grid: 32
    implicitWidth: grid * 2
    implicitHeight: grid * 2
    renderStrategy: Canvas.Immediate
    antialiasing: false
    readonly property string bits: "...............................................An..............................An.............................Aaan............................Aaan...........................Aaaaan..........................Aaaaan.........................Aaaaaaan........................Aaaaaaan.......................A.Aaaaaaan......................An.Aaaaaan.....................Aaan.Aaaaaan....................Aaaaaaaaaaan...................Aaaaaaaaaaaaan..................Aaaaaaaaaaaaan.................Aaaaaaaaaaaaaaan................Aaaaaaaaaaaaaaan...............Aaaaaaaaaaaaaaaaan..............Aaaaaaaaaaaaaaaaan.............Aaaaaaan....Aaaaaaan............Aaaaaan......Aaaaaan...........Aaaaaaan......Aaaaaaan..........Aaaaaaan......Aaaaaaan.........Aaaaaaan........Aaaaaaan........Aaaaaaan........Aaaaaaan.......Aaaaaaaan........Aaaaaaaan......Aaaaaaaan........Aaaaaaaan......Aaaaan..............Aaaaan.....Aaaan..................Aaaan...Aan........................Aan..An..........................An................................."
    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const m = Math.min(width, height);
        const s = m >= grid ? Math.floor(m / grid) : m / grid;
        const ox = Math.floor((width - grid * s) / 2), oy = Math.floor((height - grid * s) / 2);
        const one = lg.tint.a > 0;
        const col = { "a": one ? lg.tint : "#1793d1", "A": one ? Qt.lighter(lg.tint, 1.25) : "#5bbcf0", "n": one ? Qt.darker(lg.tint, 1.35) : "#0b5f8a" };
        for (let y = 0; y < grid; y++) {
            let x = 0;
            while (x < grid) {
                const ch = bits[y * grid + x];
                let run = 1;
                while (x + run < grid && bits[y * grid + x + run] === ch) run++;
                if (ch !== ".") {
                    ctx.fillStyle = col[ch];
                    ctx.fillRect(ox + x * s, oy + y * s, run * s, s);
                }
                x += run;
            }
        }
    }
}
