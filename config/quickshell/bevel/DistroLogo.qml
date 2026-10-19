import QtQuick

// Your distro's logo, 9x pixel style: Bevel's hand-drawn Arch on Arch, otherwise your distro's own logo
// turned into 32x32 pixel art by bevelctl (generated/distro-logo.png), or a little 9x computer when
// there's no logo to use. Settings → Fun picks which. Set tint to draw it in one colour.
Item {
    id: dl
    property color tint: "transparent"
    readonly property string kind: Theme.distroLogo === "system" && Theme.distroLogoPng === "" ? "generic" : Theme.distroLogo
    readonly property bool shown: kind !== "none"
    implicitWidth: 64
    implicitHeight: 64

    ArchLogo {
        anchors.fill: parent
        visible: dl.kind === "arch"
        tint: dl.tint
    }

    Canvas {
        id: px
        anchors.fill: parent
        visible: dl.kind === "system"
        renderStrategy: Canvas.Immediate
        antialiasing: false
        readonly property int grid: 32
        readonly property string src: dl.kind === "system" ? Theme.distroLogoPng : ""
        property string loaded: ""
        onSrcChanged: if (src !== "") loadImage(src)
        Component.onCompleted: if (src !== "") loadImage(src)
        onImageLoaded: { loaded = src; requestPaint(); }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: dl; function onTintChanged() { px.requestPaint(); } }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (loaded === "" || !isImageLoaded(loaded)) return;
            // read the 32x32 picture, then draw each pixel as a whole-number block so it stays crisp
            ctx.drawImage(loaded, 0, 0, grid, grid);
            const data = ctx.getImageData(0, 0, grid, grid).data;
            ctx.reset();
            const m = Math.min(width, height);
            const s = m >= grid ? Math.floor(m / grid) : m / grid;
            const ox = Math.floor((width - grid * s) / 2), oy = Math.floor((height - grid * s) / 2);
            const one = dl.tint.a > 0;
            const lite = Qt.lighter(dl.tint, 1.25), dark = Qt.darker(dl.tint, 1.35);
            for (let y = 0; y < grid; y++) {
                for (let x = 0; x < grid; x++) {
                    const i = (y * grid + x) * 4;
                    if (data[i + 3] < 128) continue;
                    if (one) {
                        const l = (0.3 * data[i] + 0.59 * data[i + 1] + 0.11 * data[i + 2]) / 255;
                        ctx.fillStyle = l > 0.7 ? lite : (l < 0.3 ? dark : dl.tint);
                    } else {
                        ctx.fillStyle = Qt.rgba(data[i] / 255, data[i + 1] / 255, data[i + 2] / 255, 1);
                    }
                    ctx.fillRect(ox + x * s, oy + y * s, s, s);
                }
            }
        }
    }

    PixIcon {
        anchors.centerIn: parent
        visible: dl.kind === "generic"
        kind: "monitor"
        zoom: Math.max(1, Math.floor(Math.min(dl.width, dl.height) / 16))
    }
}
