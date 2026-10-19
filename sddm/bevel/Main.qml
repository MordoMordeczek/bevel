import QtQuick

// Bevel — SDDM login screen matching the Bevel Hyprland rice.
// Colors and wallpaper are synced by `bevelctl apply` into theme.conf.user + background.png.
Rectangle {
    id: root
    width: 1600
    height: 900
    color: pal.dark

    // everything is designed for a 900 px tall screen and scaled from there
    readonly property real s: Math.max(0.6, height / 900)

    function cfg(key, def) {
        const v = config[key];
        return (v === undefined || v === null || v === "") ? def : v;
    }

    QtObject {
        id: pal
        property color face: root.cfg("face", "#c0c0c0")
        property color face2: root.cfg("face2", "#dfdfdf")
        property color hi: root.cfg("hi", "#ffffff")
        property color lo: root.cfg("lo", "#808080")
        property color dark: root.cfg("dark", "#0a0a0a")
        property color base: root.cfg("base", "#ffffff")
        property color text: root.cfg("text", "#000000")
        property color textDim: root.cfg("textDim", "#404040")
        property color accent: root.cfg("accent", "#000080")
        property color accent2: root.cfg("accent2", "#1084d0")
        property color accentText: root.cfg("onAccent", "#ffffff")
    }

    readonly property bool darkUi: pal.face.hslLightness < 0.5
    readonly property color errorColor: darkUi ? "#ff7a7a" : "#b00020"

    FontLoader { id: pixel; source: "fonts/PixelifySans.ttf" }
    readonly property string uiFont: pixel.status === FontLoader.Ready ? pixel.name : "monospace"
    readonly property string barFont: root.cfg("barFont", "JetBrains Mono")

    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string message: ""

    Connections {
        target: sddm
        function onLoginFailed() {
            root.message = "The password you typed is incorrect.";
            password.text = "";
            password.forceActiveFocus();
            shake.start();
        }
        function onLoginSucceeded() { root.message = ""; }
    }

    function doLogin() {
        root.message = "Logging on…";
        sddm.login(username.text, password.text, root.sessionIndex);
    }

    // session names, read through the model's "name" role
    Repeater {
        id: sessions
        model: sessionModel
        delegate: Item {
            required property string name
            readonly property string sname: name
        }
    }
    function sessionName(i) {
        if (sessions.count === 0)
            return "Hyprland";
        const it = sessions.itemAt(Math.min(i, sessions.count - 1));
        return it && it.sname ? it.sname : "Session " + (i + 1);
    }

    // ---------------------------------------------------------------- wallpaper
    Image {
        anchors.fill: parent
        source: root.cfg("background", "background.png")
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        smooth: true
    }
    Image {
        // dither dim, like the classic log-on screen
        anchors.fill: parent
        source: "dither.png"
        fillMode: Image.Tile
        smooth: false
        opacity: Number(root.cfg("dim", "0.55"))
    }

    // ---------------------------------------------------------------- top bar
    Bevel {
        pal: pal
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 * root.s }
        height: 30 * root.s

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * root.s
            Text {
                text: sddm.hostName
                color: pal.text
                font.family: root.barFont
                font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
                font.bold: true
                font.pixelSize: 13 * root.s
            }
            Text {
                text: "· Hyprland"
                color: pal.textDim
                font.family: root.barFont
                font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
                font.pixelSize: 13 * root.s
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 4 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * root.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: keyboard.layouts.length > 1
                text: keyboard.layouts.length > 0 ? keyboard.layouts[keyboard.currentLayout].shortName.toUpperCase() : ""
                color: pal.text
                font.family: root.barFont
                font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
                font.bold: true
                font.pixelSize: 13 * root.s
            }
            Bevel {
                pal: pal
                sunken: true
                depth: 1
                fill: "transparent"
                width: clock.implicitWidth + 20 * root.s
                height: 22 * root.s
                Text {
                    id: clock
                    anchors.centerIn: parent
                    color: pal.text
                    font.family: root.barFont
                    font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
                    font.bold: true
                    font.pixelSize: 13 * root.s
                    text: Qt.formatDateTime(new Date(), "ddd d · HH:mm")
                    Timer {
                        interval: 5000; running: true; repeat: true
                        onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd d · HH:mm")
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- log-on dialog
    Bevel {
        id: dlg
        pal: pal
        width: 470 * root.s
        height: col.implicitHeight + 8 * root.s
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: shakeX

        property real shakeX: 0
        SequentialAnimation {
            id: shake
            loops: 2
            NumberAnimation { target: dlg; property: "shakeX"; to: 10; duration: 40 }
            NumberAnimation { target: dlg; property: "shakeX"; to: -10; duration: 80 }
            NumberAnimation { target: dlg; property: "shakeX"; to: 0; duration: 40 }
        }

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 2 * root.s
            spacing: 0

            // title strip
            Rectangle {
                width: parent.width
                height: 24 * root.s
                color: pal.accent
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Log On to " + sddm.hostName
                    color: pal.accentText
                    font.family: root.uiFont
                    font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
                    font.bold: true
                    font.pixelSize: 14 * root.s
                }
            }

            // banner
            Rectangle {
                width: parent.width
                height: 84 * root.s
                color: pal.dark
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 22 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16 * root.s
                    // four-pane logo in the theme's colors
                    Grid {
                        anchors.verticalCenter: parent.verticalCenter
                        columns: 2
                        spacing: 3 * root.s
                        Rectangle { width: 18 * root.s; height: 18 * root.s; color: pal.accent }
                        Rectangle { width: 18 * root.s; height: 18 * root.s; color: pal.accent2 }
                        Rectangle { width: 18 * root.s; height: 18 * root.s; color: Qt.rgba(1, 1, 1, 0.85) }
                        Rectangle { width: 18 * root.s; height: 18 * root.s; color: Qt.rgba(1, 1, 1, 0.4) }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2 * root.s
                        Row {
                            spacing: 8 * root.s
                            Text { text: "Arch"; color: "#f4f4f4"; font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }; font.family: root.uiFont; font.bold: true; font.pixelSize: 34 * root.s }
                            Text { text: "Linux"; color: pal.accent2; font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }; font.family: root.uiFont; font.pixelSize: 34 * root.s }
                        }
                        Text { text: "Hyprland · Bevel edition"; color: Qt.rgba(1, 1, 1, 0.65); font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }; font.family: root.uiFont; font.pixelSize: 13 * root.s }
                    }
                }
            }
            // accent rule under the banner
            Rectangle { width: parent.width; height: 4 * root.s; color: pal.accent }

            Item { width: 1; height: 16 * root.s }

            // key icon + prompt
            Row {
                x: 18 * root.s
                spacing: 14 * root.s
                Image {
                    // 9x pixel keys
                    width: 32 * Math.max(1, Math.round(root.s)); height: width
                    source: "icons/key.png"
                    smooth: false
                    fillMode: Image.PreserveAspectFit
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: dlg.width - 100 * root.s
                    wrapMode: Text.Wrap
                    text: "Type a user name and password to log on."
                    color: pal.text
                    font.family: root.uiFont
                    font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
                    font.pixelSize: 14 * root.s
                }
            }

            Item { width: 1; height: 14 * root.s }

            // fields
            Grid {
                x: 68 * root.s
                columns: 2
                rowSpacing: 8 * root.s
                columnSpacing: 10 * root.s
                verticalItemAlignment: Grid.AlignVCenter

                Text { text: "User name:"; color: pal.text; font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }; font.family: root.uiFont; font.pixelSize: 14 * root.s; width: 92 * root.s }
                Bevel {
                    pal: pal; sunken: true; fill: pal.base
                    width: dlg.width - 190 * root.s; height: 26 * root.s
                    TextInput {
                        id: username
                        anchors.fill: parent
                        anchors.leftMargin: 5 * root.s
                        verticalAlignment: TextInput.AlignVCenter
                        text: userModel.lastUser
                        color: pal.text
                        selectionColor: pal.accent
                        selectedTextColor: pal.accentText
                        font.family: root.uiFont
                        font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
                        font.pixelSize: 14 * root.s
                        clip: true
                        selectByMouse: true
                        KeyNavigation.tab: password
                        Keys.onReturnPressed: password.forceActiveFocus()
                        Keys.onEnterPressed: password.forceActiveFocus()
                    }
                }

                Text { text: "Password:"; color: pal.text; font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }; font.family: root.uiFont; font.pixelSize: 14 * root.s }
                Bevel {
                    pal: pal; sunken: true; fill: pal.base
                    width: dlg.width - 190 * root.s; height: 26 * root.s
                    TextInput {
                        id: password
                        anchors.fill: parent
                        anchors.leftMargin: 5 * root.s
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "*"
                        color: pal.text
                        selectionColor: pal.accent
                        selectedTextColor: pal.accentText
                        font.family: root.barFont
                        font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
                        font.pixelSize: 13 * root.s
                        clip: true
                        focus: true
                        KeyNavigation.tab: sessionBtn
                        KeyNavigation.backtab: username
                        Keys.onReturnPressed: root.doLogin()
                        Keys.onEnterPressed: root.doLogin()
                    }
                }

                Text { text: "Session:"; color: pal.text; font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }; font.family: root.uiFont; font.pixelSize: 14 * root.s }
                BButton {
                    id: sessionBtn
                    pal: pal; s: root.s; fontFamily: root.uiFont
                    width: dlg.width - 190 * root.s
                    text: (sessions.count > 1 ? "◂  " : "") + root.sessionName(root.sessionIndex) + (sessions.count > 1 ? "  ▸" : "")
                    onClicked: root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, sessions.count)
                    Keys.onLeftPressed: root.sessionIndex = (root.sessionIndex + sessions.count - 1) % Math.max(1, sessions.count)
                    Keys.onRightPressed: clicked()
                    KeyNavigation.tab: okBtn
                }
            }

            Item { width: 1; height: 10 * root.s }

            // message line
            Text {
                x: 68 * root.s
                height: 18 * root.s
                text: root.message !== "" ? root.message : (keyboard.capsLock ? "Caps Lock is on." : "")
                color: root.message.indexOf("incorrect") >= 0 ? root.errorColor : pal.textDim
                font.family: root.uiFont
                font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
                font.bold: root.message.indexOf("incorrect") >= 0
                font.pixelSize: 13 * root.s
            }

            Item { width: 1; height: 6 * root.s }

            // buttons
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 14 * root.s
                spacing: 8 * root.s
                BButton { id: okBtn; pal: pal; s: root.s; fontFamily: root.uiFont; text: "OK"; isDefault: true; onClicked: root.doLogin(); KeyNavigation.tab: rebootBtn }
                BButton { id: rebootBtn; pal: pal; s: root.s; fontFamily: root.uiFont; text: "Restart"; icon: "restart"; visible: sddm.canReboot; onClicked: sddm.reboot(); KeyNavigation.tab: offBtn }
                BButton { id: offBtn; pal: pal; s: root.s; fontFamily: root.uiFont; text: "Shut Down…"; icon: "power"; visible: sddm.canPowerOff; onClicked: sddm.powerOff(); KeyNavigation.tab: username }
            }

            Item { width: 1; height: 14 * root.s }
        }
    }

    // ---------------------------------------------------------------- hint
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18 * root.s
        text: "Enter log on  ·  Tab next field  ·  ◂ ▸ change session"
        color: Qt.rgba(1, 1, 1, 0.8)
        font.family: root.uiFont
        font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
        font.pixelSize: 12 * root.s
        style: Text.Raised
        styleColor: "#000000"
    }

    Component.onCompleted: {
        if (username.text === "")
            username.forceActiveFocus();
        else
            password.forceActiveFocus();
    }
}
