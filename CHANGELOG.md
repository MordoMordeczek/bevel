# Changelog

All notable changes to Bevel. Dates are when a build was pushed here.

## 0.1.0 · 2026-10-19 · first upload

Bevel had been passed around as tarballs while it was being built. This is the first version on GitHub, still private.

**The desktop**
- A Quickshell 0.3 shell for Hyprland 0.55+ (Lua config): four bar layouts (Bevel with workspace minimaps, a Windows 95 Taskbar, Islands, Dock), a launcher in three looks, a control panel, drop-down menus from the bar, Alt+Tab, clipboard history, notifications and an on-screen display.
- Colours come from the wallpaper: the shell, kitty, Hyprland, GTK, Qt/Dolphin, Firefox, VS Code, Neovim, btop, Audacious, mpv, the SDDM login screen, hyprlock and the mouse pointer.
- 28 animated GPU backgrounds, plus effects (snow, fireflies, embers…) over a normal picture.
- Desktop widgets, from a clock to a working Minesweeper.
- Bevel Settings, its own app: a wallpaper browser built for big folders, shareable `.bevel` themes, displays, dock, bar layout, pointer, touchpad and keybinds.
- A Windows 95-style setup wizard, with backup and uninstall.

**Recent work before this upload**
- Several monitors: per-monitor bars and workspaces, a Display Properties page (resolution, refresh rate, scale, position, main display) with a 15-second "keep these settings?", and keys to move windows and workspaces between screens.
- Speed: `bevelctl` runs as compiled bytecode (~130 ms → ~40 ms per call), a wallpaper change shows in about a tenth of a second and the slow apps follow in the background, and the launcher, menus and Settings stay loaded, so they open instantly.
- The clock menu got a stopwatch and a timer, and the dock got sizes, styles, auto-hide and an app picker.
- Fixes: Dolphin stays on its workspace after a colour change, the pointer changes right away, and the fastfetch config works with fastfetch 2.66.
