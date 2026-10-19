import QtQuick

// Control-panel icons: the 9x pixel set (PixIcon). `off` swaps in the crossed-out version
// where there is one, otherwise greys the icon out. `color` is ignored (pixel icons have their own).
Item {
    id: ic
    property string kind: "gear"
    property color color
    property bool off: false
    implicitWidth: 16
    implicitHeight: 16
    readonly property var offKinds: ({ speaker: "mute", wifi: "wifi-off", bell: "bell-off" })
    readonly property string real: ic.off && ic.offKinds[ic.kind] ? ic.offKinds[ic.kind] : ic.kind
    PixIcon {
        anchors.fill: parent
        kind: ic.real
        opacity: ic.off && !ic.offKinds[ic.kind] ? 0.45 : 1
    }
}
