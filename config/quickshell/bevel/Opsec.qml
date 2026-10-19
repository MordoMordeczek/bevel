import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// The OPSEC easter egg (About → click the BEVEL logo). Hacker intro, a fresh workspace full of
// very serious green terminals, and a "WELCOME TO OPSEC" window. Close that window and it all goes away.
Scope {
    id: root
    readonly property bool wayland: !!Quickshell.env("WAYLAND_DISPLAY")
    property string phase: ""          // "" | intro | live
    property bool welcome: false

    function begin() {
        if (root.phase !== "") return;
        if (root.wayland) { root.phase = "intro"; introTimer.restart(); }
        else root.go();
    }
    function go() {
        root.phase = "live";
        Quickshell.execDetached(["bevelctl", "opsec", "start"]);
        welcomeTimer.restart();          // after the workspace switch, so it opens over there
    }
    function end() {
        if (root.phase === "") return;
        root.phase = "";
        root.welcome = false;
        Quickshell.execDetached(["bevelctl", "opsec", "stop"]);
    }
    Timer { id: introTimer; interval: 3600; onTriggered: root.go() }
    Timer { id: welcomeTimer; interval: 1500; onTriggered: root.welcome = true }

    Connections {
        target: Ui
        function onOpsecChanged() { if (Ui.opsec) { Ui.opsec = false; root.begin(); } }
    }
    IpcHandler {
        target: "opsec"
        function start(): void { root.begin(); }
        function stop(): void { root.end(); }
    }

    // ---------------------------------------------------------------- intro (Hyprland)
    LazyLoader {
        active: root.phase === "intro" && root.wayland
        PanelWindow {
            id: intro
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            WlrLayershell.namespace: "bevel-opsec"
            WlrLayershell.layer: WlrLayer.Overlay

            property int t: 0
            Timer { interval: 60; running: true; repeat: true; onTriggered: intro.t++ }
            readonly property var boot: [
                "> initializing hoodie.sys ............ OK",
                "> mounting /dev/sunglasses ........... OK",
                "> spoofing location: 127.0.0.1 ....... OK",
                "> routing through 7 proxies .......... OK",
                "> disabling webcam with tape ......... OK",
                "> loading cool green font ............ OK"
            ]
            Column {
                x: 40; y: 40
                spacing: 4
                Repeater {
                    model: intro.boot
                    Text {
                        required property string modelData
                        required property int index
                        visible: intro.t > 4 + index * 5
                        text: modelData
                        color: "#33ff66"
                        font.family: "monospace"
                        font.pixelSize: 16
                    }
                }
            }
            Column {
                anchors.centerIn: parent
                spacing: 18
                visible: intro.t > 34
                Text {
                    id: big
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "OPSEC LARP STARTING"
                    color: intro.t % 6 < 3 ? "#33ff66" : "#ff3355"
                    font.family: "monospace"
                    font.bold: true
                    font.pixelSize: 64
                    // a little glitch jitter
                    transform: Translate { x: (intro.t % 7 === 0) ? 6 : (intro.t % 11 === 0 ? -5 : 0) }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 520; height: 22
                    color: "transparent"
                    border.color: "#33ff66"
                    Rectangle {
                        x: 3; y: 3
                        height: parent.height - 6
                        width: Math.min(parent.width - 6, (parent.width - 6) * Math.max(0, intro.t - 34) / 24)
                        color: "#33ff66"
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "do not tell anyone. especially not on tiktok."
                    color: "#1f9c3f"
                    font.family: "monospace"
                    font.pixelSize: 16
                }
            }
            // scanlines
            Repeater {
                model: Math.ceil(intro.height / 4)
                Rectangle { required property int index; y: index * 4; width: intro.width; height: 1; color: "#000000"; opacity: 0.35 }
            }
        }
    }

    // ---------------------------------------------------------------- WELCOME TO OPSEC
    LazyLoader {
        active: root.phase === "live" && root.welcome
        FloatingWindow {
            id: w
            title: "WELCOME TO OPSEC"
            implicitWidth: 560
            implicitHeight: 330
            color: "black"
            onClosed: root.end()

            property int t: 0
            Timer { interval: 100; running: true; repeat: true; onTriggered: w.t++ }
            readonly property var status: [
                "VPN ............ 7 layers deep", "Hoodie ......... ON", "Sunglasses ..... ON (indoors)",
                "IP ............. 127.0.0.1 (untraceable)", "Firewall ....... on fire", "Threat level ... TikTok"
            ]

            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                color: "black"
                border.color: "#33ff66"
                border.width: 2

                Text {
                    id: head
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 18
                    text: "WELCOME TO OPSEC"
                    color: w.t % 10 < 7 ? "#33ff66" : "#b6ffc9"
                    font.family: "monospace"
                    font.bold: true
                    font.pixelSize: 38
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: head.bottom
                    anchors.topMargin: 2
                    text: "you are now 100% anonymous*"
                    color: "#1f9c3f"
                    font.family: "monospace"
                    font.pixelSize: 14
                }
                Column {
                    x: 40
                    anchors.top: head.bottom
                    anchors.topMargin: 34
                    spacing: 3
                    Repeater {
                        model: w.status
                        Text {
                            required property string modelData
                            required property int index
                            visible: w.t > index * 3
                            text: "[+] " + modelData
                            color: "#33ff66"
                            font.family: "monospace"
                            font.pixelSize: 15
                        }
                    }
                    Text {
                        text: "hacking the mainframe… " + Math.min(99, Math.floor(w.t * 1.7) % 100) + "%" + (w.t % 6 < 3 ? " █" : "")
                        color: "#b6ffc9"
                        font.family: "monospace"
                        font.pixelSize: 15
                    }
                }
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 12
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                    text: "*not really"
                    color: "#1f6c33"
                    font.family: "monospace"
                    font.pixelSize: 11
                }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                    width: 120; height: 34
                    color: closeMa.containsMouse ? "#33ff66" : "black"
                    border.color: "#33ff66"
                    border.width: 2
                    Text {
                        anchors.centerIn: parent
                        text: "[ CLOSE ]"
                        color: closeMa.containsMouse ? "black" : "#33ff66"
                        font.family: "monospace"
                        font.bold: true
                        font.pixelSize: 16
                    }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.end()
                    }
                }
            }
            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.end()
            }
        }
    }
}
