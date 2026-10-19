import QtQuick

// Chunky little power-menu icons: lock · logout · suspend · restart · shutdown
Canvas {
    id: g
    property string kind: "shutdown"
    property color color: Theme.text
    implicitWidth: 32
    implicitHeight: 32
    onColorChanged: requestPaint()
    onKindChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.reset();
        const s = Math.min(width, height) / 32;
        c.scale(s, s);
        c.strokeStyle = g.color;
        c.fillStyle = g.color;
        c.lineWidth = 3;
        c.lineCap = "square";
        c.lineJoin = "miter";
        if (kind === "lock") {
            c.fillRect(7, 14, 18, 14);
            c.beginPath(); c.moveTo(11, 14); c.lineTo(11, 9); c.arc(16, 9, 5, Math.PI, 0); c.lineTo(21, 14); c.stroke();
        } else if (kind === "logout") {
            c.strokeRect(5, 5, 14, 22);
            c.beginPath(); c.moveTo(14, 16); c.lineTo(28, 16); c.stroke();
            c.beginPath(); c.moveTo(23, 11); c.lineTo(28, 16); c.lineTo(23, 21); c.stroke();
        } else if (kind === "suspend") {
            c.beginPath(); c.arc(16, 16, 11, 0.6, Math.PI * 2 - 0.6); c.arc(22, 12, 9, Math.PI * 2 - 1.2, 1.9, true); c.fill();
            c.fillRect(24, 4, 3, 3); c.fillRect(27, 9, 2, 2);
        } else if (kind === "restart") {
            c.beginPath(); c.arc(16, 17, 10, -Math.PI * 0.35, Math.PI * 1.6); c.stroke();
            c.beginPath(); c.moveTo(20, 3); c.lineTo(26, 8); c.lineTo(19, 11); c.closePath(); c.fill();
        } else {
            c.beginPath(); c.arc(16, 17, 10, -Math.PI * 0.3, Math.PI * 1.3); c.stroke();
            c.beginPath(); c.moveTo(16, 3); c.lineTo(16, 16); c.stroke();
        }
    }
}
