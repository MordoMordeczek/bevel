import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Super+I — every knob of the rice. Changes are written through bevelctl
// (debounced) and apply live: bar, menus, kitty, Hyprland, Dolphin, GTK.
Scope {
    id: root
    property bool open: false
    property int page: 15

    IpcHandler {
        target: "settings"
        function toggle(): void { root.open = !root.open; }
        function show(): void { root.open = true; }
        function hide(): void { root.open = false; }
    }

    // Which desktop this window was opened in. Shared pages (colours, wallpaper, login, touchpad)
    // show everywhere; the rest only where they do something.
    readonly property bool xfce: false
    // idx = position in the page stack below; sidebar order = order of this list
    readonly property var allPages: [
        { name: "Wallpaper", idx: 15, where: "both" },
        { name: "Themes", idx: 16, where: "both" },
        { name: "Look & colors", idx: 0, where: "both" },
        { name: "Widgets", idx: 14, where: "both" },
        { name: "Desktop style", idx: 12, where: "hypr" },
        { name: "Retro style", idx: 2, where: "hypr" },
        { name: "Bar", idx: 3, where: "hypr" },
        { name: "Windows & display", idx: 4, where: "hypr" },
        { name: "Notifications & OSD", idx: 5, where: "hypr" },
        { name: "Touchpad", idx: 11, where: "both" },
        { name: "Login screen", idx: 1, where: "both" },
        { name: "Fun", idx: 13, where: "both" },
        { name: "Keybinds", idx: 6, where: "hypr" },
        { name: "About", idx: 7, where: "both" }
    ]
    readonly property var pages: allPages.filter(pg => pg.where === "both" || pg.where === (xfce ? "xfce" : "hypr"))

    // a clickable preview card (Desktop style pages)
    component StyleCard: Bevel {
        id: card
        property string label: ""
        property string about: ""
        property bool chosen: false
        default property alias preview: holder.data
        signal picked()
        Layout.preferredWidth: 286
        Layout.fillHeight: true
        implicitHeight: cardCol.implicitHeight + 16
        sunken: chosen
        fill: chosen ? Theme.face2 : Theme.face
        Column {
            id: cardCol
            x: 8; y: 8
            width: parent.width - 16
            spacing: 6
            Rectangle {
                width: parent.width
                height: holder.childrenRect.height + (card.chosen ? 4 : 2)
                color: Theme.dark
                border.width: card.chosen ? 2 : 1
                border.color: card.chosen ? Theme.accent : Theme.lo
                Item { id: holder; x: parent.border.width; y: parent.border.width; width: parent.width - 2 * parent.border.width; height: childrenRect.height }
            }
            BText { text: (card.chosen ? "● " : "") + card.label; font.bold: true }
            BText {
                width: parent.width
                text: card.about
                color: Theme.textDim
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                maximumLineCount: 3
                font.pixelSize: Math.max(10, Theme.fontSize - 2)
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.picked() }
    }

    // after the first open the window is kept (hidden) instead of rebuilt: Super+I again is instant
    property bool keep: false
    onOpenChanged: if (open) keep = true

    LazyLoader {
        active: root.open || root.keep

        FloatingWindow {
            id: win
            title: "Bevel Settings"
            visible: root.open
            // coming back: fresh wallpaper list and system facts
            Connections {
                target: root
                function onOpenChanged() { if (root.open) { win.loadWalls(); infoProc.running = true; } }
            }
            implicitWidth: 900
            implicitHeight: 660
            color: Theme.face
            onClosed: root.open = false

            property var walls: []

            // wallpapers: a quick list first (existing thumbnails), then make the missing ones
            property string thumbStatus: ""
            function loadWalls() { wallProc.command = ["bevelctl", "thumbs", "--quick"]; wallProc.running = true; }
            Process {
                id: wallProc
                command: ["bevelctl", "thumbs", "--quick"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        let list = [];
                        try { list = JSON.parse(text); } catch (e) { list = []; }
                        win.walls = list;
                        const missing = list.filter(w => w.pending).length;
                        if (missing > 0 && wallProc.command.indexOf("--quick") >= 0) {
                            win.thumbStatus = "Making thumbnails for " + missing + " new pictures…";
                            makeThumbs.running = true;
                        } else {
                            win.thumbStatus = "";
                        }
                    }
                }
            }
            Process {
                id: makeThumbs
                command: ["bevelctl", "thumbs"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try { win.walls = JSON.parse(text); } catch (e) {}
                        win.thumbStatus = "";
                    }
                }
            }
            property var info: ({})
            Process {
                id: infoProc
                command: ["bevelctl", "info"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: { try { win.info = JSON.parse(text); } catch (e) { win.info = {}; } }
                }
            }


            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.open = false

                Bevel {
                    anchors.fill: parent
                    padding: 2

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6

                        // title strip, 9x style
                        Rectangle {
                            visible: !!Quickshell.env("WAYLAND_DISPLAY")
                            Layout.fillWidth: true
                            implicitHeight: Theme.fontSize + 10
                            color: Theme.accent
                            radius: Theme.radiusSm
                            BText {
                                anchors.left: parent.left; anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Bevel Settings"; font.bold: true; color: Theme.accentText
                            }
                            BText {
                                anchors.right: parent.right; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Super+I · Esc to close"; color: Theme.accentText; opacity: 0.85
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: 4
                            spacing: 8

                            // ---- sidebar
                            Bevel {
                                Layout.preferredWidth: 170
                                Layout.fillHeight: true
                                sunken: true
                                fill: Theme.base
                                radius: Theme.radiusSm
                                padding: 2
                                Column {
                                    anchors.fill: parent
                                    Repeater {
                                        model: root.pages
                                        Rectangle {
                                            required property var modelData
                                            width: parent.width
                                            height: Theme.fontSize + 14
                                            color: root.page === modelData.idx ? Theme.accent : (hov.containsMouse ? Theme.face2 : "transparent")
                                            BText {
                                                anchors.fill: parent
                                                anchors.leftMargin: 8
                                                text: parent.modelData.name
                                                color: root.page === parent.modelData.idx ? Theme.accentText : Theme.text
                                            }
                                            MouseArea {
                                                id: hov
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: root.page = parent.modelData.idx
                                            }
                                        }
                                    }
                                }
                            }

                            // ---- page
                            // Scrolls with the wheel/touchpad only. Dragging is off on purpose:
                            // otherwise tiny touchpad movements turn clicks into scrolls.
                            // Wheel / two-finger scrolling. This MouseArea wraps the page and only
                            // listens to the wheel (no buttons), so every click still reaches the controls.
                            MouseArea {
                                id: wheelArea
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                acceptedButtons: Qt.NoButton
                                onWheel: wheel => {
                                    const dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 2;
                                    flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY - dy));
                                    wheel.accepted = true;
                                }

                                Flickable {
                                    id: flick
                                    anchors.fill: parent
                                    // height of the page you're on (not the tallest page)
                                    contentHeight: (stack.children[stack.currentIndex] ? stack.children[stack.currentIndex].implicitHeight : stack.implicitHeight) + 16
                                    clip: true
                                    interactive: false
                                    boundsBehavior: Flickable.StopAtBounds


                                    // scrollbar
                                    Rectangle {
                                        parent: flick
                                        visible: flick.contentHeight > flick.height
                                        anchors.right: parent.right
                                        y: flick.contentY / flick.contentHeight * flick.height
                                        width: 6
                                        height: Math.max(24, flick.height * flick.height / flick.contentHeight)
                                        color: Theme.lo
                                        opacity: 0.8
                                        z: 10
                                    }

                                    StackLayout {
                                        id: stack
                                        width: flick.width - 12
                                        currentIndex: root.page
                                        onCurrentIndexChanged: flick.contentY = 0

                                        // ===================== Look & colors
                                        // built the first time you open the page
                                        Loader {
                                            active: false
                                            readonly property bool current: StackLayout.isCurrentItem
                                            onCurrentChanged: if (current) active = true
                                            Component.onCompleted: if (current) active = true
                                            sourceComponent: Component {
                                                Item {      // keeps the page its natural height (a Layout would stretch it)
                                                    implicitHeight: childrenRect.height
                                                ColumnLayout {
                                                    width: parent.width
                                                    spacing: 14
                                                    SGroup {
                                                        title: "Colors"
                                                        SChoice {
                                                            text: "Source"
                                                            model: [{ label: "From wallpaper", value: "wallpaper" }, { label: "My own accent", value: "custom" }]
                                                            current: Theme.sv("colors.source", "wallpaper")
                                                            onPicked: v => Theme.set("colors.source", v)
                                                        }
                                                        RowLayout {
                                                            visible: Theme.sv("colors.source", "wallpaper") === "custom"
                                                            spacing: 10
                                                            BText { text: "Accent"; Layout.preferredWidth: 130 }
                                                            Repeater {
                                                                model: ["#2a5ea8", "#000080", "#b5532a", "#4f7a36", "#7a3fa8", "#a83f5e", "#2f8f8a", "#808000"]
                                                                Bevel {
                                                                    id: accSw
                                                                    required property string modelData
                                                                    width: 22; height: 22
                                                                    sunken: Theme.sv("colors.custom", "") === modelData
                                                                    fill: modelData
                                                                    MouseArea { anchors.fill: parent; onClicked: Theme.set("colors.custom", accSw.modelData) }
                                                                }
                                                            }
                                                        }
                                                        SField {
                                                            visible: Theme.sv("colors.source", "wallpaper") === "custom"
                                                            text: "Hex color"
                                                            value: Theme.sv("colors.custom", "#2a5ea8")
                                                            onAccepted: t => { if (/^#?[0-9a-fA-F]{6}$/.test(t.trim())) Theme.set("colors.custom", (t.trim()[0] === "#" ? "" : "#") + t.trim()); }
                                                        }
                                                        SSlider {
                                                            text: "Tint strength"
                                                            from: 0; to: 1; step: 0.05
                                                            value: Theme.sv("colors.tint", 0.6)
                                                            displayScale: 100; suffix: "%"
                                                            onMoved: v => Theme.set("colors.tint", v)
                                                        }
                                                        SSlider {
                                                            text: "Accent vibrance"
                                                            from: 0; to: 1; step: 0.05
                                                            value: Theme.sv("colors.vibrance", 0.6)
                                                            displayScale: 100; suffix: "%"
                                                            onMoved: v => Theme.set("colors.vibrance", v)
                                                        }
                                                        SChoice {
                                                            text: "Black & white"
                                                            model: [{ label: "When the wallpaper is", value: "auto" }, { label: "Always", value: "always" }, { label: "Never", value: "never" }]
                                                            current: Theme.sv("colors.mono", "auto")
                                                            onPicked: v => Theme.set("colors.mono", v)
                                                        }
                                                        RowLayout {
                                                            spacing: 20
                                                            SCheck { text: "Dark panels"; checked: Theme.sv("colors.darkPanels", false); onToggled: v => Theme.set("colors.darkPanels", v) }
                                                            SCheck { text: "Dark terminal"; checked: Theme.sv("colors.darkTerminal", true); onToggled: v => Theme.set("colors.darkTerminal", v) }
                                                        }
                                                        Row {
                                                            spacing: 0
                                                            Repeater {
                                                                model: [Theme.hi, Theme.face2, Theme.face, Theme.lo, Theme.dark, Theme.accent, Theme.accent2, Theme.termBg]
                                                                Rectangle {
                                                                    required property color modelData
                                                                    width: 60; height: 20
                                                                    color: modelData
                                                                    border.color: Theme.dark
                                                                }
                                                            }
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Icons"
                                                        visible: !root.xfce
                                                        SChoice {
                                                            text: "Icon style"
                                                            model: [{ label: "Retro (Windows 95)", value: "retro" }, { label: "Modern (Breeze)", value: "modern" }]
                                                            current: Theme.sv("style.icons", "retro")
                                                            onPicked: v => Theme.set("style.icons", v)
                                                        }
                                                        BText {
                                                            Layout.fillWidth: true
                                                            text: (win.info.retroIcons === false ? "⚠ The Chicago95 icons aren't installed yet: run ./install.sh again and tick \"Retro icons\". " : "")
                                                                  + "Used by the Run menu, dock, taskbar and your apps (apps pick it up when they restart)."
                                                            color: win.info.retroIcons === false ? Theme.accent : Theme.textDim
                                                            wrapMode: Text.Wrap
                                                            maximumLineCount: 3
                                                            elide: Text.ElideNone
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Mouse pointer"
                                                        SChoice {
                                                            text: "Style"
                                                            model: [{ label: "Bevel (Windows 9x)", value: "bevel" }, { label: "System default", value: "system" }]
                                                            current: Theme.sv("cursor.style", "bevel")
                                                            onPicked: v => Theme.set("cursor.style", v)
                                                        }
                                                        SChoice {
                                                            visible: Theme.sv("cursor.style", "bevel") === "bevel"
                                                            text: "Colour"
                                                            model: [{ label: "White", value: "white" }, { label: "Black", value: "black" },
                                                                    { label: "Accent", value: "accent" }, { label: "My colour", value: "custom" }]
                                                            current: Theme.sv("cursor.color", "white")
                                                            onPicked: v => Theme.set("cursor.color", v)
                                                        }
                                                        RowLayout {
                                                            visible: Theme.sv("cursor.style", "bevel") === "bevel" && Theme.sv("cursor.color", "white") === "custom"
                                                            spacing: 10
                                                            SField {
                                                                Layout.fillWidth: true
                                                                text: "Hex colour"
                                                                value: Theme.sv("cursor.custom", "#ffcc00")
                                                                onAccepted: t => { if (/^#?[0-9a-fA-F]{6}$/.test(t.trim())) Theme.set("cursor.custom", t.trim().startsWith("#") ? t.trim() : "#" + t.trim()); }
                                                            }
                                                            Repeater {
                                                                model: ["#ffcc00", "#ff5a5a", "#5ad1ff", "#7dff7a", "#ff8ad8", "#b48cff"]
                                                                Rectangle {
                                                                    required property string modelData
                                                                    width: 22; height: 22
                                                                    color: modelData
                                                                    border.color: Theme.sv("cursor.custom", "") === modelData ? Theme.text : Theme.dark
                                                                    border.width: Theme.sv("cursor.custom", "") === modelData ? 2 : 1
                                                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Theme.set("cursor.custom", parent.modelData) }
                                                                }
                                                            }
                                                        }
                                                        SChoice {
                                                            visible: Theme.sv("cursor.style", "bevel") === "bevel"
                                                            text: "Size"
                                                            model: [{ label: "Normal", value: 24 }, { label: "Large", value: 48 }, { label: "Huge", value: 72 }]
                                                            current: Theme.sv("cursor.size", 24)
                                                            onPicked: v => Theme.set("cursor.size", v)
                                                        }
                                                        Bevel {
                                                            visible: Theme.sv("cursor.style", "bevel") === "bevel"
                                                            implicitWidth: 6 * 36 * 2 + 12
                                                            implicitHeight: 36 * 2 + 8
                                                            sunken: true
                                                            fill: "#008080"
                                                            Image {
                                                                id: curPrev
                                                                anchors.centerIn: parent
                                                                width: 6 * 36 * 2; height: 36 * 2
                                                                smooth: false
                                                                cache: false
                                                                // bevelctl redraws the picture when the theme is rebuilt: look again a moment later
                                                                property int bump: 0
                                                                readonly property string want: Theme.sv("cursor.color", "white") + Theme.sv("cursor.custom", "") + Theme.accent
                                                                onWantChanged: reloadPrev.restart()
                                                                Timer { id: reloadPrev; interval: 2500; onTriggered: curPrev.bump++ }
                                                                source: "file://" + Theme.home + "/.cache/bevel/cursor-preview.png?" + want + bump
                                                            }
                                                        }
                                                        BText {
                                                            Layout.fillWidth: true
                                                                text: "Apps that are already open keep their old pointer until they restart; the desktop changes right away."
                                                            color: Theme.textDim
                                                            wrapMode: Text.Wrap
                                                            font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Apps that only read colours when they start"
                                                        BText {
                                                            text: "Dolphin and Firefox keep running in the background, so new windows keep the old colours."
                                                            color: Theme.textDim
                                                            wrapMode: Text.Wrap
                                                            maximumLineCount: 2
                                                            elide: Text.ElideNone
                                                            Layout.fillWidth: true
                                                        }
                                                        SCheck { text: "Restart Dolphin when the colours change (its tabs come back)"; checked: Theme.sv("apps.restartDolphin", true); onToggled: v => Theme.set("apps.restartDolphin", v) }
                                                        SCheck { text: "Restart Firefox when the colours change (its tabs come back)"; checked: Theme.sv("apps.restartFirefox", false); onToggled: v => Theme.set("apps.restartFirefox", v) }
                                                        RowLayout {
                                                            spacing: 6
                                                            SButton { text: "Restart them now"; onClicked: Theme.run(["bevelctl", "restart-apps", "dolphin", "firefox"]) }
                                                            BText { text: "Firefox closes and reopens with the same tabs."; color: Theme.textDim }
                                                        }
                                                    }
                                                }
                                                }
                                            }
                                        }

                                        // ===================== Login screen
                                        // built the first time you open the page
                                        Loader {
                                            active: false
                                            readonly property bool current: StackLayout.isCurrentItem
                                            onCurrentChanged: if (current) active = true
                                            Component.onCompleted: if (current) active = true
                                            sourceComponent: Component {
                                                Item {      // keeps the page its natural height (a Layout would stretch it)
                                                    implicitHeight: childrenRect.height
                                                ColumnLayout {
                                                    width: parent.width
                                                    spacing: 14
                                                    SGroup {
                                                        title: "Login screen wallpaper"
                                                        BText {
                                                            visible: win.info.login === false
                                                            text: "The login screen isn't installed. Run ./install.sh again and say yes to the login screen."
                                                            color: Theme.textDim
                                                            Layout.fillWidth: true
                                                            wrapMode: Text.Wrap
                                                            maximumLineCount: 2
                                                        }
                                                        WallBrowser {
                                                            walls: win.walls
                                                            pickKey: "login.wallpaper"
                                                            gridHeight: 250
                                                            status: Theme.sv("login.wallpaper", "") === "" ? "Using your desktop wallpaper" : ""
                                                        }
                                                        SSlider {
                                                            text: "Dither dimming"
                                                            from: 0; to: 0.9; step: 0.05
                                                            value: Theme.sv("login.dim", 0.55)
                                                            displayScale: 100; suffix: "%"
                                                            onMoved: v => Theme.set("login.dim", v)
                                                        }
                                                        SCheck {
                                                            text: "Keep the login screen in sync with my colors and wallpaper"
                                                            checked: Theme.sv("login.sync", true)
                                                            onToggled: v => Theme.set("login.sync", v)
                                                        }
                                                        RowLayout {
                                                            spacing: 6
                                                            SButton {
                                                                text: "Preview login screen"
                                                                onClicked: Theme.run(["sddm-greeter-qt6", "--test-mode", "--theme", "/usr/share/sddm/themes/bevel"])
                                                            }
                                                            BText { text: "Opens it as a window · close it with Super+C"; color: Theme.textDim; Layout.leftMargin: 8 }
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Lock screen"
                                                        SCheck { text: "Lock when the lid closes or the computer sleeps"; checked: Theme.sv("lock.onSleep", true); onToggled: v => Theme.set("lock.onSleep", v) }
                                                        SCheck { text: "Lock when I'm away"; checked: Theme.sv("lock.onIdle", true); onToggled: v => Theme.set("lock.onIdle", v) }
                                                        SSlider {
                                                            text: "Away after"
                                                            from: 1; to: 60; step: 1
                                                            value: Theme.sv("lock.minutes", 15)
                                                            suffix: " min"
                                                            onMoved: v => Theme.set("lock.minutes", v)
                                                        }
                                                        BText {
                                                            visible: !root.xfce && (win.info.missing || []).some(m => m === "hypridle" || m === "hyprlock")
                                                            Layout.fillWidth: true
                                                            text: "⚠ Locking needs hypridle and hyprlock: sudo pacman -S hypridle hyprlock, then log out and back in."
                                                            color: Theme.accent
                                                            font.bold: true
                                                            wrapMode: Text.Wrap
                                                            maximumLineCount: 2
                                                            elide: Text.ElideNone
                                                        }
                                                        RowLayout {
                                                            spacing: 6
                                                            SButton { text: "Lock now"; onClicked: { root.open = false; Theme.run(["sh", "-c", "sleep 0.4; bevelctl lock"]); } }
                                                            BText {
                                                                    text: "Hyprland: hyprlock in your colours (Super+Esc, or Super+L → Lock)."
                                                                color: Theme.textDim
                                                                Layout.leftMargin: 8
                                                            }
                                                        }
                                                    }
                                                }
                                                }
                                            }
                                        }

                                        // ===================== Retro style
                                        // built the first time you open the page
                                        Loader {
                                            active: false
                                            readonly property bool current: StackLayout.isCurrentItem
                                            onCurrentChanged: if (current) active = true
                                            Component.onCompleted: if (current) active = true
                                            sourceComponent: Component {
                                                Item {      // keeps the page its natural height (a Layout would stretch it)
                                                    implicitHeight: childrenRect.height
                                                ColumnLayout {
                                                    width: parent.width
                                                    spacing: 14
                                                    SGroup {
                                                        title: "Preset"
                                                        SChoice {
                                                            text: "Start from"
                                                            model: [{ label: "Classic", value: "classic" }, { label: "Soft", value: "soft" }, { label: "Modern", value: "modern" }]
                                                            current: Theme.sv("style.preset", "soft")
                                                            onPicked: v => Theme.run(["bevelctl", "preset", v])
                                                        }
                                                        BText {
                                                            text: "Classic = flat 9x panels, dithered bar · Soft = floating bar · Modern = thinner bevels, blur"
                                                            color: Theme.textDim
                                                            font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Panels"
                                                        SSlider { text: "Rounding"; from: 0; to: 14; step: 1; value: Theme.sv("style.rounding", 0); suffix: "px"; onMoved: v => Theme.set("style.rounding", v) }
                                                        SSlider { text: "Bevel depth"; from: 0; to: 2; step: 1; value: Theme.sv("style.bevel", 2); onMoved: v => Theme.set("style.bevel", v) }
                                                        SSlider { text: "Panel opacity"; from: 0.5; to: 1; step: 0.02; value: Theme.sv("style.opacity", 0.96); displayScale: 100; suffix: "%"; onMoved: v => Theme.set("style.opacity", v) }
                                                        RowLayout {
                                                            spacing: 20
                                                            SCheck { text: "Dithered panels"; checked: Theme.sv("style.dither", false); onToggled: v => Theme.set("style.dither", v) }
                                                            SCheck { text: "LCD clock"; checked: Theme.sv("style.lcdClock", false); onToggled: v => Theme.set("style.lcdClock", v) }
                                                            SCheck { text: "Lit window borders"; checked: Theme.sv("style.bevelBorders", false); onToggled: v => Theme.set("style.bevelBorders", v) }
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Fonts"
                                                        SChoice {
                                                            text: "Interface font"
                                                            model: [{ label: "Pixelify Sans", value: "Pixelify Sans" }, { label: "VT323", value: "VT323" },
                                                                    { label: "JetBrains Mono", value: "JetBrains Mono" }, { label: "Noto Sans", value: "Noto Sans" }]
                                                            current: Theme.sv("style.font", "Pixelify Sans")
                                                            onPicked: v => Theme.set("style.font", v)
                                                        }
                                                        SSlider { text: "Interface size"; from: 10; to: 18; step: 1; value: Theme.sv("style.fontSize", 13); suffix: "px"; onMoved: v => Theme.set("style.fontSize", v) }
                                                        SChoice {
                                                            text: "Terminal font"
                                                            model: [{ label: "VT323", value: "VT323" }, { label: "JetBrains Mono", value: "JetBrains Mono" }, { label: "monospace", value: "monospace" }]
                                                            current: Theme.sv("style.monoFont", "VT323")
                                                            onPicked: v => Theme.set("style.monoFont", v)
                                                        }
                                                        SSlider { text: "Terminal size"; from: 9; to: 24; step: 1; value: Theme.sv("terminal.fontSize", 15); suffix: "pt"; onMoved: v => Theme.set("terminal.fontSize", v) }
                                                        SSlider { text: "Terminal opacity"; from: 0.6; to: 1; step: 0.02; value: Theme.sv("terminal.opacity", 1); displayScale: 100; suffix: "%"; onMoved: v => Theme.set("terminal.opacity", v) }
                                                    }
                                                }
                                                }
                                            }
                                        }

                                        // ===================== Bar
                                        // built the first time you open the page
                                        Loader {
                                            active: false
                                            readonly property bool current: StackLayout.isCurrentItem
                                            onCurrentChanged: if (current) active = true
                                            Component.onCompleted: if (current) active = true
                                            sourceComponent: Component {
                                                Item {      // keeps the page its natural height (a Layout would stretch it)
                                                    implicitHeight: childrenRect.height
                                                ColumnLayout {
                                                    width: parent.width
                                                    spacing: 14
                                                    SGroup {
                                                        title: "What's on the bar"
                                                        BarItemsEditor { Layout.fillWidth: true }
                                                    }
                                                    SGroup {
                                                        title: "Placement"
                                                        SChoice {
                                                            text: "Position"
                                                            model: [{ label: "Top", value: "top" }, { label: "Bottom", value: "bottom" }]
                                                            current: Theme.sv("bar.position", "top")
                                                            onPicked: v => Theme.set("bar.position", v)
                                                        }
                                                        SSlider { text: "Height"; from: 20; to: 44; step: 1; value: Theme.sv("bar.height", 28); suffix: "px"; onMoved: v => Theme.set("bar.height", v) }
                                                        SCheck { text: "Floating (gap around the bar)"; checked: Theme.sv("bar.floating", true); onToggled: v => Theme.set("bar.floating", v) }
                                                    }
                                                    SGroup {
                                                        title: "Control panel"
                                                        SCheck {
                                                            text: "Show a Control Panel button on the bar"
                                                            readonly property var all: Theme.barItems.left.concat(Theme.barItems.center, Theme.barItems.right)
                                                            checked: all.indexOf("control") >= 0
                                                            onToggled: v => {
                                                                const c = { left: Theme.barItems.left.filter(x => x !== "control"), center: Theme.barItems.center.filter(x => x !== "control"),
                                                                            right: Theme.barItems.right.filter(x => x !== "control") };
                                                                if (v) { const i = c.right.indexOf("clock"); c.right.splice(i >= 0 ? i : c.right.length, 0, "control"); }
                                                                Theme.setUi("bar.controlButton", v);
                                                                Theme.setBarItems(c);
                                                            }
                                                        }
                                                        RowLayout {
                                                            spacing: 10
                                                            BText {
                                                                Layout.fillWidth: true
                                                                text: "Date and calendar, Wi-Fi, Bluetooth, sound, brightness, night light, battery, media and more. Super+A opens it too."
                                                                color: Theme.textDim
                                                                wrapMode: Text.Wrap
                                                                maximumLineCount: 3
                                                                elide: Text.ElideNone
                                                            }
                                                            SButton { text: "Open it"; onClicked: Theme.run(["qs", "-c", "bevel", "ipc", "call", "controlpanel", "show"]) }
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Bar text"
                                                        SChoice {
                                                            text: "Font"
                                                            model: [{ label: "JetBrains Mono", value: "JetBrains Mono" }, { label: "Pixelify Sans", value: "Pixelify Sans" },
                                                                    { label: "VT323", value: "VT323" }, { label: "Noto Sans", value: "Noto Sans" }]
                                                            current: Theme.sv("bar.font", "JetBrains Mono")
                                                            onPicked: v => Theme.set("bar.font", v)
                                                        }
                                                        SSlider { text: "Size"; from: 10; to: 18; step: 1; value: Theme.sv("bar.fontSize", 13); suffix: "px"; onMoved: v => Theme.set("bar.fontSize", v) }
                                                        SCheck { text: "Bold"; checked: Theme.sv("bar.bold", true); onToggled: v => Theme.set("bar.bold", v) }
                                                    }
                                                    SGroup {
                                                        title: "Workspaces"
                                                        SSlider { text: "Always show"; from: 1; to: 10; step: 1; value: Theme.sv("bar.workspaces", 5); onMoved: v => Theme.set("bar.workspaces", v) }
                                                        SCheck { text: "Mini window maps (off = numbers)"; checked: Theme.sv("bar.minimaps", true); onToggled: v => Theme.set("bar.minimaps", v) }
                                                        SChoice {
                                                            text: "With 2+ monitors"
                                                            model: [{ label: "Each bar: its monitor's", value: "auto" }, { label: "Every bar: all of them", value: "all" }]
                                                            current: Theme.sv("bar.workspacesMode", "auto") === "all" ? "all" : "auto"
                                                            onPicked: v => Theme.setUi("bar.workspacesMode", v)
                                                        }
                                                        SCheck {
                                                            text: "Window buttons (Taskbar layout): only the windows on that screen"
                                                            checked: Theme.sv("bar.tasksPerScreen", true)
                                                            onToggled: v => Theme.setUi("bar.tasksPerScreen", v)
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Clock"
                                                        RowLayout {
                                                            spacing: 24
                                                            SCheck { text: "Date"; checked: Theme.sv("bar.showDate", false); onToggled: v => Theme.set("bar.showDate", v) }
                                                            SCheck { text: "Seconds"; checked: Theme.sv("bar.clockSeconds", false); onToggled: v => Theme.set("bar.clockSeconds", v) }
                                                            SCheck {
                                                                text: "12-hour clock"
                                                                checked: Theme.sv("bar.clockFormat", "HH:mm") !== "HH:mm"
                                                                onToggled: v => Theme.set("bar.clockFormat", v ? "h:mm AP" : "HH:mm")
                                                            }
                                                        }
                                                    }
                                                }
                                                }
                                            }
                                        }

                                        // ===================== Windows & display
                                        // built the first time you open the page
                                        Loader {
                                            active: false
                                            readonly property bool current: StackLayout.isCurrentItem
                                            onCurrentChanged: if (current) active = true
                                            Component.onCompleted: if (current) active = true
                                            sourceComponent: Component {
                                                Item {      // keeps the page its natural height (a Layout would stretch it)
                                                    implicitHeight: childrenRect.height
                                                ColumnLayout {
                                                    width: parent.width
                                                    spacing: 14
                                                    SGroup {
                                                        title: "Displays"
                                                        DisplaysEditor { Layout.fillWidth: true }
                                                    }
                                                    SGroup {
                                                        title: "Terminal window"
                                                        SCheck { text: "Super+Q opens a small floating terminal (Super+Shift+Q = tiled)"; checked: Theme.sv("terminal.floating", true); onToggled: v => Theme.set("terminal.floating", v) }
                                                        SSlider { text: "Width"; from: 500; to: 1600; step: 20; value: Theme.sv("terminal.width", 900); suffix: "px"; onMoved: v => Theme.set("terminal.width", v) }
                                                        SSlider { text: "Height"; from: 300; to: 1000; step: 20; value: Theme.sv("terminal.height", 560); suffix: "px"; onMoved: v => Theme.set("terminal.height", v) }
                                                    }
                                                    SGroup {
                                                        title: "Tiling"
                                                        SChoice {
                                                            text: "Layout"
                                                            model: [{ label: "dwindle", value: "dwindle" }, { label: "master", value: "master" }]
                                                            current: Theme.sv("windows.layout", "dwindle")
                                                            onPicked: v => Theme.set("windows.layout", v)
                                                        }
                                                        SSlider { text: "Gaps between"; from: 0; to: 24; step: 1; value: Theme.sv("windows.gapsIn", 4); suffix: "px"; onMoved: v => Theme.set("windows.gapsIn", v) }
                                                        SSlider { text: "Gaps to edge"; from: 0; to: 40; step: 1; value: Theme.sv("windows.gapsOut", 8); suffix: "px"; onMoved: v => Theme.set("windows.gapsOut", v) }
                                                        SSlider { text: "Border size"; from: 0; to: 6; step: 1; value: Theme.sv("windows.border", 2); suffix: "px"; onMoved: v => Theme.set("windows.border", v) }
                                                        SSlider { text: "Inactive opacity"; from: 0.6; to: 1; step: 0.02; value: Theme.sv("windows.inactiveOpacity", 1); displayScale: 100; suffix: "%"; onMoved: v => Theme.set("windows.inactiveOpacity", v) }
                                                        RowLayout {
                                                            spacing: 20
                                                            SCheck { text: "Blur"; checked: Theme.sv("windows.blur", false); onToggled: v => Theme.set("windows.blur", v) }
                                                            SCheck { text: "Shadows"; checked: Theme.sv("windows.shadow", false); onToggled: v => Theme.set("windows.shadow", v) }
                                                            SCheck { text: "Animations"; checked: Theme.sv("windows.animations", true); onToggled: v => Theme.set("windows.animations", v) }
                                                        }
                                                    }
                                                }
                                                }
                                            }
                                        }

                                        // ===================== Notifications & OSD
                                        // built the first time you open the page
                                        Loader {
                                            active: false
                                            readonly property bool current: StackLayout.isCurrentItem
                                            onCurrentChanged: if (current) active = true
                                            Component.onCompleted: if (current) active = true
                                            sourceComponent: Component {
                                                Item {      // keeps the page its natural height (a Layout would stretch it)
                                                    implicitHeight: childrenRect.height
                                                ColumnLayout {
                                                    width: parent.width
                                                    spacing: 14
                                                    SGroup {
                                                        title: "Timing"
                                                        SSlider { text: "Notifications stay"; from: 2; to: 15; step: 1; value: Theme.sv("notifications.timeout", 5000) / 1000; suffix: "s"; onMoved: v => Theme.set("notifications.timeout", Math.round(v * 1000)) }
                                                        SChoice {
                                                            visible: Quickshell.screens.length > 1
                                                            text: "Show them on"
                                                            model: [{ label: "The screen I'm using", value: "focused" }, { label: "The main display", value: "primary" }]
                                                            current: Theme.sv("notifications.screen", "focused")
                                                            onPicked: v => Theme.setUi("notifications.screen", v)
                                                        }
                                                        SSlider { text: "Volume pop-up stays"; from: 0.5; to: 4; step: 0.1; decimals: 1; value: Theme.sv("osd.timeout", 1400) / 1000; suffix: "s"; onMoved: v => Theme.set("osd.timeout", Math.round(v * 1000)) }
                                                    }
                                                    SGroup {
                                                        title: "Try it"
                                                        RowLayout {
                                                            spacing: 6
                                                            SButton { text: "Test notification"; onClicked: Theme.run(["notify-send", "-a", "Bevel", "Hello from Bevel", "This is what notifications look like."]) }
                                                            SButton { text: "Clear all"; onClicked: Theme.run(["qs", "-c", "bevel", "ipc", "call", "notifications", "clear"]) }
                                                        }
                                                    }
                                                }
                                                }
                                            }
                                        }

                                        // ===================== Keybinds
                                        // built the first time you open the page
                                        Loader {
                                            active: false
                                            readonly property bool current: StackLayout.isCurrentItem
                                            onCurrentChanged: if (current) active = true
                                            Component.onCompleted: if (current) active = true
                                            sourceComponent: Component {
                                                Item {      // keeps the page its natural height (a Layout would stretch it)
                                                    implicitHeight: childrenRect.height
                                                ColumnLayout {
                                                    width: parent.width
                                                    spacing: 14
                                                    SGroup {
                                                        title: "Keybinds"
                                                        GridLayout {
                                                            columns: 2
                                                            columnSpacing: 24
                                                            rowSpacing: 4
                                                            Repeater {
                                                                model: [
                                                                    ["Super + Q", "Terminal (floating)"], ["Super + Shift + Q", "Terminal (tiled)"],
                                                                    ["Super + C", "Close window"], ["Super + Shift + F", "Maximize"],
                                                                    ["Super + R", "Run / app menu"], ["Super + L", "Lock · log out · shut down"],
                                                                    ["Super + E", "Dolphin"], ["Super + I", "These settings"],
                                                                    ["Super + W", "Random wallpaper"], ["Super + N", "Clear notifications"],
                                                                    ["Super + V", "Clipboard history"], ["Super + F", "Fullscreen"],
                                                                    ["Super + Shift + V", "Float / tile window"], ["Alt + Tab", "Switch windows"],
                                                                    ["Super + J", "Flip split"], ["Super + P", "Pseudo-tile"],
                                                                    ["Super + arrows", "Move focus"], ["Super + 1…0", "Go to workspace"],
                                                                    ["Super + Shift + 1…0", "Send window to workspace"], ["Super + S", "Show/hide scratchpad"],
                                                                    ["Super + Alt + S", "Send window to scratchpad"], ["Super + Shift + S", "Screenshot of a region"],
                                                                    ["Super + Ctrl + ←/→", "Go to the other monitor"], ["Super + Ctrl + Shift + ←/→", "Take the window there"],
                                                                    ["Super + Alt + ←/→", "Move the workspace to the other monitor"],
                                                                    ["Super + drag", "Move (left) / resize (right)"], ["Print", "Screenshot of a region"],
                                                                    ["Shift + Print", "Screenshot of the screen"], ["Super + Print", "Screenshot of the window"],
                                                                    ["Volume / mute keys", "Volume (with pop-up)"], ["Brightness keys", "Brightness (with pop-up)"],
                                                                    ["Media keys", "Play / pause / next / previous"], ["Super + Shift + Z", "Screensaver"],
                                                                    ["Super + A", "Control panel"], ["Super + Shift + W", "Random favourite wallpaper"],
                                                                    ["Super + Esc", "Lock the screen"], ["Super + F1", "Every shortcut (cheat sheet)"]
                                                                ]
                                                                BText {
                                                                    required property var modelData
                                                                    required property int index
                                                                    text: "<b>" + modelData[0] + "</b> — " + modelData[1]
                                                                    textFormat: Text.StyledText
                                                                }
                                                            }
                                                        }
                                                        BText {
                                                            text: "Edit them in ~/.config/hypr/bevel_keybinds.lua"
                                                            color: Theme.textDim
                                                        }
                                                    }
                                                }
                                                }
                                            }
                                        }

                                        // ===================== About
                                        // built the first time you open the page
                                        Loader {
                                            active: false
                                            readonly property bool current: StackLayout.isCurrentItem
                                            onCurrentChanged: if (current) active = true
                                            Component.onCompleted: if (current) active = true
                                            sourceComponent: Component {
                                                Item {      // keeps the page its natural height (a Layout would stretch it)
                                                    implicitHeight: childrenRect.height
                                                ColumnLayout {
                                                    width: parent.width
                                                    spacing: 14

                                                    // ---- logo banner
                                                    Bevel {
                                                        Layout.fillWidth: true
                                                        implicitHeight: bannerCol.implicitHeight + 40
                                                        sunken: true
                                                        fill: Theme.dark
                                                        Dither { anchors.fill: parent; opacity: 0.25 }
                                                        Column {
                                                            id: bannerCol
                                                            anchors.centerIn: parent
                                                            spacing: 12
                                                            Logo {
                                                                id: aboutLogo
                                                                anchors.horizontalCenter: parent.horizontalCenter
                                                                block: 13
                                                                transform: Translate { id: shake }
                                                                // don't click the logo.
                                                                Rectangle {
                                                                    id: glitchTint
                                                                    anchors.fill: parent
                                                                    color: "#33ff66"
                                                                    opacity: 0
                                                                }
                                                                MouseArea {
                                                                    anchors.fill: parent
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onClicked: if (!glitch.running) glitch.restart()
                                                                }
                                                                SequentialAnimation {
                                                                    id: glitch
                                                                    ParallelAnimation {
                                                                        SequentialAnimation {
                                                                            loops: 6
                                                                            NumberAnimation { target: shake; property: "x"; to: 7; duration: 35 }
                                                                            NumberAnimation { target: shake; property: "x"; to: -6; duration: 35 }
                                                                            NumberAnimation { target: shake; property: "x"; to: 0; duration: 30 }
                                                                        }
                                                                        SequentialAnimation {
                                                                            loops: 4
                                                                            NumberAnimation { target: glitchTint; property: "opacity"; to: 0.7; duration: 50 }
                                                                            NumberAnimation { target: glitchTint; property: "opacity"; to: 0; duration: 70 }
                                                                        }
                                                                    }
                                                                    ScriptAction {
                                                                        script: {
                                                                            Ui.opsec = true;
                                                                            if (!root.xfce) root.open = false;
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                            Row {
                                                                anchors.horizontalCenter: parent.horizontalCenter
                                                                spacing: 10
                                                                Rectangle { width: 36; height: 2; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                                                                BText {
                                                                    text: "H Y P R · 9 X   E D I T I O N"
                                                                    color: Theme.accent2
                                                                    font.family: Theme.barFont
                                                                    font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
                                                                    font.bold: true
                                                                    font.pixelSize: 12
                                                                }
                                                                Rectangle { width: 36; height: 2; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                                                            }
                                                            BText {
                                                                anchors.horizontalCenter: parent.horizontalCenter
                                                                text: "square corners · raised edges · colors pulled from your wallpaper"
                                                                color: Qt.rgba(1, 1, 1, 0.6)
                                                                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                                            }
                                                        }
                                                    }

                                                    SGroup {
                                                        title: "This machine"
                                                        GridLayout {
                                                            columns: 2
                                                            columnSpacing: 24
                                                            rowSpacing: 4
                                                            Repeater {
                                                                model: [
                                                                    ["Host", win.info.host || "…"],
                                                                    ["CPU", win.info.cpu || "…"],
                                                                    ["Kernel", win.info.kernel || "…"],
                                                                        ["Hyprland", win.info.hyprland || "…"],
                                                                    ["Quickshell", win.info.quickshell || "…"],
                                                                    ["Uptime", win.info.uptime || "…"],
                                                                    ["Wallpaper", Theme.wallpaper ? Theme.wallpaper.split("/").pop() : "custom accent"],
                                                                    ["Preset", Theme.sv("style.preset", "soft")]
                                                                ]
                                                                BText {
                                                                    required property var modelData
                                                                    text: "<b>" + modelData[0] + "</b>  " + modelData[1]
                                                                    textFormat: Text.StyledText
                                                                    Layout.maximumWidth: 300
                                                                }
                                                            }
                                                        }
                                                    }

                                                    SGroup {
                                                        title: "Bevel"
                                                        BText { text: "Settings: ~/.config/bevel/settings.json  ·  CLI: bevelctl --help"; color: Theme.textDim }
                                                        RowLayout {
                                                            spacing: 6
                                                            SButton { text: "Re-apply theme"; onClicked: Theme.run(["bevelctl", "apply"]) }
                                                            SButton { visible: !root.xfce; text: "Reload shell"; onClicked: Quickshell.reload(true) }
                                                            SButton { text: "Reset to defaults"; onClicked: Theme.run(["bevelctl", "reset"]) }
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Help"
                                                        RowLayout {
                                                            spacing: 6
                                                            SButton { text: "Welcome tour"; onClicked: Theme.run(["bevelctl", "welcome"]) }
                                                            SButton { text: "Keyboard shortcuts"; onClicked: Theme.run(["bevelctl", "welcome", "keys"]) }
                                                            SButton {
                                                                text: "Make a bug report"
                                                                onClicked: Theme.run(["sh", "-c", "bevelctl doctor && xdg-open \"$HOME/bevel-report.txt\""])
                                                            }
                                                        }
                                                        BText {
                                                            Layout.fillWidth: true
                                                            text: "Something broken? The bug report collects your settings, versions and recent logs into ~/bevel-report.txt (nothing is sent anywhere)."
                                                            color: Theme.textDim
                                                            wrapMode: Text.Wrap
                                                            maximumLineCount: 2
                                                            elide: Text.ElideNone
                                                            font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                                        }
                                                    }
                                                }
                                                }
                                            }
                                        }

                                        // (8, 9, 10: pages of the other desktop)
                                        Item {}
                                        Item {}
                                        Item {}
                                        
                                        // ===================== (11) Touchpad (both desktops)
                                        // built the first time you open the page
                                        Loader {
                                            active: false
                                            readonly property bool current: StackLayout.isCurrentItem
                                            onCurrentChanged: if (current) active = true
                                            Component.onCompleted: if (current) active = true
                                            sourceComponent: Component {
                                                Item {      // keeps the page its natural height (a Layout would stretch it)
                                                    implicitHeight: childrenRect.height
                                                ColumnLayout {
                                                    width: parent.width
                                                    spacing: 14
                                                    SGroup {
                                                        title: "Tapping"
                                                        SCheck { text: "Tap to click"; checked: Theme.sv("touchpad.tap", true); onToggled: v => Theme.set("touchpad.tap", v) }
                                                        SChoice {
                                                            text: "Multi-finger tap"
                                                            labelWidth: 130
                                                            model: [{ label: "2 fingers = right · 3 = middle", value: "lrm" }, { label: "2 fingers = middle · 3 = right", value: "lmr" }]
                                                            current: Theme.sv("touchpad.tapMap", "lrm")
                                                            onPicked: v => Theme.set("touchpad.tapMap", v)
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Clicking"
                                                        SCheck {
                                                            text: "Press down with 2 fingers = right click, 3 fingers = middle click"
                                                            checked: Theme.sv("touchpad.clickfinger", true)
                                                            onToggled: v => Theme.set("touchpad.clickfinger", v)
                                                        }
                                                        BText {
                                                            text: "Off: right click by pressing the bottom-right corner instead."
                                                            color: Theme.textDim
                                                            font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Scrolling & speed"
                                                        RowLayout {
                                                            spacing: 20
                                                            SCheck { text: "Natural scrolling"; checked: Theme.sv("touchpad.natural", false); onToggled: v => Theme.set("touchpad.natural", v) }
                                                            SCheck { text: "Ignore while typing"; checked: Theme.sv("touchpad.dwt", true); onToggled: v => Theme.set("touchpad.dwt", v) }
                                                        }
                                                        SSlider {
                                                            text: "Pointer speed"
                                                            from: -1; to: 1; step: 0.1; decimals: 1
                                                            value: Theme.sv("touchpad.speed", 0)
                                                            onMoved: v => Theme.set("touchpad.speed", Math.round(v * 10) / 10)
                                                        }
                                                    }
                                                }
                                                }
                                            }
                                        }

                                        // ===================== (12) Hyprland: Desktop style
                                        // built the first time you open the page
                                        Loader {
                                            active: false
                                            readonly property bool current: StackLayout.isCurrentItem
                                            onCurrentChanged: if (current) active = true
                                            Component.onCompleted: if (current) active = true
                                            sourceComponent: Component {
                                                Item {      // keeps the page its natural height (a Layout would stretch it)
                                                    implicitHeight: childrenRect.height
                                                ColumnLayout {
                                                    width: parent.width
                                                    spacing: 14
                                                    SGroup {
                                                        title: "Bar layout"
                                                        GridLayout {
                                                            columns: 2
                                                            columnSpacing: 10
                                                            rowSpacing: 10
                                                            Repeater {
                                                                model: [
                                                                    { id: "bevel", label: "Bevel", about: "One bar with workspace minimaps. The original." },
                                                                    { id: "taskbar", label: "Taskbar", about: "Windows 95 at the bottom: Start, window buttons, tray." },
                                                                    { id: "island", label: "Islands", about: "Three floating blocks: workspaces, clock, status." },
                                                                    { id: "dock", label: "Dock", about: "Slim top bar plus an icon dock. Set it up below." }
                                                                ]
                                                                StyleCard {
                                                                    id: layoutCard
                                                                    required property var modelData
                                                                    label: modelData.label; about: modelData.about
                                                                    chosen: Theme.barLayout === modelData.id
                                                                    onPicked: Theme.set("bar.layout", modelData.id)
                                                                    MiniDesk { layout: layoutCard.modelData.id; width: layoutCard.width - 20; height: Math.round(width * 0.6) }
                                                                }
                                                            }
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Dock"
                                                        BText {
                                                            Layout.fillWidth: true
                                                            visible: Theme.barLayout !== "dock"
                                                            text: "The dock shows with the \"Dock\" bar layout above."
                                                            color: Theme.textDim
                                                        }
                                                        SChoice {
                                                            text: "Position"
                                                            model: [{ label: "Bottom", value: "bottom" }, { label: "Left", value: "left" }, { label: "Right", value: "right" }]
                                                            current: Theme.dockPos
                                                            onPicked: v => Theme.setUi("dock.position", v)
                                                        }
                                                        SSlider { text: "Icon size"; from: 24; to: 72; step: 4; value: Theme.dockSize; suffix: "px"; onMoved: v => Theme.setUi("dock.size", v) }
                                                        SChoice {
                                                            text: "Background"
                                                            model: [{ label: "9x panel", value: "panel" }, { label: "Glass", value: "glass" }, { label: "Flat", value: "flat" },
                                                                    { label: "Accent", value: "accent" }, { label: "None", value: "none" }]
                                                            current: Theme.dockStyle
                                                            onPicked: v => Theme.setUi("dock.style", v)
                                                        }
                                                        SChoice {
                                                            text: "Icons"
                                                            model: [{ label: "On buttons", value: true }, { label: "Plain", value: false }]
                                                            current: Theme.dockButtons
                                                            onPicked: v => Theme.setUi("dock.buttons", v)
                                                        }
                                                        RowLayout {
                                                            spacing: 18
                                                            SCheck { text: "Grow on hover"; checked: Theme.dockGrow; onToggled: v => Theme.setUi("dock.grow", v) }
                                                            SCheck { text: "Show running apps"; checked: Theme.dockRunning; onToggled: v => Theme.setUi("dock.running", v) }
                                                            SCheck { text: "Auto-hide"; checked: Theme.dockAutohide; onToggled: v => Theme.setUi("dock.autohide", v) }
                                                        }
                                                        SCheck {
                                                            visible: Quickshell.screens.length > 1
                                                            text: "Show the dock on every monitor (off: only on the main display)"
                                                            checked: Theme.sv("dock.allScreens", false)
                                                            onToggled: v => Theme.setUi("dock.allScreens", v)
                                                        }
                                                        DockEditor { Layout.fillWidth: true }
                                                    }
                                                    SGroup {
                                                        title: "Launcher (Super+R)"
                                                        GridLayout {
                                                            columns: 3
                                                            columnSpacing: 10
                                                            rowSpacing: 10
                                                            Repeater {
                                                                model: [
                                                                    { id: "run", label: "Run box", about: "Type, arrows, Enter." },
                                                                    { id: "grid", label: "Program Manager", about: "A window of icons." },
                                                                    { id: "start", label: "Start menu", about: "Categories + banner." }
                                                                ]
                                                                StyleCard {
                                                                    id: launchCard
                                                                    required property var modelData
                                                                    Layout.preferredWidth: 188
                                                                    label: modelData.label; about: modelData.about
                                                                    chosen: Theme.launcherStyle === modelData.id
                                                                    onPicked: Theme.set("launcher.style", modelData.id)
                                                                    MiniDesk { launcher: launchCard.modelData.id; layout: "none"; width: launchCard.width - 20; height: Math.round(width * 0.62) }
                                                                }
                                                            }
                                                        }
                                                        RowLayout {
                                                            spacing: 6
                                                            SButton { text: "Try it"; onClicked: Theme.run(["qs", "-c", "bevel", "ipc", "call", "launcher", "show"]) }
                                                            BText { text: "In any style: =12*7 calculates, and a few words do something silly."; color: Theme.textDim }
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Shut-down menu (Super+L)"
                                                        GridLayout {
                                                            columns: 3
                                                            columnSpacing: 10
                                                            rowSpacing: 10
                                                            Repeater {
                                                                model: [
                                                                    { id: "dialog", label: "Dialog", about: "\"What do you want the computer to do?\"" },
                                                                    { id: "tiles", label: "Tiles", about: "Five big icons across the screen." },
                                                                    { id: "dropdown", label: "Drop-down", about: "A small menu from the bar's corner." }
                                                                ]
                                                                StyleCard {
                                                                    id: powerCard
                                                                    required property var modelData
                                                                    Layout.preferredWidth: 188
                                                                    label: modelData.label; about: modelData.about
                                                                    chosen: Theme.sv("power.style", "dialog") === modelData.id
                                                                    onPicked: Theme.set("power.style", modelData.id)
                                                                    MiniDesk { power: powerCard.modelData.id; layout: "none"; width: powerCard.width - 20; height: Math.round(width * 0.62) }
                                                                }
                                                            }
                                                        }
                                                        SCheck {
                                                            text: "Show \"It's now safe to turn off your computer\" before shutting down (Esc cancels)"
                                                            checked: Theme.sv("power.safeScreen", true)
                                                            onToggled: v => Theme.set("power.safeScreen", v)
                                                        }
                                                        SButton { text: "Try it"; onClicked: { root.open = false; Theme.run(["sh", "-c", "sleep 0.3; qs -c bevel ipc call power show"]); } }
                                                    }
                                                    SGroup {
                                                        title: "Changing colours"
                                                        SCheck {
                                                            text: "Show a \"Repainting your desktop\" screen while the colours change"
                                                            checked: Theme.loadingScreen
                                                            onToggled: v => Theme.set("style.loadingScreen", v)
                                                        }
                                                    }
                                                }
                                                }
                                            }
                                        }

                                        // ===================== (13) Fun (both)
                                        // built the first time you open the page
                                        Loader {
                                            active: false
                                            readonly property bool current: StackLayout.isCurrentItem
                                            onCurrentChanged: if (current) active = true
                                            Component.onCompleted: if (current) active = true
                                            sourceComponent: Component {
                                                Item {      // keeps the page its natural height (a Layout would stretch it)
                                                    implicitHeight: childrenRect.height
                                                ColumnLayout {
                                                    width: parent.width
                                                    spacing: 14
                                                    SGroup {
                                                        title: "\"" + Theme.btwLabel + "\""
                                                        SCheck { visible: !root.xfce; text: "Show it on the bar (click it for a reply)"; checked: Theme.btw; onToggled: v => Theme.set("fun.btw", v) }
                                                        SCheck { text: "Add it to fastfetch"; checked: Theme.sv("fun.btwFastfetch", true); onToggled: v => Theme.set("fun.btwFastfetch", v) }
                                                        SField {
                                                            text: "Custom text"
                                                            value: Theme.sv("fun.btwText", "")
                                                            onAccepted: t => Theme.set("fun.btwText", t.trim())
                                                        }
                                                        BText { text: "Leave it empty for \"I use " + Theme.distro + " btw\". Press Enter to save."; color: Theme.textDim }
                                                    }
                                                    SGroup {
                                                        visible: !root.xfce
                                                        title: "Screensaver"
                                                        SChoice {
                                                            text: "Screensaver"
                                                            model: [{ label: "Off", value: "off" }, { label: "Starfield", value: "starfield" },
                                                                    { label: "Mystify", value: "mystify" }, { label: "Pipes", value: "pipes" }]
                                                            current: Theme.saver
                                                            onPicked: v => Theme.set("fun.screensaver", v)
                                                        }
                                                        SSlider {
                                                            text: "Start after"
                                                            from: 1; to: 60; step: 1
                                                            value: Theme.saverMinutes
                                                            suffix: " min"
                                                            onMoved: v => Theme.set("fun.saverMinutes", v)
                                                        }
                                                        RowLayout {
                                                            spacing: 6
                                                            SButton { text: "Preview"; onClicked: { root.open = false; Theme.run(["sh", "-c", "sleep 0.4; qs -c bevel ipc call screensaver start"]); } }
                                                            BText { text: "Or press Super+Shift+Z. Move the mouse or press a key to stop it."; color: Theme.textDim }
                                                        }
                                                    }
                                                    SGroup {
                                                        visible: !root.xfce
                                                        title: "Desktop pet"
                                                        SChoice {
                                                            text: "Pet"
                                                            model: [{ label: "None", value: "off" }, { label: "Bevvy the sheep", value: "sheep" }]
                                                            current: Theme.sv("fun.pet", "off")
                                                            onPicked: v => Theme.set("fun.pet", v)
                                                        }
                                                        BText {
                                                            text: "Wanders along the bottom of the screen. Click it. Type \"party\" in Super+R for the whole flock."
                                                            color: Theme.textDim
                                                            wrapMode: Text.Wrap
                                                            maximumLineCount: 2
                                                            elide: Text.ElideNone
                                                            Layout.fillWidth: true
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Little things"
                                                        RowLayout {
                                                            visible: !root.xfce
                                                            spacing: 10
                                                            SCheck { text: "Tip of the Day at login"; checked: Theme.tips; onToggled: v => Theme.set("fun.tips", v) }
                                                            SButton { text: "Show one now"; onClicked: Theme.run(["qs", "-c", "bevel", "ipc", "call", "tips", "show"]) }
                                                        }
                                                        RowLayout {
                                                            spacing: 10
                                                            SCheck { text: "Start-up chime when you log in"; checked: Theme.sv("fun.chime", false); onToggled: v => Theme.set("fun.chime", v) }
                                                            SButton { text: "Play"; onClicked: Theme.run(["bevelctl", "chime"]) }
                                                        }
                                                    }
                                                }
                                                }
                                            }
                                        }

                                        // ===================== (14) Widgets (Hyprland)
                                        // built the first time you open the page
                                        Loader {
                                            active: false
                                            readonly property bool current: StackLayout.isCurrentItem
                                            onCurrentChanged: if (current) active = true
                                            Component.onCompleted: if (current) active = true
                                            sourceComponent: Component {
                                                Item {      // keeps the page its natural height (a Layout would stretch it)
                                                    implicitHeight: childrenRect.height
                                                ColumnLayout {
                                                    width: parent.width
                                                    id: wpage
                                                    spacing: 14
                                                    readonly property var list: Theme.widgetList
                                                    function save(l) { Theme.setUi("widgets.list", l); }
                                                    function move(i, d) {
                                                        const l = wpage.list.slice();
                                                        const j = i + d;
                                                        if (j < 0 || j >= l.length) return;
                                                        const x = l[i]; l[i] = l[j]; l[j] = x;
                                                        wpage.save(l);
                                                    }
                                                    SGroup {
                                                        title: "Desktop widgets"
                                                        SCheck {
                                                            text: "Show widgets on the desktop"
                                                            checked: Theme.widgetsOn
                                                            onToggled: v => root.xfce ? Theme.set("widgets.enabled", v) : Theme.setUi("widgets.enabled", v)
                                                        }
                                                        BText {
                                                            Layout.fillWidth: true
                                                            text: "Tiles line up by themselves, in the order below, like the Windows 8 start screen. Changes show on the desktop right away."
                                                            color: Theme.textDim
                                                            wrapMode: Text.Wrap
                                                            maximumLineCount: 2
                                                            elide: Text.ElideNone
                                                        }
                                                        SChoice {
                                                            text: "Look"
                                                            model: [{ label: "Metro tiles", value: "tiles" }, { label: "9x windows", value: "window" },
                                                                    { label: "9x panels", value: "panel" }, { label: "Glass", value: "glass" }]
                                                            current: Theme.sv("widgets.style", "tiles")
                                                            onPicked: v => Theme.setUi("widgets.style", v)
                                                        }
                                                        RowLayout {
                                                            spacing: 10
                                                            BText { text: "Position"; Layout.preferredWidth: 130; Layout.alignment: Qt.AlignTop; Layout.topMargin: 4 }
                                                            // a 3×3 picker, like the old "Display Properties" position box
                                                            Bevel {
                                                                implicitWidth: posGrid.implicitWidth + 10
                                                                implicitHeight: posGrid.implicitHeight + 10
                                                                sunken: true
                                                                fill: Theme.base
                                                                Grid {
                                                                    id: posGrid
                                                                    anchors.centerIn: parent
                                                                    columns: 3
                                                                    spacing: 3
                                                                    Repeater {
                                                                        model: ["top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right"]
                                                                        Rectangle {
                                                                            required property string modelData
                                                                            readonly property bool on: Theme.sv("widgets.corner", "top-right") === modelData
                                                                            width: 34; height: 22
                                                                            color: on ? Theme.accent : (posMa.containsMouse ? Theme.face2 : Theme.face)
                                                                            border.color: Theme.lo
                                                                            Rectangle {
                                                                                width: 10; height: 7
                                                                                color: parent.on ? Theme.accentText : Theme.textDim
                                                                                x: parent.modelData.endsWith("left") ? 3 : (parent.modelData.endsWith("right") ? parent.width - width - 3 : (parent.width - width) / 2)
                                                                                y: parent.modelData.startsWith("top") ? 3 : (parent.modelData.startsWith("bottom") ? parent.height - height - 3 : (parent.height - height) / 2)
                                                                            }
                                                                            MouseArea { id: posMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Theme.setUi("widgets.corner", parent.modelData) }
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                            BText {
                                                                Layout.fillWidth: true
                                                                Layout.alignment: Qt.AlignTop
                                                                text: "Pick a corner, an edge or the middle. With \"One row\" below, the top and bottom spots line the widgets up along the edge."
                                                                color: Theme.textDim
                                                                wrapMode: Text.Wrap
                                                                maximumLineCount: 3
                                                                elide: Text.ElideNone
                                                                font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                                            }
                                                        }
                                                        SChoice {
                                                            text: "Arrange"
                                                            model: [{ label: "Grid", value: "grid" }, { label: "One row", value: "row" }, { label: "One column", value: "column" }]
                                                            current: Theme.sv("widgets.arrange", "grid")
                                                            onPicked: v => Theme.setUi("widgets.arrange", v)
                                                        }
                                                        SSlider { visible: Theme.sv("widgets.arrange", "grid") === "grid"; text: "Columns"; from: 1; to: 10; step: 1; value: Theme.sv("widgets.cols", 4); onMoved: v => Theme.setUi("widgets.cols", v) }
                                                        SSlider { text: "Tile size"; from: 70; to: 200; step: 5; value: Theme.sv("widgets.cell", 110); suffix: "px"; onMoved: v => Theme.setUi("widgets.cell", v) }
                                                        SSlider { text: "Space between"; from: 0; to: 24; step: 1; value: Theme.sv("widgets.gap", 8); suffix: "px"; onMoved: v => Theme.setUi("widgets.gap", v) }
                                                        SSlider { text: "Opacity"; from: 0.3; to: 1; step: 0.05; value: Theme.sv("widgets.opacity", 0.95); displayScale: 100; suffix: "%"; onMoved: v => Theme.setUi("widgets.opacity", v) }
                                                        SCheck { visible: !root.xfce; text: "On every screen (not just the main one)"; checked: Theme.sv("widgets.allScreens", false); onToggled: v => Theme.setUi("widgets.allScreens", v) }
                                                    }
                                                    SGroup {
                                                        title: "Your widgets (" + wpage.list.length + ")"
                                                        Repeater {
                                                            model: wpage.list
                                                            RowLayout {
                                                                id: wrow
                                                                required property var modelData
                                                                required property int index
                                                                readonly property var meta: Theme.widgetKinds.find(k => k.id === modelData.id) || { name: modelData.id, sizes: ["1x1"] }
                                                                Layout.fillWidth: true
                                                                spacing: 4
                                                                BText { text: (wrow.index + 1) + "."; color: Theme.textDim; Layout.preferredWidth: 22 }
                                                                BText { text: wrow.meta.name; font.bold: true; Layout.preferredWidth: 120 }
                                                                Row {
                                                                    spacing: 2
                                                                    Layout.fillWidth: true
                                                                    Repeater {
                                                                        model: wrow.meta.sizes
                                                                        SButton {
                                                                            required property string modelData
                                                                            implicitWidth: 44
                                                                            text: modelData.replace("x", "×")
                                                                            checked: (wrow.modelData.size || wrow.meta.sizes[0]) === modelData
                                                                            onClicked: {
                                                                                const l = JSON.parse(JSON.stringify(wpage.list));
                                                                                l[wrow.index].size = modelData;
                                                                                wpage.save(l);
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                                SButton { text: "▲"; implicitWidth: 30; onClicked: wpage.move(wrow.index, -1) }
                                                                SButton { text: "▼"; implicitWidth: 30; onClicked: wpage.move(wrow.index, 1) }
                                                                SButton {
                                                                    text: "Remove"
                                                                    onClicked: { const l = wpage.list.slice(); l.splice(wrow.index, 1); wpage.save(l); }
                                                                }
                                                            }
                                                        }
                                                        BText { visible: wpage.list.length === 0; text: "No widgets yet. Add some below."; color: Theme.textDim }
                                                    }
                                                    SGroup {
                                                        title: "Add a widget"
                                                        Flow {
                                                            Layout.fillWidth: true
                                                            spacing: 6
                                                            Repeater {
                                                                model: Theme.widgetKinds
                                                                Bevel {
                                                                    id: addCard
                                                                    required property var modelData
                                                                    width: 196
                                                                    height: addCol.implicitHeight + 12
                                                                    sunken: addMa.pressed
                                                                    depth: Math.min(2, Theme.bevel)
                                                                    Column {
                                                                        id: addCol
                                                                        x: 8; y: 6
                                                                        width: parent.width - 16
                                                                        BText { text: "+ " + addCard.modelData.name; font.bold: true }
                                                                        BText { width: parent.width; text: addCard.modelData.about; color: Theme.textDim; font.pixelSize: Math.max(10, Theme.fontSize - 3) }
                                                                    }
                                                                    MouseArea {
                                                                        id: addMa
                                                                        anchors.fill: parent
                                                                        cursorShape: Qt.PointingHandCursor
                                                                        onClicked: wpage.save(wpage.list.concat([{ id: addCard.modelData.id, size: addCard.modelData.sizes[0] }]))
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Widget options"
                                                        SField {
                                                            text: "ASCII text"
                                                            value: Theme.sv("widgets.asciiText", "BEVEL")
                                                            onAccepted: t => Theme.setUi("widgets.asciiText", t)
                                                        }
                                                        SChoice {
                                                            text: "ASCII style"
                                                            model: [{ label: "Blocks", value: "block" }, { label: "Shaded", value: "shade" }, { label: "Dots", value: "dots" }, { label: "# signs", value: "hash" }]
                                                            current: Theme.sv("widgets.asciiStyle", "block")
                                                            onPicked: v => Theme.setUi("widgets.asciiStyle", v)
                                                        }
                                                        SField {
                                                            text: "Weather city"
                                                            value: Theme.sv("widgets.weatherCity", "")
                                                            onAccepted: t => Theme.setUi("widgets.weatherCity", t.trim())
                                                        }
                                                        BText { text: "Leave the city empty to guess it from your connection."; color: Theme.textDim; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
                                                        SField {
                                                            text: "App tiles"
                                                            value: (Theme.sv("widgets.apps", null) || Theme.dockPinned).join(", ")
                                                            onAccepted: t => Theme.setUi("widgets.apps", t.split(",").map(x => x.trim()).filter(x => x !== ""))
                                                        }
                                                        BText { text: "App ids, comma separated (e.g. firefox, kitty, org.kde.dolphin)."; color: Theme.textDim; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
                                                        SField {
                                                            text: "World clock"
                                                            value: (Theme.sv("widgets.worldClocks", null) || ["London|Europe/London", "New York|America/New_York", "Tokyo|Asia/Tokyo"]).join(", ")
                                                            onAccepted: t => Theme.setUi("widgets.worldClocks", t.split(",").map(x => x.trim()).filter(x => x !== ""))
                                                        }
                                                        BText { text: "Name|Time zone, comma separated (e.g. Warsaw|Europe/Warsaw, Sydney|Australia/Sydney)."; color: Theme.textDim; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
                                                        SField {
                                                            text: "News feed"
                                                            value: Theme.sv("widgets.rssUrl", "") || "https://archlinux.org/feeds/news/"
                                                            onAccepted: t => Theme.setUi("widgets.rssUrl", t.trim())
                                                        }
                                                        SSlider { text: "Pomodoro focus"; from: 5; to: 60; step: 5; value: Theme.sv("widgets.pomodoroFocus", 25); suffix: " min"; onMoved: v => Theme.setUi("widgets.pomodoroFocus", v) }
                                                        SSlider { text: "Pomodoro break"; from: 1; to: 30; step: 1; value: Theme.sv("widgets.pomodoroBreak", 5); suffix: " min"; onMoved: v => Theme.setUi("widgets.pomodoroBreak", v) }
                                                    }
                                                }
                                                }
                                            }
                                        }

                                        // ===================== (15) Wallpaper (both)
                                        // built the first time you open the page
                                        Loader {
                                            active: false
                                            readonly property bool current: StackLayout.isCurrentItem
                                            onCurrentChanged: if (current) active = true
                                            Component.onCompleted: if (current) active = true
                                            sourceComponent: Component {
                                                Item {      // keeps the page its natural height (a Layout would stretch it)
                                                    implicitHeight: childrenRect.height
                                                ColumnLayout {
                                                    width: parent.width
                                                    spacing: 10
                                                    // picture or animation: two big 9x tabs
                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 0
                                                        Repeater {
                                                            model: [{ l: "Picture", v: "image", d: "a wallpaper from your folder" }, { l: "Animated", v: "live", d: Theme.liveKinds.length + " moving backgrounds in any colour" }]
                                                            Bevel {
                                                                id: modeTab
                                                                required property var modelData
                                                                readonly property bool on: (Theme.liveMode ? "live" : "image") === modelData.v
                                                                Layout.fillWidth: true
                                                                implicitHeight: modeCol.implicitHeight + 14
                                                                sunken: on
                                                                fill: on ? Theme.face2 : Theme.face
                                                                Rectangle { visible: modeTab.on; x: 2; y: 2; width: parent.width - 4; height: 3; color: Theme.accent }
                                                                Column {
                                                                    id: modeCol
                                                                    anchors.centerIn: parent
                                                                    spacing: 1
                                                                    BText { anchors.horizontalCenter: parent.horizontalCenter; text: (modeTab.on ? "● " : "○ ") + modeTab.modelData.l; font.bold: true; font.pixelSize: Theme.fontSize + 2 }
                                                                    BText { anchors.horizontalCenter: parent.horizontalCenter; text: modeTab.modelData.d; color: Theme.textDim; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
                                                                }
                                                                MouseArea {
                                                                    anchors.fill: parent
                                                                    cursorShape: Qt.PointingHandCursor
                                                                    onClicked: if (!modeTab.on) Theme.set("wallpaper.mode", modeTab.modelData.v)
                                                                }
                                                            }
                                                        }
                                                    }
                                                    SGroup {
                                                        visible: !Theme.liveMode
                                                        title: "Effect over the picture"
                                                        FxPicker { Layout.fillWidth: true; xfce: root.xfce }
                                                    }
                                                    // only the tab you're on is built (28 animation cards are heavy), and kept once built
                                                    Item {
                                                        Layout.fillWidth: true
                                                        implicitHeight: Theme.liveMode ? (liveLoad.item ? liveLoad.item.implicitHeight : 0)
                                                                                       : (wallLoad.item ? wallLoad.item.implicitHeight : 0)
                                                        Loader {
                                                            id: wallLoad
                                                            width: parent.width
                                                            visible: !Theme.liveMode
                                                            active: false
                                                            readonly property bool want: !Theme.liveMode
                                                            onWantChanged: if (want) active = true
                                                            Component.onCompleted: if (want) active = true
                                                            sourceComponent: WallBrowser {
                                                                walls: win.walls
                                                                loading: wallProc.running && win.walls.length === 0
                                                                status: win.thumbStatus
                                                                onRescan: win.loadWalls()
                                                            }
                                                        }
                                                        Loader {
                                                            id: liveLoad
                                                            width: parent.width
                                                            visible: Theme.liveMode
                                                            active: false
                                                            readonly property bool want: Theme.liveMode
                                                            onWantChanged: if (want) active = true
                                                            Component.onCompleted: if (want) active = true
                                                            sourceComponent: LivePicker { xfce: root.xfce }
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Options"
                                                        SField {
                                                            text: "Folder"
                                                            value: Theme.sv("wallpaper.folder", "~/Pictures/Wallpapers")
                                                            onAccepted: t => { Theme.setUi("wallpaper.folder", t); refreshWalls.restart(); }
                                                        }
                                                        Timer { id: refreshWalls; interval: 600; onTriggered: win.loadWalls() }
                                                        SCheck {
                                                            text: "Include pictures in folders inside it (they show up as folder filters)"
                                                            checked: Theme.sv("wallpaper.subfolders", true)
                                                            onToggled: v => { Theme.setUi("wallpaper.subfolders", v); refreshWalls.restart(); }
                                                        }
                                                        SChoice {
                                                            visible: !root.xfce
                                                            text: "Super+W picks"
                                                            model: [{ label: "Any wallpaper", value: "all" }, { label: "A favourite", value: "favorites" }]
                                                            current: Theme.sv("wallpaper.randomFrom", "all")
                                                            onPicked: v => Theme.setUi("wallpaper.randomFrom", v)
                                                        }
                                                        BText {
                                                            visible: !root.xfce
                                                            text: "With an animated background on, Super+W picks a random animation instead."
                                                            color: Theme.textDim
                                                            font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                                        }
                                                        SChoice {
                                                            visible: !root.xfce
                                                            text: "Transition"
                                                            model: [{ label: "grow", value: "grow" }, { label: "wipe", value: "wipe" }, { label: "fade", value: "fade" },
                                                                    { label: "outer", value: "outer" }, { label: "any", value: "any" }, { label: "none", value: "none" }]
                                                            current: Theme.sv("wallpaper.transition", "grow")
                                                            onPicked: v => Theme.setUi("wallpaper.transition", v)
                                                        }
                                                    }
                                                }
                                                }
                                            }
                                        }

                                        // ===================== (16) Themes (both)
                                        // built the first time you open the page
                                        Loader {
                                            active: false
                                            readonly property bool current: StackLayout.isCurrentItem
                                            onCurrentChanged: if (current) active = true
                                            Component.onCompleted: if (current) active = true
                                            sourceComponent: Component {
                                                Item {      // keeps the page its natural height (a Layout would stretch it)
                                                    implicitHeight: childrenRect.height
                                                ColumnLayout {
                                                    width: parent.width
                                                    id: tpage
                                                    spacing: 14
                                                    property var themes: []
                                                    property string message: ""
                                                    function load() { themeList.running = true; }
                                                    Component.onCompleted: load()
                                                    Process {
                                                        id: themeList
                                                        command: ["bevelctl", "theme", "list"]
                                                        stdout: StdioCollector { onStreamFinished: { try { tpage.themes = JSON.parse(text); } catch (e) { tpage.themes = []; } } }
                                                    }
                                                    Process {
                                                        id: themeAct
                                                        stdout: StdioCollector { onStreamFinished: if (text.trim() !== "") tpage.message = "Saved: " + text.trim() }
                                                        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") tpage.message = text.trim() }
                                                        onExited: tpage.load()
                                                    }
                                                    function act(args) { tpage.message = ""; Theme.flushNow(); themeAct.command = ["bevelctl", "theme"].concat(args); themeAct.running = true; }

                                                    SGroup {
                                                        title: "Themes"
                                                        BText {
                                                            Layout.fillWidth: true
                                                            text: "A theme is your whole look in one .bevel file: wallpaper or animation, colours, bar, launcher, widgets and style. Click one to try it — \"Undo\" brings back what you had."
                                                            color: Theme.textDim
                                                            wrapMode: Text.Wrap
                                                            maximumLineCount: 3
                                                            elide: Text.ElideNone
                                                        }
                                                        GridLayout {
                                                            Layout.fillWidth: true
                                                            columns: Math.max(2, Math.floor(width / 190))
                                                            columnSpacing: 8
                                                            rowSpacing: 8
                                                            Repeater {
                                                                model: tpage.themes
                                                                Bevel {
                                                                    id: tcard
                                                                    required property var modelData
                                                                    Layout.fillWidth: true
                                                                    implicitHeight: tthumb.height + tname.implicitHeight + 16
                                                                    sunken: tma.pressed
                                                                    depth: Math.min(2, Theme.bevel)
                                                                    Rectangle {
                                                                        id: tthumb
                                                                        x: 5; y: 5
                                                                        width: parent.width - 10
                                                                        height: Math.round(width * 9 / 16)
                                                                        color: Theme.dark
                                                                        border.color: tma.containsMouse ? Theme.accent : Theme.lo
                                                                        Image {
                                                                            anchors.fill: parent
                                                                            anchors.margins: 1
                                                                            source: tcard.modelData.thumb ? "file://" + tcard.modelData.thumb : ""
                                                                            fillMode: Image.PreserveAspectCrop
                                                                            asynchronous: true
                                                                        }
                                                                        Row {
                                                                            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 4
                                                                            visible: !tcard.modelData.thumb
                                                                            Repeater {
                                                                                model: tcard.modelData.swatch || []
                                                                                Rectangle { required property string modelData; width: 18; height: 18; color: modelData }
                                                                            }
                                                                        }
                                                                        Rectangle {
                                                                            visible: tcard.modelData.live
                                                                            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 4
                                                                            width: liveTag.implicitWidth + 8; height: liveTag.implicitHeight + 2
                                                                            color: Qt.rgba(0, 0, 0, 0.6)
                                                                            BText { id: liveTag; anchors.centerIn: parent; text: "animated"; color: "white"; font.pixelSize: 10 }
                                                                        }
                                                                    }
                                                                    Column {
                                                                        id: tname
                                                                        anchors.top: tthumb.bottom
                                                                        anchors.topMargin: 4
                                                                        x: 6
                                                                        width: parent.width - 12
                                                                        BText { width: parent.width; text: tcard.modelData.name; font.bold: true }
                                                                        BText { width: parent.width; text: tcard.modelData.builtin ? "built in" : ("by " + (tcard.modelData.author || "you")); color: Theme.textDim; font.pixelSize: Math.max(10, Theme.fontSize - 3) }
                                                                    }
                                                                    MouseArea {
                                                                        id: tma
                                                                        anchors.fill: parent
                                                                        hoverEnabled: true
                                                                        cursorShape: Qt.PointingHandCursor
                                                                        onClicked: tpage.act(["apply", tcard.modelData.path])
                                                                    }
                                                                    BText {
                                                                        visible: !tcard.modelData.builtin && tma.containsMouse
                                                                        anchors.right: parent.right; anchors.rightMargin: 6
                                                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                                                                        text: "Delete"
                                                                        color: "#c0392b"
                                                                        font.pixelSize: Math.max(10, Theme.fontSize - 3)
                                                                        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: tpage.act(["delete", tcard.modelData.name]) }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                        RowLayout {
                                                            spacing: 6
                                                            SButton { text: "Undo last theme"; onClicked: tpage.act(["undo"]) }
                                                            SButton { text: "Refresh"; onClicked: tpage.load() }
                                                            BText { Layout.fillWidth: true; text: tpage.message; color: Theme.textDim; wrapMode: Text.Wrap; maximumLineCount: 2 }
                                                        }
                                                    }
                                                    SGroup {
                                                        title: "Save my look as a theme"
                                                        SField { id: tName; text: "Name"; value: "My Bevel" }
                                                        SField { id: tAuthor; text: "Made by"; value: Quickshell.env("USER") || "" }
                                                        SCheck { id: tWall; text: "Include the wallpaper picture (so it looks the same for whoever you send it to)"; checked: true }
                                                        RowLayout {
                                                            spacing: 6
                                                            SButton {
                                                                text: "Export…"
                                                                highlighted: true
                                                                onClicked: {
                                                                    const name = tName.currentText || "My Bevel";
                                                                    const author = tAuthor.currentText || "";
                                                                    tpage.act(["export", name, "--author", author].concat(tWall.checked ? [] : ["--no-wallpaper"]));
                                                                }
                                                            }
                                                            SButton { text: "Open the themes folder"; onClicked: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$HOME/Bevel Themes\" && exec xdg-open \"$HOME/Bevel Themes\""]) }
                                                        }
                                                        BText { text: "Saved to ~/Bevel Themes as a single .bevel file you can share."; color: Theme.textDim; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
                                                    }
                                                    SGroup {
                                                        title: "Import a theme"
                                                        SField { id: tFile; text: "File"; value: ""; onAccepted: t => { if (t.trim() !== "") tpage.act(["import", t.trim().replace(/^file:\/\//, "").replace(/^~/, Theme.home)]); } }
                                                        BText {
                                                            Layout.fillWidth: true
                                                            text: "Paste the path of a .bevel file and press Enter — or just double-click the file in your file manager. Imported themes show up above."
                                                            color: Theme.textDim
                                                            wrapMode: Text.Wrap
                                                            maximumLineCount: 2
                                                            elide: Text.ElideNone
                                                            font.pixelSize: Math.max(10, Theme.fontSize - 2)
                                                        }
                                                    }
                                                }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // status bar
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 2
                            Layout.rightMargin: 2
                            Layout.bottomMargin: 2
                            spacing: 3
                            Bevel {
                                Layout.fillWidth: true
                                implicitHeight: Theme.fontSize + 8
                                sunken: true; depth: 1; fill: "transparent"
                                BText { anchors.fill: parent; anchors.leftMargin: 6; text: "Changes apply instantly · saved to ~/.config/bevel/settings.json" }
                            }
                            Bevel {
                                Layout.preferredWidth: 220
                                implicitHeight: Theme.fontSize + 8
                                sunken: true; depth: 1; fill: "transparent"
                                BText {
                                    anchors.fill: parent; anchors.leftMargin: 6
                                    text: "Theme: " + (Theme.wallpaper ? Theme.wallpaper.split("/").pop() : "custom")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
