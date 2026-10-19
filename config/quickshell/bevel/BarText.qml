import QtQuick

// Text in the bar's font
BText {
    font.family: Theme.barFont
    font.features: { "liga": 0, "clig": 0, "dlig": 0, "calt": 0 }
    font.pixelSize: Theme.barFontSize
    font.bold: Theme.barBold
}
