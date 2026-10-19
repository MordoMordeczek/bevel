import QtQuick

// An effect drawn over a picture wallpaper (snow, stars, rain…): a transparent shader on the
// desktop layer, in chunky pixels like the animated backgrounds. Settings → Wallpaper → Effect.
ShaderEffect {
    id: fx
    property string kind: Theme.fxKind
    property real speed: Theme.fxSpeed
    property int fps: 30
    property int pixelSize: Theme.fxPixel
    property bool running: true
    property real scaleRef: 0               // previews: shrink the pixels with the picture

    readonly property real px: Math.max(1, scaleRef > 0 ? pixelSize * width / scaleRef : pixelSize)
    readonly property int texW: Math.max(1, Math.ceil(width / px))
    readonly property int texH: Math.max(1, Math.ceil(height / px))

    property real time: 3.0
    readonly property real pixel: px
    property real density: Theme.fxDensity
    readonly property size res: Qt.size(texW * px, texH * px)
    property color c1: Theme.fxColor
    readonly property color c2: Theme.accent

    visible: kind !== "none"
    fragmentShader: kind !== "none" ? Theme.liveDir + "fx_" + kind + ".frag.qsb" : ""
    onStatusChanged: if (status === ShaderEffect.Error) console.warn("bevel: wallpaper effect '" + kind + "' failed: " + log)
    blending: true

    layer.enabled: px > 1.01
    layer.textureSize: Qt.size(texW, texH)
    layer.smooth: false

    Timer {
        interval: Math.round(1000 / fx.fps)
        repeat: true
        running: fx.running && fx.visible && fx.width > 0
        onTriggered: {
            fx.time += interval / 1000 * fx.speed;
            if (fx.time > 3600) fx.time -= 3500;
        }
    }
}
