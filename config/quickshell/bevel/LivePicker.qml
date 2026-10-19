import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

// Live (animated) background chooser: a big preview, colour + palette, then every animation.
ColumnLayout {
    id: root
    spacing: 10
    Layout.fillWidth: true

    property bool xfce: false
    property string hover: ""
    readonly property bool liveOn: Theme.liveMode

    function pick(kind) {
        if (!root.liveOn) Theme.set("wallpaper.mode", "live");
        Theme.set("wallpaper.live.kind", kind);
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        // ---- preview
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 4
            Bevel {
                implicitWidth: 300
                implicitHeight: 300 * 9 / 16 + 6
                sunken: true
                fill: Theme.dark
                padding: 1
                LiveBackground {
                    id: bigPreview
                    anchors.fill: parent
                    kind: root.hover !== "" ? root.hover : Theme.liveKind
                    scaleRef: 1920
                }
                BText {
                    anchors.fill: parent
                    anchors.margins: 8
                    visible: bigPreview.failed || bigPreview.GraphicsInfo.api === GraphicsInfo.Software || fileCheck.missing
                    wrapMode: Text.Wrap
                    maximumLineCount: 8
                    elide: Text.ElideNone
                    color: "#ff8080"
                    font.pixelSize: Math.max(10, Theme.fontSize - 2)
                    text: bigPreview.GraphicsInfo.api === GraphicsInfo.Software
                          ? "Quickshell is drawing in software mode here, which can't run animations. Check that QT_QUICK_BACKEND isn't set to \"software\"."
                          : fileCheck.missing ? "The animation file is missing:\n" + fileCheck.path + "\n\nRun the installer again (./install.sh --no-pkgs)."
                          : "The animation couldn't load on this system:\n" + bigPreview.log
                }
            }
            // is the compiled shader where we look for it?
            Process {
                id: fileCheck
                property string path: String(bigPreview.fragmentShader).replace(/^file:\/\//, "")
                property bool missing: false
                property bool checked: false
                command: ["sh", "-c", "test -r \"$1\"", "sh", path]
                onPathChanged: running = true
                Component.onCompleted: running = true
                onExited: code => { missing = code !== 0; checked = true; }
            }
            // what's drawing it: helps when an animation stays black ("bevelctl doctor live" has more)
            BText {
                Layout.preferredWidth: 300
                color: Theme.textDim
                font.pixelSize: Math.max(9, Theme.fontSize - 4)
                readonly property var apis: ({ [GraphicsInfo.Unknown]: "unknown", [GraphicsInfo.Software]: "software", [GraphicsInfo.OpenGL]: "OpenGL",
                                               [GraphicsInfo.Vulkan]: "Vulkan", [GraphicsInfo.Null]: "nothing" })
                text: "Drawn with " + (apis[bigPreview.GraphicsInfo.api] || bigPreview.GraphicsInfo.api)
                      + (fileCheck.checked ? (fileCheck.missing ? " · shader file missing" : " · shader file found") : "")
                      + (bigPreview.failed ? " · failed: " + bigPreview.log.split("\n")[0] : "")
            }
            BText {
                Layout.preferredWidth: 300
                readonly property var k: Theme.liveKinds.find(x => x.id === (root.hover !== "" ? root.hover : Theme.liveKind))
                text: k ? k.name + " — " + k.about : ""
                font.bold: true
            }
            BText {
                Layout.preferredWidth: 300
                wrapMode: Text.Wrap
                maximumLineCount: 3
                color: Theme.textDim
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                text: "Moves on your desktop. The login and lock screens get a still frame."
            }
        }

        // ---- colour and motion
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 8
            RowLayout {
                spacing: 6
                BText { text: "Colour"; Layout.preferredWidth: 80 }
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: ["#2a5ea8", "#1d8fd6", "#2f8f8a", "#3f9a4a", "#9bbb2a", "#d8a520", "#d8662a", "#c0392b",
                                "#c03070", "#9b3fc0", "#5a4fcf", "#808080"]
                        Bevel {
                            id: sw
                            required property string modelData
                            width: 22; height: 22
                            sunken: Theme.liveColor.toLowerCase() === modelData
                            fill: modelData
                            depth: Math.min(2, Theme.bevel)
                            Rectangle {
                                anchors.fill: parent; anchors.margins: -3
                                color: "transparent"; border.color: Theme.text; border.width: 2
                                visible: sw.sunken
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Theme.set("wallpaper.live.color", sw.modelData) }
                        }
                    }
                }
            }
            SField {
                text: "Hex"
                labelWidth: 80
                value: Theme.liveColor
                onAccepted: t => { const v = t.trim(); if (/^#?[0-9a-fA-F]{6}$/.test(v)) Theme.set("wallpaper.live.color", (v[0] === "#" ? "" : "#") + v.toLowerCase()); }
            }
            RowLayout {
                spacing: 6
                BText { text: "Palette"; Layout.preferredWidth: 80; Layout.alignment: Qt.AlignTop; Layout.topMargin: 4 }
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: Theme.livePalettes
                        Bevel {
                            id: palBtn
                            required property var modelData
                            readonly property var cols: Theme.liveColors(Theme.liveColor, modelData.id)
                            readonly property bool on: Theme.livePalette === modelData.id
                            width: palRow.implicitWidth + 14
                            height: Theme.fontSize + 12
                            sunken: on
                            fill: on ? Theme.face2 : Theme.face
                            depth: Math.min(2, Theme.bevel)
                            Row {
                                id: palRow
                                anchors.centerIn: parent
                                spacing: 5
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Repeater {
                                        model: [2, 0, 1, 3]
                                        Rectangle { required property int modelData; width: 7; height: 12; color: palBtn.cols[modelData] }
                                    }
                                }
                                BText { text: palBtn.modelData.name; font.bold: palBtn.on; font.pixelSize: Math.max(10, Theme.fontSize - 1) }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Theme.set("wallpaper.live.palette", palBtn.modelData.id) }
                        }
                    }
                }
            }
            SSlider {
                text: "Speed"
                labelWidth: 80
                from: 0.2; to: 3; step: 0.1
                decimals: 1
                suffix: "×"
                value: Theme.liveSpeed
                onMoved: v => Theme.setUi("wallpaper.live.speed", v)
            }
            SChoice {
                text: "Pixels"
                labelWidth: 80
                model: [{ label: "Smooth", value: 1 }, { label: "2", value: 2 }, { label: "3", value: 3 }, { label: "4", value: 4 }, { label: "6", value: 6 }, { label: "8", value: 8 }]
                current: Theme.livePixel
                onPicked: v => Theme.set("wallpaper.live.pixel", v)
            }
            SChoice {
                text: "Frame rate"
                labelWidth: 80
                model: [{ label: "15", value: 15 }, { label: "30", value: 30 }, { label: "60", value: 60 }]
                current: Theme.liveFps
                onPicked: v => Theme.setUi("wallpaper.live.fps", v)
            }
            Flow {
                Layout.fillWidth: true
                spacing: 16
                SCheck { text: "90s dither"; checked: Theme.liveDither; onToggled: v => Theme.set("wallpaper.live.dither", v) }
                SCheck { text: "Pause on battery"; checked: Theme.sv("wallpaper.live.pauseOnBattery", false); onToggled: v => Theme.setUi("wallpaper.live.pauseOnBattery", v) }
                BText {
                    visible: Theme.sv("wallpaper.live.pauseOnBattery", false) && UPower.onBattery
                    text: "(paused now)"
                    color: Theme.textDim
                }
            }
        }
    }

    // ---- every animation (still frames; hover one to play it in the preview)
    BText { text: Theme.liveKinds.length + " animations — click one to use it, hover to preview"; color: Theme.textDim }
    GridLayout {
        id: cards
        Layout.fillWidth: true
        columns: Math.max(2, Math.floor(width / 150))
        columnSpacing: 6
        rowSpacing: 6
        Repeater {
            model: Theme.liveKinds
            Bevel {
                id: card
                required property var modelData
                readonly property bool chosen: root.liveOn && Theme.liveKind === modelData.id
                Layout.fillWidth: true
                implicitHeight: thumbBox.height + nameText.implicitHeight + 14
                sunken: chosen
                fill: chosen ? Theme.face2 : Theme.face
                depth: Math.min(2, Theme.bevel)
                Item {
                    id: thumbBox
                    x: 4; y: 4
                    width: parent.width - 8
                    height: Math.round(width * 9 / 16)
                    LiveBackground {
                        anchors.fill: parent
                        kind: card.modelData.id
                        scaleRef: 1920
                        running: false
                        cache: true
                        time: 6.0
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: card.chosen ? 2 : 1
                        border.color: card.chosen ? Theme.accent : (cardMa.containsMouse ? Theme.hi : Theme.lo)
                    }
                }
                BText {
                    id: nameText
                    anchors.top: thumbBox.bottom
                    anchors.topMargin: 3
                    x: 4
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                    text: (card.chosen ? "● " : "") + card.modelData.name
                    font.bold: card.chosen
                    font.pixelSize: Math.max(10, Theme.fontSize - 2)
                }
                MouseArea {
                    id: cardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse) root.hover = card.modelData.id;
                        else if (root.hover === card.modelData.id) root.hover = "";
                    }
                    onClicked: root.pick(card.modelData.id)
                }
            }
        }
    }
}
