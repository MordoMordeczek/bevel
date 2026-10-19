import QtQuick

// One live (animated) background. The shader renders one texel per chunky pixel into a
// small texture that is scaled up without smoothing: pixel size 3 = 1/9 of the GPU work.
// Colours, speed, pixel size… default to your settings but can be overridden (previews).
ShaderEffect {
    id: fx
    property string kind: Theme.liveKind
    property var cols: Theme.liveCols
    property real speed: Theme.liveSpeed
    property int fps: Theme.liveFps
    property int pixelSize: Theme.livePixel
    property bool ditherOn: Theme.liveDither
    property bool running: true
    // previews are drawn small: shrink the chunky pixels with them (1920 = full screen)
    property real scaleRef: 0
    // draw once into a texture and reuse it (still previews)
    property bool cache: false

    readonly property real px: Math.max(1, scaleRef > 0 ? pixelSize * width / scaleRef : pixelSize)
    readonly property int texW: Math.max(1, Math.ceil(width / px))
    readonly property int texH: Math.max(1, Math.ceil(height / px))

    property real time: 6.0
    readonly property real pixel: px
    readonly property real dither: ditherOn ? 1 : 0
    readonly property size res: Qt.size(texW * px, texH * px)
    readonly property color c1: cols[0]
    readonly property color c2: cols[1]
    readonly property color c3: cols[2]
    readonly property color c4: cols[3]

    fragmentShader: Theme.liveDir + kind + ".frag.qsb"
    onStatusChanged: if (status === ShaderEffect.Error) console.warn("bevel: live background '" + kind + "' failed: " + log)
    readonly property bool failed: status === ShaderEffect.Error
    // one line in the log for "bevelctl doctor live"
    Component.onCompleted: if (scaleRef === 0) console.info("bevel: live background '" + kind + "' from " + fragmentShader + " via graphics api " + GraphicsInfo.api)
    blending: false

    layer.enabled: px > 1.01 || cache
    layer.textureSize: Qt.size(texW, texH)
    layer.smooth: false

    Timer {
        interval: Math.round(1000 / Math.max(1, fx.fps))
        repeat: true
        running: fx.running && fx.visible && fx.width > 0
        onTriggered: {
            fx.time += interval / 1000 * fx.speed;
            if (fx.time > 3600) fx.time -= 3594;     // keep float precision on long sessions
        }
    }
}
