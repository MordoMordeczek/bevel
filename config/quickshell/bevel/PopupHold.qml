import QtQuick

// Put one inside a popup window: while it's showing (active), Ui.focusedScreen stays put
// (the popup opened on the monitor you were using, and stays there).
QtObject {
    property bool active: true
    property bool counted: false
    function sync() {
        if (active && !counted) { Ui.popups++; counted = true; }
        else if (!active && counted) { Ui.popups--; counted = false; }
    }
    onActiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (counted) Ui.popups--
}
