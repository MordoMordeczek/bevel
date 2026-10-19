import Quickshell
import QtQuick
import QtQuick.Layouts

// Wallpaper browser for big collections: search, sort, favourites, recent, folders, view size.
// walls: [{ path, thumb, name, folder, mtime, w, h }] from `bevelctl thumbs`
ColumnLayout {
    id: root
    property var walls: []
    property bool loading: false
    property string status: ""
    signal rescan()

    spacing: 6
    Layout.fillWidth: true

    // pickKey "" = the desktop wallpaper; e.g. "login.wallpaper" = pick a picture for that setting
    property string pickKey: ""
    property int gridHeight: 336
    readonly property string current: pickKey === "" ? Theme.sv("wallpaper.path", "") : Theme.sv(pickKey, "")
    readonly property bool liveOn: pickKey === "" && Theme.liveMode
    function choose(path) {
        if (root.pickKey === "") Theme.setWallpaper(path);
        else Theme.set(root.pickKey, path);
    }
    readonly property var favs: Theme.sv("wallpaper.favorites", []) || []
    readonly property var recent: Theme.sv("wallpaper.recent", []) || []
    readonly property string sortBy: Theme.sv("wallpaper.browser.sort", "name")
    readonly property string viewSize: Theme.sv("wallpaper.browser.size", "medium")
    property string filter: "all"          // all | favorites | recent | folder:<name>
    property string query: ""

    function isFav(p) { return root.favs.indexOf(p) >= 0; }
    function toggleFav(p) {
        const f = root.favs.slice();
        const i = f.indexOf(p);
        if (i >= 0) f.splice(i, 1); else f.push(p);
        Theme.setUi("wallpaper.favorites", f);
    }

    readonly property var folders: {
        const m = {};
        for (const w of root.walls) if (w.folder) m[w.folder] = (m[w.folder] || 0) + 1;
        return Object.keys(m).sort((a, b) => a.toLowerCase() < b.toLowerCase() ? -1 : 1).map(k => ({ name: k, count: m[k] }));
    }
    readonly property int favCount: root.walls.filter(w => root.favs.indexOf(w.path) >= 0).length

    readonly property var shown: {
        let list = root.walls;
        const q = root.query.trim().toLowerCase();
        if (root.filter === "favorites")
            list = list.filter(w => root.favs.indexOf(w.path) >= 0);
        else if (root.filter === "recent") {
            const byPath = {};
            for (const w of list) byPath[w.path] = w;
            list = root.recent.map(p => byPath[p]).filter(w => w !== undefined);
        } else if (root.filter.startsWith("folder:")) {
            const f = root.filter.substring(7);
            list = list.filter(w => w.folder === f || w.folder.startsWith(f + "/"));
        }
        if (q !== "") {
            const words = q.split(/\s+/);
            list = list.filter(w => {
                const hay = (w.name + " " + w.folder).toLowerCase();
                return words.every(x => hay.indexOf(x) >= 0);
            });
        }
        if (root.filter !== "recent") {
            list = list.slice();
            const byName = (a, b) => a.name.toLowerCase() < b.name.toLowerCase() ? -1 : (a.name.toLowerCase() > b.name.toLowerCase() ? 1 : 0);
            if (root.sortBy === "newest") list.sort((a, b) => (b.mtime - a.mtime) || byName(a, b));
            else if (root.sortBy === "oldest") list.sort((a, b) => (a.mtime - b.mtime) || byName(a, b));
            else if (root.sortBy === "favorites") list.sort((a, b) => ((root.favs.indexOf(b.path) >= 0) - (root.favs.indexOf(a.path) >= 0)) || byName(a, b));
            else if (root.sortBy === "folder") list.sort((a, b) => a.folder.toLowerCase() < b.folder.toLowerCase() ? -1 : (a.folder.toLowerCase() > b.folder.toLowerCase() ? 1 : byName(a, b)));
            else list.sort(byName);
        }
        return list;
    }

    function jumpToCurrent() {
        for (let i = 0; i < root.shown.length; i++) {
            if (root.shown[i].path === root.current) {
                grid.positionViewAtIndex(i, GridView.Center);
                list.positionViewAtIndex(i, ListView.Center);
                return;
            }
        }
    }
    onShownChanged: Qt.callLater(() => { if (grid.contentY > grid.contentHeight) grid.contentY = 0; })

    // a small 9x segmented button
    component Seg: Bevel {
        id: seg
        property string label: ""
        property bool on: false
        signal hit()
        sunken: on || segMa.pressed
        fill: on ? Theme.face2 : Theme.face
        depth: Math.min(2, Theme.bevel)
        radius: Theme.radiusSm
        implicitWidth: segText.implicitWidth + 16
        implicitHeight: Theme.fontSize + 10
        BText { id: segText; anchors.centerIn: parent; text: seg.label; font.bold: seg.on; font.pixelSize: Math.max(10, Theme.fontSize - 1) }
        MouseArea { id: segMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: seg.hit() }
    }

    // ---- toolbar: search · sort · size
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Bevel {
            Layout.fillWidth: true
            Layout.minimumWidth: 140
            implicitHeight: Theme.fontSize + 12
            sunken: true
            fill: Theme.base
            radius: Theme.radiusSm
            padding: 2
            BText {
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === "" && !search.activeFocus
                text: "Search " + root.walls.length + " wallpapers…"
                color: Theme.textDim
            }
            TextInput {
                id: search
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 20
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentText
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                clip: true
                selectByMouse: true
                onTextChanged: queryDelay.restart()
                Keys.onEscapePressed: event => { if (text !== "") { text = ""; event.accepted = true; } else event.accepted = false; }
            }
            Timer { id: queryDelay; interval: 120; onTriggered: root.query = search.text }
            BText {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: search.text === "" ? "⌕" : "✕"
                color: Theme.textDim
                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: { search.text = ""; root.query = ""; } }
            }
        }
        BText { text: "Sort"; color: Theme.textDim }
        Row {
            spacing: 2
            Repeater {
                model: [{ l: "A–Z", v: "name" }, { l: "Newest", v: "newest" }, { l: "Oldest", v: "oldest" }, { l: "★ first", v: "favorites" }, { l: "Folder", v: "folder" }]
                Seg {
                    required property var modelData
                    label: modelData.l
                    on: root.sortBy === modelData.v
                    onHit: Theme.setUi("wallpaper.browser.sort", modelData.v)
                }
            }
        }
    }

    // ---- filters: all · favourites · recent · folders, plus the view size
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Flow {
            Layout.fillWidth: true
            spacing: 3
            Seg { label: "All  " + root.walls.length; on: root.filter === "all"; onHit: root.filter = "all" }
            Seg { label: "★ Favourites  " + root.favCount; on: root.filter === "favorites"; onHit: root.filter = "favorites" }
            Seg { label: "Recent"; on: root.filter === "recent"; onHit: root.filter = "recent" }
            Repeater {
                model: root.folders.length > 1 || (root.folders.length === 1 && root.folders[0].count < root.walls.length) ? root.folders.filter(f => f.name.indexOf("/") < 0) : []
                Seg {
                    required property var modelData
                    label: "▸ " + modelData.name + "  " + root.walls.filter(w => w.folder === modelData.name || w.folder.startsWith(modelData.name + "/")).length
                    on: root.filter === "folder:" + modelData.name
                    onHit: root.filter = "folder:" + modelData.name
                }
            }
        }
        Row {
            spacing: 2
            Layout.alignment: Qt.AlignTop
            Repeater {
                model: [{ l: "▪", v: "small" }, { l: "■", v: "medium" }, { l: "█", v: "large" }, { l: "≡", v: "list" }]
                Seg {
                    required property var modelData
                    label: modelData.l
                    on: root.viewSize === modelData.v
                    implicitWidth: 28
                    onHit: Theme.setUi("wallpaper.browser.size", modelData.v)
                }
            }
        }
    }

    // ---- the pictures
    Bevel {
        id: frame
        Layout.fillWidth: true
        Layout.preferredHeight: root.gridHeight
        sunken: true
        fill: Theme.base
        padding: 2

        readonly property int cellW: root.viewSize === "small" ? 104 : (root.viewSize === "large" ? 204 : 140)
        readonly property real cols: Math.max(1, Math.floor((width - 16) / cellW))
        readonly property real tileW: Math.floor((width - 16) / cols)

        MouseArea {
            // wheel / two-finger scrolling for the grid (the page itself scrolls elsewhere)
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                const v = root.viewSize === "list" ? list : grid;
                const dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y;
                v.contentY = Math.max(v.originY, Math.min(v.originY + Math.max(0, v.contentHeight - v.height), v.contentY - dy));
                wheel.accepted = true;
            }

            GridView {
                id: grid
                visible: root.viewSize !== "list"
                anchors.fill: parent
                anchors.rightMargin: 10
                clip: true
                interactive: false
                cellWidth: frame.tileW
                cellHeight: Math.round((frame.tileW - 8) * 0.625) + (root.viewSize === "small" ? 8 : 26)
                model: visible ? root.shown : []
                cacheBuffer: 400
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    readonly property bool isCurrent: !root.liveOn && modelData.path === root.current
                    readonly property bool fav: root.favs.indexOf(modelData.path) >= 0

                    Item {
                        id: pic
                        x: 4; y: 4
                        width: parent.width - 8
                        height: Math.round(width * 0.625)
                        Rectangle { anchors.fill: parent; color: Theme.face2 }
                        BText {
                            anchors.centerIn: parent
                            width: parent.width - 8
                            horizontalAlignment: Text.AlignHCenter
                            visible: img.status !== Image.Ready
                            text: tile.modelData.name
                            color: Theme.textDim
                            font.pixelSize: Math.max(9, Theme.fontSize - 3)
                        }
                        Image {
                            id: img
                            anchors.fill: parent
                            source: tile.modelData.thumb ? "file://" + tile.modelData.thumb : ""
                            sourceSize.width: 320
                            sourceSize.height: 200
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: tile.isCurrent ? -3 : 0
                            color: "transparent"
                            border.color: tile.isCurrent ? Theme.accent : Theme.hi
                            border.width: tile.isCurrent ? 3 : 1
                            visible: tile.isCurrent || tileMa.containsMouse
                        }
                        // favourite star
                        Rectangle {
                            visible: tile.fav || tileMa.containsMouse
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 3
                            width: 20; height: 20
                            radius: Theme.radiusSm
                            color: tile.fav ? Theme.accent : Qt.rgba(0, 0, 0, 0.45)
                            border.color: Theme.dark
                            Text {
                                anchors.centerIn: parent
                                text: tile.fav ? "★" : "☆"
                                color: tile.fav ? Theme.accentText : "white"
                                font.pixelSize: 14
                            }
                        }
                    }
                    BText {
                        visible: root.viewSize !== "small"
                        anchors.top: pic.bottom
                        anchors.topMargin: 3
                        x: 4
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.modelData.name
                        font.bold: tile.isCurrent
                        font.pixelSize: Math.max(10, Theme.fontSize - 2)
                        color: tile.isCurrent ? Theme.accent : Theme.text
                    }
                    MouseArea {
                        id: tileMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            const star = mouse.x > pic.x + pic.width - 26 && mouse.y < pic.y + 26;
                            if (mouse.button === Qt.RightButton || star) root.toggleFav(tile.modelData.path);
                            else root.choose(tile.modelData.path);
                        }
                    }
                }
            }

            ListView {
                id: list
                visible: root.viewSize === "list"
                anchors.fill: parent
                anchors.rightMargin: 10
                clip: true
                interactive: false
                model: visible ? root.shown : []
                cacheBuffer: 400
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: !root.liveOn && modelData.path === root.current
                    readonly property bool fav: root.favs.indexOf(modelData.path) >= 0
                    width: list.width
                    height: 44
                    color: isCurrent ? Theme.accent : (rowMa.containsMouse ? Theme.face2 : (index % 2 ? Theme.base : Qt.tint(Theme.base, Qt.rgba(Theme.face.r, Theme.face.g, Theme.face.b, 0.25))))
                    Image {
                        id: rimg
                        x: 4; y: 4
                        width: 58; height: 36
                        source: row.modelData.thumb ? "file://" + row.modelData.thumb : ""
                        sourceSize.width: 116
                        sourceSize.height: 72
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Column {
                        anchors.left: rimg.right
                        anchors.leftMargin: 10
                        anchors.right: rstar.left
                        anchors.verticalCenter: parent.verticalCenter
                        BText {
                            width: parent.width
                            text: row.modelData.name
                            font.bold: row.isCurrent
                            color: row.isCurrent ? Theme.accentText : Theme.text
                        }
                        BText {
                            width: parent.width
                            text: [row.modelData.folder || "", row.modelData.w ? row.modelData.w + "×" + row.modelData.h : "",
                                   row.modelData.mtime ? new Date(row.modelData.mtime * 1000).toLocaleDateString(Qt.locale(), Locale.ShortFormat) : ""].filter(x => x).join("  ·  ")
                            color: row.isCurrent ? Theme.accentText : Theme.textDim
                            font.pixelSize: Math.max(9, Theme.fontSize - 3)
                        }
                    }
                    Text {
                        id: rstar
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.fav ? "★" : "☆"
                        font.pixelSize: 18
                        color: row.isCurrent ? Theme.accentText : (row.fav ? Theme.accent : Theme.textDim)
                    }
                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton || mouse.x > width - 40) root.toggleFav(row.modelData.path);
                            else root.choose(row.modelData.path);
                        }
                    }
                }
            }

            // scrollbar
            Rectangle {
                readonly property var v: root.viewSize === "list" ? list : grid
                visible: v.contentHeight > v.height
                anchors.right: parent.right
                y: v.height * (v.contentY - v.originY) / Math.max(1, v.contentHeight)
                width: 7
                height: Math.max(24, v.height * v.height / Math.max(1, v.contentHeight))
                color: Theme.lo
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    drag.target: null
                    property real startY: 0
                    property real startC: 0
                    onPressed: mouse => { startY = mapToItem(frame, 0, mouse.y).y; startC = parent.v.contentY; }
                    onPositionChanged: mouse => {
                        const v = parent.v;
                        const dy = mapToItem(frame, 0, mouse.y).y - startY;
                        v.contentY = Math.max(v.originY, Math.min(v.originY + Math.max(0, v.contentHeight - v.height), startC + dy * v.contentHeight / v.height));
                    }
                }
            }

            BText {
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 3
                visible: root.shown.length === 0
                color: Theme.textDim
                text: root.loading ? "Looking for wallpapers…"
                    : root.walls.length === 0 ? "No pictures in " + Theme.sv("wallpaper.folder", "~/Pictures/Wallpapers") + " yet. Put some there and press Rescan."
                    : root.filter === "favorites" && root.query === "" ? "No favourites yet. Click the ☆ on a picture (or right-click it) to add it here."
                    : root.filter === "recent" && root.query === "" ? "Pictures you pick show up here."
                    : "Nothing matches \"" + root.query + "\"."
            }
        }
    }

    // ---- status + actions
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        BText {
            Layout.fillWidth: true
            color: Theme.textDim
            text: root.status !== "" ? root.status
                : (root.shown.length === root.walls.length ? root.walls.length + " wallpapers" : root.shown.length + " of " + root.walls.length)
                  + (root.liveOn ? "  ·  click one to switch back from the animation" : "  ·  right-click = ★")
        }
        SButton { text: "Show current"; visible: !root.liveOn && root.current !== ""; onClicked: { root.filter = "all"; search.text = ""; root.query = ""; Qt.callLater(root.jumpToCurrent); } }
        SButton { text: "Same as desktop"; visible: root.pickKey !== ""; checked: root.current === ""; onClicked: Theme.set(root.pickKey, "") }
        SButton { text: "Random"; visible: root.pickKey === ""; onClicked: Theme.run(["bevelctl", "random", "all"]) }
        SButton { text: "Random ★"; visible: root.pickKey === "" && root.favCount > 1; onClicked: Theme.run(["bevelctl", "random", "favorites"]) }
        SButton { text: "Rescan"; visible: root.pickKey === ""; onClicked: root.rescan() }
        SButton { text: "Open folder"; visible: root.pickKey === ""; onClicked: Quickshell.execDetached(["xdg-open", Theme.sv("wallpaper.folder", "~/Pictures/Wallpapers").replace(/^~/, Theme.home)]) }
    }
}
