# Changelog

All notable changes to Bevel. Dates are when a build was pushed here.

## 0.3.0 · 2026-10-20 · keyboard layouts, updates, config buttons

- **Keyboard layouts.** No more fixed US layout. Setup takes yours from the system, and Settings → Keyboard & touchpad sets one or more layouts (`us,pl`), a variant, and the keys that switch between them.
- **One-command updates.** `bevelctl update` (or Super+I → About → Check for updates) pulls the newest Bevel and installs it with the new `./install.sh --update`: no wizard, no packages, your choices, settings and `user.lua` kept.
- **Your config files, one click away.** Settings → About opens `settings.json`, `user.lua`, the keybinds, the Hyprland folder, the shell and kitty's `user.conf` in VS Code or whichever editor you have (`bevelctl edit …` from a terminal). About also shows the Bevel version.
- **Display scale:** new installs use the scale Hyprland picks for your screen instead of one step smaller.
- The Setup progress bar now counts the retro icons step.

## 0.2.0 · 2026-10-20 · Arch-based distros

- **Your distro, not just Arch.** fastfetch, the System info and "btw" widgets, the bar badge, the Start menu and the login screen now show the distro you actually run: "I use CachyOS btw", "EndeavourOS" on the login screen, and so on.
- **Pixel logos for every distro.** On Arch it's still Bevel's hand-drawn pixel Arch. Elsewhere Bevel turns the logo your distro installs into 32×32 9x-style pixel art, for the widgets and fastfetch alike.
- **Settings → Fun → Your distro:** change the name, or pick the logo (Auto, Bevel's pixel Arch, classic fastfetch, none). `bevelctl distro --json` shows what was detected.
- **Setup on Arch-based distros:** it names your distro, and builds Quickshell or Hyprland pieces from the AUR (paru or yay) when your repos don't have them. It also installs `librsvg` for the logos.
- **No systemd needed (Artix):** service packages and services for OpenRC, runit, dinit and s6; the shut-down menu falls back to `loginctl`; polkit and PipeWire start without systemd user services.
- The bug report now says which distro and init system you run.
- Cleanup: dead code paths in Settings and an unused X11 screenshot path are gone.

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
