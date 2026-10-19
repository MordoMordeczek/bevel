import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

// Notification daemon + popups. Click a popup to dismiss it; Super+N clears all.
Scope {
    id: root

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        onNotification: n => {
            n.tracked = true;
            NotifHistory.add({ appName: n.appName, summary: n.summary, body: n.body, appIcon: n.appIcon,
                               critical: n.urgency === NotificationUrgency.Critical });
        }
    }

    IpcHandler {
        target: "notifications"
        function clear(): void {
            const list = server.trackedNotifications.values.slice();
            for (let i = 0; i < list.length; i++)
                list[i].dismiss();
        }
    }

    PanelWindow {
        id: win
        // pop-ups on the main display, or on whichever one you're using (Notifications & OSD)
        // picked when the first pop-up appears, so they don't hop screens while you read them
        readonly property bool want: server.trackedNotifications.values.length > 0 && !Theme.sv("notifications.dnd", false)
        property var where: null
        onWantChanged: if (want) where = Theme.sv("notifications.screen", "focused") === "primary" ? Ui.primaryScreen : Ui.focusedScreen
        screen: where || Ui.primaryScreen
        visible: want
        anchors {
            top: Theme.barTop
            bottom: !Theme.barTop
            right: true
        }
        margins {
            top: Theme.barTop ? Theme.gapsOut : 0
            bottom: Theme.barTop ? 0 : Theme.gapsOut
            right: Theme.gapsOut
        }
        exclusiveZone: 0
        implicitWidth: 340
        implicitHeight: Math.max(1, stack.implicitHeight)
        color: "transparent"
        WlrLayershell.namespace: "bevel-notifications"
        WlrLayershell.layer: WlrLayer.Overlay

        Column {
            id: stack
            width: parent.width
            spacing: 6

            Repeater {
                // newest first, at most 4 on screen
                model: server.trackedNotifications.values.slice().reverse().slice(0, 4)

                Bevel {
                    id: card
                    required property var modelData
                    readonly property var n: modelData
                    readonly property bool critical: n.urgency === NotificationUrgency.Critical
                    width: stack.width
                    height: body.implicitHeight + 10
                    radius: Theme.radius
                    fillOpacity: Math.max(Theme.panelOpacity, 0.92)
                    padding: 2

                    Timer {
                        running: !card.critical
                        interval: card.n.expireTimeout > 0 ? card.n.expireTimeout : Theme.notifTimeout
                        onTriggered: card.n.expire()
                    }

                    ColumnLayout {
                        id: body
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: Theme.fontSize + 8
                            color: card.critical ? "#aa2222" : Theme.accent
                            radius: Theme.radiusSm
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                IconImage {
                                    visible: card.n.appIcon !== ""
                                    implicitSize: Theme.fontSize
                                    source: card.n.appIcon !== "" ? Quickshell.iconPath(card.n.appIcon, true) : ""
                                }
                                BText {
                                    Layout.fillWidth: true
                                    text: card.n.appName || "Notification"
                                    font.bold: true
                                    color: card.critical ? "#ffffff" : Theme.accentText
                                }
                                BText {
                                    text: "×"
                                    color: card.critical ? "#ffffff" : Theme.accentText
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 6
                            Layout.rightMargin: 6
                            spacing: 8
                            Image {
                                visible: card.n.image !== ""
                                source: card.n.image
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                BText {
                                    Layout.fillWidth: true
                                    text: card.n.summary
                                    font.bold: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: card.n.body
                                    color: Theme.text
                                    font.family: Theme.font
                                    font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
                                    font.pixelSize: Theme.fontSize
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            Layout.leftMargin: 6
                            Layout.bottomMargin: 4
                            spacing: 4
                            visible: card.n.actions.length > 0
                            Repeater {
                                model: card.n.actions
                                SButton {
                                    required property var modelData
                                    text: modelData.text
                                    onClicked: modelData.invoke()
                                }
                            }
                        }
                        Item { implicitHeight: 2 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: card.n.dismiss()
                    }
                }
            }
        }
    }
}
