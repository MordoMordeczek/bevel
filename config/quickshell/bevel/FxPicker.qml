import QtQuick
import QtQuick.Layouts

// Settings → Wallpaper → Picture: an effect over your wallpaper (snow, stars, rain…),
// with a small live preview on top of the current picture.
RowLayout {
    id: root
    property bool xfce: false
    spacing: 14
    property string hover: ""
    readonly property string shownKind: hover !== "" ? hover : Theme.fxKind

    // preview: the wallpaper with the effect running over it
    ColumnLayout {
        Layout.alignment: Qt.AlignTop
        spacing: 4
        Bevel {
            implicitWidth: 240
            implicitHeight: 240 * 9 / 16 + 4
            sunken: true
            fill: Theme.dark
            padding: 1
            clip: true
            Image {
                anchors.fill: parent
                anchors.margins: 2
                source: Theme.wallpaper !== "" ? "file://" + Theme.wallpaper : ""
                sourceSize.width: 480
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            FxOverlay {
                anchors.fill: parent
                anchors.margins: 2
                kind: root.shownKind
                scaleRef: 1920
                // a small preview needs more of everything to show what it looks like
                density: Theme.fxDensity
            }
            BText {
                anchors.centerIn: parent
                visible: root.shownKind === "none"
                text: "no effect"
                color: "#ffffff"
                style: Text.Outline
                styleColor: "#000000"
            }
        }
        BText {
            Layout.preferredWidth: 240
            readonly property var k: Theme.fxKinds.find(x => x.id === root.shownKind)
            text: k ? k.name + " — " + k.about : ""
            color: Theme.textDim
            wrapMode: Text.Wrap
            font.pixelSize: Math.max(10, Theme.fontSize - 2)
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: 6
        Flow {
            Layout.fillWidth: true
            spacing: 3
            Repeater {
                model: Theme.fxKinds
                SButton {
                    id: kb
                    required property var modelData
                    text: modelData.name
                    checked: Theme.fxKind === modelData.id
                    onClicked: Theme.set("wallpaper.effect.kind", modelData.id)
                    HoverHandler { onHoveredChanged: root.hover = hovered ? kb.modelData.id : (root.hover === kb.modelData.id ? "" : root.hover) }
                }
            }
        }
        SChoice {
            text: "Colour"
            labelWidth: 80
            visible: ["snow", "stars", "rain", "bubbles"].indexOf(Theme.fxKind) >= 0 || Theme.fxKind === "fireflies"
            model: [{ label: "White", value: "white" }, { label: "Accent", value: "accent" }, { label: "Black", value: "#101010" },
                    { label: "Ice", value: "#a8dcff" }, { label: "Gold", value: "#ffd36b" }, { label: "Pink", value: "#ff9ad5" }]
            current: Theme.fxColorMode
            onPicked: v => Theme.setUi("wallpaper.effect.color", v)
        }
        SSlider { text: "Amount"; labelWidth: 80; from: 0.25; to: 2.5; step: 0.05; value: Theme.fxDensity; displayScale: 100; suffix: "%"; onMoved: v => Theme.setUi("wallpaper.effect.density", v) }
        SSlider { text: "Speed"; labelWidth: 80; from: 0.25; to: 2.5; step: 0.05; value: Theme.fxSpeed; decimals: 2; suffix: "×"; onMoved: v => Theme.setUi("wallpaper.effect.speed", v) }
        SChoice {
            text: "Pixels"
            labelWidth: 80
            model: [{ label: "Smooth", value: 1 }, { label: "2", value: 2 }, { label: "3", value: 3 }, { label: "4", value: 4 }]
            current: Theme.fxPixel
            onPicked: v => Theme.setUi("wallpaper.effect.pixel", v)
        }
        BText {
            Layout.fillWidth: true
            visible: false
            color: Theme.textDim
            wrapMode: Text.Wrap
            font.pixelSize: Math.max(10, Theme.fontSize - 2)
        }
    }
}
