import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Super+V — clipboard history (cliphist). Pick an entry to copy it again; Del removes it.
Scope {
    id: root
    property bool open: false
    property var items: []          // [{id, text, image}]
    property string query: ""
    property int sel: 0
    property bool missing: false
    readonly property var shown: {
        const q = root.query.trim().toLowerCase();
        return q === "" ? root.items : root.items.filter(i => i.text.toLowerCase().indexOf(q) >= 0);
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.open ? root.open = false : root.show(); }
        function show(): void { root.show(); }
    }
    function show() {
        root.query = "";
        root.sel = 0;
        root.open = true;
        listProc.running = true;
    }

    Process {
        id: listProc
        command: ["sh", "-c", "command -v cliphist >/dev/null || exit 3; cliphist list | head -n 200"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    const id = line.slice(0, tab), body = line.slice(tab + 1);
                    const m = body.match(/^\[\[ binary data (.*) \]\]$/);
                    out.push({ id: id, text: m ? "Image  " + m[1] : body, image: !!m, raw: line });
                }
                root.items = out;
            }
        }
        onExited: code => root.missing = code === 3
    }
    Process { id: actProc; onExited: if (root.open) listProc.running = true }
    function pick(it) {
        if (!it) return;
        root.open = false;
        actProc.command = ["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "sh", it.raw];
        actProc.running = true;
    }
    function remove(it) {
        if (!it) return;
        actProc.command = ["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", it.raw];
        actProc.running = true;
    }
    function wipe() {
        actProc.command = ["cliphist", "wipe"];
        actProc.running = true;
    }

    LazyLoader {
        active: root.open
        PanelWindow {
            // on the monitor you're using (Settings → Windows & display has the main one)
            screen: Ui.focusedScreen
            PopupHold {}
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "bevel-clipboard"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            MouseArea { anchors.fill: parent; onClicked: root.open = false }

            Bevel {
                anchors.centerIn: parent
                width: 520
                height: 460
                radius: Theme.radius
                fillOpacity: 1
                padding: 2
                MouseArea { anchors.fill: parent }
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Theme.fontSize + 10
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.accent }
                            GradientStop { position: 1; color: Theme.accent2 }
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 4
                            PixIcon { kind: "note"; width: 16; height: 16 }
                            BText { Layout.fillWidth: true; text: "Clipboard"; color: Theme.accentText; font.bold: true }
                            BText { text: "×"; color: Theme.accentText; font.bold: true; MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.open = false } }
                        }
                    }
                    Bevel {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        implicitHeight: Theme.fontSize + 12
                        sunken: true
                        fill: Theme.base
                        padding: 2
                        TextInput {
                            id: search
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            focus: true
                            Component.onCompleted: forceActiveFocus()
                            onTextChanged: { root.query = text; root.sel = 0; }
                            Keys.onPressed: event => {
                                const n = root.shown.length;
                                if (event.key === Qt.Key_Escape) root.open = false;
                                else if (event.key === Qt.Key_Down) root.sel = Math.min(n - 1, root.sel + 1);
                                else if (event.key === Qt.Key_Up) root.sel = Math.max(0, root.sel - 1);
                                else if (event.key === Qt.Key_PageDown) root.sel = Math.min(n - 1, root.sel + 8);
                                else if (event.key === Qt.Key_PageUp) root.sel = Math.max(0, root.sel - 8);
                                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.pick(root.shown[root.sel]);
                                else if (event.key === Qt.Key_Delete) root.remove(root.shown[root.sel]);
                                else return;
                                event.accepted = true;
                                list.positionViewAtIndex(root.sel, ListView.Contain);
                            }
                            BText { visible: search.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Search your clipboard…"; color: Theme.textDim }
                        }
                    }
                    Bevel {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        sunken: true
                        fill: Theme.base
                        padding: 1
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: wheel => {
                                const dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 2;
                                list.contentY = Math.max(0, Math.min(Math.max(0, list.contentHeight - list.height), list.contentY - dy));
                            }
                            ListView {
                                id: list
                                anchors.fill: parent
                                clip: true
                                interactive: false
                                model: root.shown
                                delegate: Rectangle {
                                    id: row
                                    required property var modelData
                                    required property int index
                                    width: list.width
                                    height: Theme.fontSize + 16
                                    color: index === root.sel ? Theme.accent : (rowMa.containsMouse ? Theme.face2 : "transparent")
                                    PixIcon { id: ico; x: 6; anchors.verticalCenter: parent.verticalCenter; kind: row.modelData.image ? "picture" : "note"; width: 16; height: 16 }
                                    BText {
                                        anchors.left: ico.right
                                        anchors.leftMargin: 8
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: row.modelData.text.replace(/\s+/g, " ")
                                        color: row.index === root.sel ? Theme.accentText : Theme.text
                                    }
                                    MouseArea {
                                        id: rowMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: mouse => mouse.button === Qt.RightButton ? root.remove(row.modelData) : root.pick(row.modelData)
                                    }
                                }
                            }
                        }
                        BText {
                            anchors.centerIn: parent
                            visible: root.shown.length === 0
                            text: root.missing ? "Clipboard history needs cliphist:  sudo pacman -S cliphist" : (root.query !== "" ? "Nothing matches." : "Copy something and it shows up here.")
                            color: Theme.textDim
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        Layout.bottomMargin: 8
                        BText { Layout.fillWidth: true; text: "Enter: copy  ·  Del / right-click: remove  ·  Esc: close"; color: Theme.textDim; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
                        SButton { text: "Clear all"; onClicked: root.wipe() }
                    }
                }
            }
        }
    }
}
