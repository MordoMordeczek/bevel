import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// Settings → Desktop style → Dock: the pinned apps, in order. Arrows move one, × unpins it,
// "Add apps" opens a searchable list of everything installed.
ColumnLayout {
    id: ed
    Layout.fillWidth: true
    spacing: 6
    property bool adding: false
    property string query: ""

    function entryFor(id) {
        if (!id) return null;
        return DesktopEntries.byId(id) || DesktopEntries.byId(id.toLowerCase())
            || (DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(id) : null);
    }
    function idOf(e) { return e.id || e.name; }
    readonly property var apps: {
        const q = ed.query.trim().toLowerCase();
        const l = DesktopEntries.applications.values.filter(e => !e.noDisplay
            && (q === "" || (e.name || "").toLowerCase().indexOf(q) >= 0 || (e.genericName || "").toLowerCase().indexOf(q) >= 0));
        return l.slice().sort((a, b) => (a.name || "").localeCompare(b.name || ""));
    }

    BText { text: "Pinned apps"; font.bold: true }
    // the pinned apps as icon cards
    Flow {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: Theme.dockPinned
            Bevel {
                id: card
                required property string modelData
                required property int index
                readonly property var entry: ed.entryFor(modelData)
                width: 96
                height: 92
                radius: Theme.radiusSm
                IconImage {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 8
                    implicitSize: 32
                    source: Quickshell.iconPath(card.entry && card.entry.icon ? card.entry.icon : card.modelData, "application-x-executable")
                }
                BText {
                    x: 4; y: 44
                    width: parent.width - 8
                    horizontalAlignment: Text.AlignHCenter
                    text: card.entry ? card.entry.name : card.modelData
                    font.pixelSize: Math.max(10, Theme.fontSize - 2)
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    spacing: 2
                    Mini { label: "◂"; on: card.index > 0; onHit: Theme.dockMove(card.modelData, -1) }
                    Mini { label: "×"; on: true; onHit: Theme.dockUnpin(card.modelData) }
                    Mini { label: "▸"; on: card.index < Theme.dockPinned.length - 1; onHit: Theme.dockMove(card.modelData, 1) }
                }
            }
        }
        // the "add" card
        Bevel {
            width: 96
            height: 92
            radius: Theme.radiusSm
            sunken: ed.adding || addMa.pressed
            BText { anchors.centerIn: parent; anchors.verticalCenterOffset: -8; text: "+"; font.pixelSize: Theme.fontSize + 14; font.bold: true }
            BText { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; text: "Add apps"; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
            MouseArea { id: addMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ed.adding = !ed.adding }
        }
    }

    // ---- the app list
    ColumnLayout {
        visible: ed.adding
        Layout.fillWidth: true
        spacing: 4
        Bevel {
            Layout.fillWidth: true
            implicitHeight: Theme.fontSize + 12
            sunken: true
            fill: Theme.base
            radius: Theme.radiusSm
            padding: 2
            TextInput {
                id: search
                anchors.fill: parent
                anchors.leftMargin: 4
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                clip: true
                onTextChanged: ed.query = text
                BText { visible: search.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Search your apps…"; color: Theme.textDim }
            }
        }
        Bevel {
            Layout.fillWidth: true
            implicitHeight: 230
            sunken: true
            fill: Theme.base
            padding: 1
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    const dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 2;
                    lv.contentY = Math.max(0, Math.min(Math.max(0, lv.contentHeight - lv.height), lv.contentY - dy));
                }
                ListView {
                    id: lv
                    anchors.fill: parent
                    clip: true
                    interactive: false
                    model: ed.apps
                    delegate: Rectangle {
                        id: arow
                        required property var modelData
                        readonly property bool pinned: Theme.dockPinned.indexOf(ed.idOf(modelData)) >= 0
                        width: lv.width
                        height: 30
                        color: ama.containsMouse ? Theme.face2 : "transparent"
                        IconImage {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 20
                            source: Quickshell.iconPath(arow.modelData.icon || "", "application-x-executable")
                        }
                        BText {
                            x: 34
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 120
                            text: arow.modelData.name + (arow.modelData.genericName ? "  ·  " + arow.modelData.genericName : "")
                        }
                        BText {
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: arow.pinned ? "✓ in the dock" : "+ add"
                            color: arow.pinned ? Theme.textDim : Theme.accent
                            font.bold: !arow.pinned
                        }
                        MouseArea {
                            id: ama
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: arow.pinned ? Theme.dockUnpin(ed.idOf(arow.modelData)) : Theme.dockPin(ed.idOf(arow.modelData))
                        }
                    }
                }
            }
        }
        BText {
            text: "Tip: right-click any icon in the dock to pin, move or close it."
            color: Theme.textDim
            font.pixelSize: Math.max(10, Theme.fontSize - 2)
        }
    }

    component Mini: Bevel {
        id: mini
        property string label: ""
        property bool on: true
        signal hit()
        width: 22; height: 18
        radius: Theme.radiusSm
        depth: 1
        sunken: mma.pressed
        opacity: on ? 1 : 0.35
        BText { anchors.centerIn: parent; text: mini.label; font.pixelSize: Math.max(10, Theme.fontSize - 2); font.bold: true }
        MouseArea { id: mma; anchors.fill: parent; enabled: mini.on; onClicked: mini.hit() }
    }
}
