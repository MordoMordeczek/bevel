pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Notifications you've had (newest first), kept across restarts for the control panel's list.
Singleton {
    id: h
    property var items: []
    property int unseen: 0
    readonly property string file: Quickshell.env("HOME") + "/.cache/bevel/notifications.json"

    FileView {
        id: store
        path: h.file
        blockLoading: true
        printErrors: false
        onLoaded: { try { const j = JSON.parse(text()); h.items = j.items || []; h.unseen = j.unseen || 0; } catch (e) {} }
    }
    Component.onCompleted: { try { const j = JSON.parse(store.text()); h.items = j.items || []; h.unseen = j.unseen || 0; } catch (e) {} }
    Timer { id: saveLater; interval: 800; onTriggered: store.setText(JSON.stringify({ items: h.items, unseen: h.unseen })) }

    function add(n) {
        const it = {
            id: Date.now() + "-" + Math.floor(Math.random() * 1e6),
            app: n.appName || "", summary: n.summary || "", body: (n.body || "").slice(0, 400),
            icon: n.appIcon || "", time: Date.now(), critical: !!n.critical
        };
        h.items = [it].concat(h.items).slice(0, 60);
        h.unseen++;
        saveLater.restart();
    }
    function remove(id) { h.items = h.items.filter(x => x.id !== id); saveLater.restart(); }
    function clear() { h.items = []; h.unseen = 0; saveLater.restart(); }
    function seen() { if (h.unseen !== 0) { h.unseen = 0; saveLater.restart(); } }
    function ago(t) {
        const s = Math.max(0, (Date.now() - t) / 1000);
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + " min ago";
        if (s < 86400) return Math.floor(s / 3600) + " h ago";
        return new Date(t).toLocaleDateString(Qt.locale(), "d MMM");
    }
}
