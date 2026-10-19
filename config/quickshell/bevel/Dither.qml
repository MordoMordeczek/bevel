import QtQuick

// 2×2 checker pattern tiled over a panel (style.dither)
Image {
    source: Qt.resolvedUrl("dither.png")
    fillMode: Image.Tile
    smooth: false
    opacity: 0.55
}
