.pragma library

// Every keyboard shortcut, grouped — for the cheat sheet (Super+F1) and the Welcome tour.
var hypr = [
    { group: "Bevel", keys: [
        ["Super + R", "Run / app launcher"], ["Super + A", "Control panel"], ["Super + I", "Bevel Settings"],
        ["Super + V", "Clipboard history"], ["Super + F1", "This cheat sheet"], ["Super + N", "Clear notifications"],
        ["Super + W", "Random wallpaper (or animation)"], ["Super + Shift + W", "Random favourite wallpaper"],
        ["Super + Shift + Z", "Screensaver"], ["Super + L", "Lock · log out · shut down"], ["Super + Esc", "Lock the screen"] ] },
    { group: "Apps", keys: [
        ["Super + Q", "Terminal (floating)"], ["Super + Shift + Q", "Terminal (tiled)"], ["Super + E", "Files (Dolphin)"] ] },
    { group: "Windows", keys: [
        ["Alt + Tab", "Switch windows (hold Alt)"], ["Super + C", "Close window"], ["Super + F", "Fullscreen"],
        ["Super + Shift + F", "Maximize"], ["Super + Shift + V", "Float / tile"], ["Super + J", "Flip the split"],
        ["Super + P", "Pseudo-tile"], ["Super + arrows", "Move focus"], ["Super + drag", "Move (left) · resize (right)"] ] },
    { group: "Workspaces", keys: [
        ["Super + 1…0", "Go to workspace"], ["Super + Shift + 1…0", "Send window there"],
        ["Super + S", "Show/hide scratchpad"], ["Super + Alt + S", "Send to scratchpad"] ] },
    { group: "Monitors", keys: [
        ["Super + Ctrl + ← / →", "Go to the other monitor"], ["Super + Ctrl + Shift + ← / →", "Take the window there"],
        ["Super + Alt + ← / →", "Move the whole workspace there"] ] },
    { group: "Screenshots", keys: [
        ["Print / Super + Shift + S", "A region"], ["Shift + Print", "The whole screen"], ["Super + Print", "The active window"] ] },
    { group: "Hardware keys", keys: [
        ["Volume keys", "Volume (with pop-up)"], ["Brightness keys", "Brightness (with pop-up)"], ["Media keys", "Play · pause · next · previous"] ] }
];

