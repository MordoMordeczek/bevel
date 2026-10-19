import QtQuick

// The BEVEL wordmark: every pixel is a little raised 9x block in the theme's colors.
// Blocks drop in one column at a time when it appears, then a glint sweeps across now and then.
Item {
    id: logo
    property real block: 14
    property string word: "BEVEL"
    property real sweep: -10

    readonly property var glyphs: ({
        "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
        "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
        "V": ["10001", "10001", "10001", "10001", "01010", "01010", "00100"],
        "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"]
    })

    readonly property var cells: {
        const out = [];
        let col0 = 0;
        for (let i = 0; i < word.length; i++) {
            const g = glyphs[word[i]];
            if (g) {
                for (let r = 0; r < 7; r++)
                    for (let c = 0; c < 5; c++)
                        if (g[r][c] === "1")
                            out.push({ c: col0 + c, r: r });
            }
            col0 += 6;
        }
        return out;
    }
    readonly property int cols: word.length * 6 - 1

    implicitWidth: cols * block + 6
    implicitHeight: 7 * block + 6

    // drop shadow
    Repeater {
        model: logo.cells
        Rectangle {
            required property var modelData
            x: modelData.c * logo.block + 5
            y: modelData.r * logo.block + 5
            width: logo.block; height: logo.block
            color: Theme.dark
            opacity: 0.45
        }
    }

    Repeater {
        model: logo.cells
        Item {
            id: px
            required property var modelData
            required property int index
            x: modelData.c * logo.block
            y: modelData.r * logo.block
            width: logo.block; height: logo.block

            // accent → accent2 across the word, plus the glint
            readonly property real t: modelData.c / Math.max(1, logo.cols - 1)
            readonly property real glow: Math.max(0, 1 - Math.abs(logo.sweep - modelData.c - modelData.r * 0.5) / 2.5)
            readonly property color base: Qt.rgba(
                Theme.accent.r + (Theme.accent2.r - Theme.accent.r) * t,
                Theme.accent.g + (Theme.accent2.g - Theme.accent.g) * t,
                Theme.accent.b + (Theme.accent2.b - Theme.accent.b) * t, 1)

            opacity: 0
            scale: 0.4
            Rectangle { anchors.fill: parent; color: Qt.lighter(px.base, 1 + px.glow * 0.6) }
            Rectangle { x: 0; y: 0; width: parent.width; height: 2; color: Qt.lighter(px.base, 1.5); opacity: 0.9 }
            Rectangle { x: 0; y: 0; width: 2; height: parent.height; color: Qt.lighter(px.base, 1.5); opacity: 0.9 }
            Rectangle { x: 0; y: parent.height - 2; width: parent.width; height: 2; color: Qt.darker(px.base, 1.8) }
            Rectangle { x: parent.width - 2; y: 0; width: 2; height: parent.height; color: Qt.darker(px.base, 1.8) }

            SequentialAnimation {
                running: true
                PauseAnimation { duration: px.modelData.c * 28 + px.modelData.r * 12 }
                ParallelAnimation {
                    NumberAnimation { target: px; property: "opacity"; to: 1; duration: 160 }
                    NumberAnimation { target: px; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutBack }
                }
            }
        }
    }

    SequentialAnimation on sweep {
        loops: Animation.Infinite
        PauseAnimation { duration: 1400 }
        NumberAnimation { from: -6; to: logo.cols + 8; duration: 1100; easing.type: Easing.InOutQuad }
        PauseAnimation { duration: 3200 }
    }
}
