import QtQuick

// Tiny pixel-ish icons drawn with a Canvas so they follow the theme colors.
Canvas {
    id: ic
    property string kind: "volume"
    property real level: 1          // 0..1, used by battery / wifi
    property color color: Theme.text
    property color accent: Theme.accent
    implicitWidth: kind === "battery" ? 20 : 14
    implicitHeight: 12
    antialiasing: false

    onKindChanged: requestPaint()
    onLevelChanged: requestPaint()
    onColorChanged: requestPaint()
    onAccentChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const g = getContext("2d");
        g.reset();
        g.fillStyle = ic.color;
        g.strokeStyle = ic.color;
        g.lineWidth = 1;
        const w = width, h = height;
        if (kind === "wifi" || kind === "wifi-off") {
            const bars = kind === "wifi-off" ? 0 : Math.max(1, Math.round(level * 3));
            for (let i = 0; i < 3; i++) {
                const bh = 4 + i * 3.5;
                if (i < bars) g.fillRect(1 + i * 4.5, h - bh, 3, bh);
                else g.strokeRect(1.5 + i * 4.5, h - bh + 0.5, 2, bh - 1);
            }
        } else if (kind === "wired") {
            g.fillRect(2, 2, 10, 5);
            g.fillRect(6, 7, 2, 3);
            g.fillRect(1, 10, 12, 2);
        } else if (kind === "volume" || kind === "mute") {
            g.beginPath();
            g.moveTo(1, 4); g.lineTo(4, 4); g.lineTo(8, 1); g.lineTo(8, 11); g.lineTo(4, 8); g.lineTo(1, 8);
            g.closePath(); g.fill();
            if (kind === "mute") {
                g.beginPath(); g.moveTo(10, 4); g.lineTo(13, 8); g.moveTo(13, 4); g.lineTo(10, 8); g.stroke();
            } else {
                g.fillRect(10, 5, 1, 2);
                if (level > 0.33) g.fillRect(12, 3, 1, 6);
            }
        } else if (kind === "battery") {
            g.strokeRect(0.5, 1.5, w - 3.5, h - 3);
            g.fillRect(w - 2, 4, 2, h - 8);
            g.fillStyle = level < 0.15 ? "#cc3333" : ic.color;
            g.fillRect(2, 3, Math.max(1, (w - 6) * Math.max(0, Math.min(1, level))), h - 6);
        } else if (kind === "bright") {
            g.fillRect(4, 4, 6, 4);
            g.fillRect(6, 0, 2, 2); g.fillRect(6, 10, 2, 2);
            g.fillRect(0, 5, 2, 2); g.fillRect(12, 5, 2, 2);
        } else if (kind === "cpu") {
            g.strokeRect(2.5, 2.5, 9, 7);
            g.fillRect(5, 5, 4, 2);
            for (let i = 0; i < 3; i++) { g.fillRect(4 + i * 2.5, 0, 1, 2); g.fillRect(4 + i * 2.5, 10, 1, 2); }
        }
    }
}
