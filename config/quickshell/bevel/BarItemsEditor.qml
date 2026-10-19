import QtQuick
import QtQuick.Layouts

// Settings → Bar → Items: what's on the bar and where. Three columns (left, centre, right);
// move things with the arrows, × takes one off, and the buttons underneath put one back.
ColumnLayout {
    id: ed
    spacing: 8
    readonly property var cur: Theme.barItems
    readonly property var groups: [{ key: "left", name: "Left" }, { key: "center", name: "Centre" }, { key: "right", name: "Right" }]
    function nameOf(id) { const m = Theme.barModuleInfo.find(x => x.id === id); return m ? m.name : id; }
    function copy() { return { left: ed.cur.left.slice(), center: ed.cur.center.slice(), right: ed.cur.right.slice() }; }
    function move(g, i, dg, di) {
        const c = ed.copy();
        const keys = ["left", "center", "right"];
        const item = c[g][i];
        if (dg !== 0) {
            const ng = keys[keys.indexOf(g) + dg];
            if (!ng) return;
            c[g].splice(i, 1);
            if (dg > 0) c[ng].unshift(item); else c[ng].push(item);
        } else {
            const j = i + di;
            if (j < 0 || j >= c[g].length) return;
            c[g][i] = c[g][j];
            c[g][j] = item;
        }
        Theme.setBarItems(c);
    }
    // no separator at the very start or end of a group
    function tidy(c) {
        for (const k of ["left", "center", "right"]) {
            while (c[k].length && c[k][0] === "sep") c[k].shift();
            while (c[k].length && c[k][c[k].length - 1] === "sep") c[k].pop();
        }
        return c;
    }
    function remove(g, i) { const c = ed.copy(); c[g].splice(i, 1); Theme.setBarItems(c); }
    function add(id) { const c = ed.copy(); c.right.unshift(id); Theme.setBarItems(c); }
    readonly property var hidden: Theme.barModuleInfo.filter(m => m.many || (ed.cur.left.concat(ed.cur.center, ed.cur.right).indexOf(m.id) < 0))

    BText {
        Layout.fillWidth: true
        text: "For the \"" + ({ bevel: "Bevel", dock: "Dock", island: "Islands", taskbar: "Taskbar" })[Theme.barLayout] + "\" layout. Click an item on the bar to open its menu."
        color: Theme.textDim
        wrapMode: Text.Wrap
        font.pixelSize: Math.max(10, Theme.fontSize - 2)
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: ed.groups
            Bevel {
                id: col
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                implicitHeight: colBody.implicitHeight + 10
                sunken: true
                fill: Theme.base
                ColumnLayout {
                    id: colBody
                    x: 5; y: 5
                    width: parent.width - 10
                    spacing: 2
                    BText { text: col.modelData.name; font.bold: true; color: Theme.accent }
                    BText {
                        visible: ed.cur[col.modelData.key].length === 0
                        text: "(empty)"
                        color: Theme.textDim
                        font.pixelSize: Math.max(10, Theme.fontSize - 2)
                    }
                    Repeater {
                        model: ed.cur[col.modelData.key]
                        Rectangle {
                            id: row
                            required property string modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: Theme.fontSize + 10
                            color: rowMa.containsMouse ? Theme.face2 : "transparent"
                            MouseArea { id: rowMa; anchors.fill: parent; hoverEnabled: true }
                            BText {
                                anchors.left: parent.left
                                anchors.leftMargin: 3
                                anchors.right: btns.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: ed.nameOf(row.modelData)
                                font.pixelSize: Math.max(10, Theme.fontSize - 1)
                            }
                            Row {
                                id: btns
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Mini { label: "◂"; on: col.index > 0; onHit: ed.move(col.modelData.key, row.index, -1, 0) }
                                Mini { label: "▴"; on: row.index > 0; onHit: ed.move(col.modelData.key, row.index, 0, -1) }
                                Mini { label: "▾"; on: row.index < ed.cur[col.modelData.key].length - 1; onHit: ed.move(col.modelData.key, row.index, 0, 1) }
                                Mini { label: "▸"; on: col.index < 2; onHit: ed.move(col.modelData.key, row.index, 1, 0) }
                                Mini { label: "×"; onHit: ed.remove(col.modelData.key, row.index) }
                            }
                        }
                    }
                }
            }
        }
    }
    BText { text: "Add to the bar:"; color: Theme.textDim; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
    Flow {
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: ed.hidden
            SButton {
                required property var modelData
                text: "+ " + modelData.name
                onClicked: ed.add(modelData.id)
            }
        }
    }
    RowLayout {
        spacing: 6
        SButton { text: "Workspaces in the middle"; onClicked: { const c = ed.copy(); for (const k of ["left", "right"]) c[k] = c[k].filter(x => x !== "workspaces"); c.center = ["workspaces"].concat(c.center.filter(x => x !== "workspaces")); Theme.setBarItems(ed.tidy(c)); } }
        SButton { text: "Clock in the middle"; onClicked: { const c = ed.copy(); for (const k of ["left", "right"]) c[k] = c[k].filter(x => x !== "clock"); c.center = c.center.filter(x => x !== "clock").concat(["clock"]); Theme.setBarItems(ed.tidy(c)); } }
        SButton { text: "Reset"; onClicked: Theme.setBarItems(Theme.barDefaults(Theme.barLayout)) }
    }

    component Mini: Bevel {
        id: mini
        property string label: ""
        property bool on: true
        signal hit()
        width: Theme.fontSize + 6
        height: Theme.fontSize + 6
        depth: 1
        sunken: miniMa.pressed
        opacity: on ? 1 : 0.3
        BText { anchors.centerIn: parent; text: mini.label; font.pixelSize: Math.max(10, Theme.fontSize - 2) }
        MouseArea { id: miniMa; anchors.fill: parent; enabled: mini.on; onClicked: mini.hit() }
    }
}
