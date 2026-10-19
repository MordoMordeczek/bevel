import Quickshell
import QtQuick

// Plain sunken clock by default; style.lcdClock turns it into a green-glass LCD.
Item {
    id: root
    implicitWidth: label.implicitWidth + 16 + (chips.visible ? chips.width + 4 : 0)
    property bool pressed: false          // its menu is open

    // a running stopwatch / timer shows up next to the time (clock menu → "Show on the bar")
    readonly property bool showSw: Theme.sv("clock.onBar", true) && Ui.swActive
    readonly property bool showTm: Theme.sv("clock.onBar", true) && Ui.timerActive
    property real nowMs: Date.now()
    Timer { interval: 250; repeat: true; running: root.showSw || root.showTm; triggeredOnStart: true; onTriggered: root.nowMs = Date.now() }
    Row {
        id: chips
        visible: root.showSw || root.showTm
        height: parent.height
        spacing: 4
        Chip { visible: root.showSw; icon: "clock"; paused: Ui.swStart === 0; text: Ui.clockText(Ui.swElapsed(root.nowMs)) }
        Chip {
            visible: root.showTm
            icon: "bell"
            paused: Ui.timerEnd === 0
            readonly property real ms: Ui.timerLeft(root.nowMs)
            urgent: Ui.timerEnd > 0 && ms < 10000
            text: Ui.clockText(Math.ceil(ms / 1000) * 1000)
        }
    }
    component Chip: Bevel {
        id: chip
        property string icon: "clock"
        property string text: ""
        property bool paused: false
        property bool urgent: false
        height: parent.height
        width: chipRow.implicitWidth + 12
        sunken: true
        depth: 1
        fill: urgent ? Theme.accent : "transparent"
        radius: Theme.radiusSm
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4
            PixIcon { kind: chip.icon; width: 14; height: 14; anchors.verticalCenter: parent.verticalCenter; opacity: chip.paused ? 0.5 : 1 }
            BText {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                font.family: Theme.barFont
                font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
                font.pixelSize: Theme.barFontSize
                font.bold: true
                color: chip.urgent ? Theme.accentText : (chip.paused ? Theme.textDim : Theme.text)
            }
        }
    }

    SystemClock {
        id: clock
        precision: Theme.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    readonly property string fmt: {
        let f = Theme.clockFormat;
        if (Theme.clockSeconds && f.indexOf("ss") < 0)
            f += ":ss";
        return (Theme.showDate ? "ddd d · " : "") + f;
    }

    Item {
        id: timeBox
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: label.implicitWidth + 16
    Bevel {
        anchors.fill: parent
        visible: !Theme.lcdClock
        sunken: true
        depth: root.pressed ? 2 : 1
        fill: root.pressed ? Theme.face2 : "transparent"
        radius: Theme.radiusSm
    }
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        visible: Theme.lcdClock
        color: Theme.lcdBg
        radius: Theme.radiusSm
        border.color: Theme.lo
    }

    BText {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, root.fmt)
        font.family: Theme.lcdClock ? Theme.mono : Theme.barFont
        font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
        font.pixelSize: Theme.lcdClock ? Theme.barFontSize + 6 : Theme.barFontSize
        font.bold: !Theme.lcdClock
        color: Theme.lcdClock ? Theme.lcd : Theme.text
    }
    }
}
