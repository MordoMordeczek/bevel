import QtQuick

Text {
    color: Theme.text
    font.family: Theme.font
    font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
    font.pixelSize: Theme.fontSize
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    maximumLineCount: 1
}
