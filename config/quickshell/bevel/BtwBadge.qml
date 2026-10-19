import Quickshell
import QtQuick

// "I use Arch btw" — click it for a second opinion.
Item {
    id: badge
    visible: Theme.btw
    implicitWidth: Theme.btw ? label.implicitWidth + 12 : 0
    implicitHeight: Theme.barFontSize + 8

    readonly property var replies: [
        "Yes. Everyone knows.", "We noticed.", "Have you tried telling people?",
        "pacman -Syu and chill.", "The wiki is proud of you.", "Certified 'it works on my machine'.",
        "Your keyboard has a special key for that, right?", "Achievement unlocked: mentioned it again."
    ]

    Bevel {
        anchors.fill: parent
        sunken: true
        depth: 1
        fill: Theme.accent
        radius: Theme.radiusSm
    }
    BarText {
        id: label
        anchors.centerIn: parent
        text: Theme.btwLabel
        color: Theme.accentText
        font.pixelSize: Math.max(10, Theme.barFontSize - 1)
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["notify-send", "-a", "Bevel", Theme.btwLabel + ".",
                                            badge.replies[Math.floor(Math.random() * badge.replies.length)]])
    }
}
