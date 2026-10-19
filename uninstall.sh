#!/usr/bin/env bash
# Puts back the files the Bevel installer backed up. Packages are left installed.
set -euo pipefail
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="${1:-$(cat "$CONFIG/.bevel-last-backup" 2>/dev/null || true)}"

if [ -z "$BACKUP" ] || [ ! -d "$BACKUP" ]; then
    echo "No backup found. Pass one: ./uninstall.sh ~/.config/bevel-backup-YYYYMMDD-HHMMSS"
    exit 1
fi

read -r -p "Restore files from $BACKUP and remove Bevel's config? [y/N] " r
[[ "$r" =~ ^[Yy] ]] || exit 0

pkill -f "qs -c bevel" 2>/dev/null || true
pkill -f "bevelctl super-tap" 2>/dev/null || true
rm -f "$HOME/.local/share/applications/bevel-controlpanel.desktop" "$HOME/.local/share/applications/bevel-welcome.desktop" "$HOME/.local/share/applications/bevel-theme-import.desktop" "$HOME/.local/share/mime/packages/bevel-theme.xml"
[ -f "$HOME/.cache/bevel/caffeine.pid" ] && kill "$(cat "$HOME/.cache/bevel/caffeine.pid")" 2>/dev/null || true
rm -rf "$CONFIG/quickshell/bevel" "$CONFIG/bevel" "$CONFIG/kitty/bevel-colors.conf" \
       "$CONFIG/hypr/bevel_generated.lua" "$CONFIG/hypr/bevel_keybinds.lua" \
       "$CONFIG/gtk-3.0/bevel.css" "$CONFIG/gtk-4.0/bevel.css" \
       "$HOME/.local/share/color-schemes/Bevel.colors"
for v in gtk-3.0 gtk-4.0; do
    [ -f "$CONFIG/$v/gtk.css" ] && sed -i "/@import 'bevel.css';/d" "$CONFIG/$v/gtk.css"
done

# copy everything from the backup back into $HOME
(cd "$BACKUP" && find . -mindepth 1 -maxdepth 1 -print0) | while IFS= read -r -d '' item; do
    cp -a "$BACKUP/$item" "$HOME/"
done
for svc in fr.emersion.mako org.knopwob.dunst org.erikreider.swaync; do
    f="$HOME/.local/share/dbus-1/services/$svc.service"
    grep -q "disabled by bevel" "$f" 2>/dev/null && rm -f "$f"
done
rm -f "$HOME/.local/share/applications/bevel-settings.desktop"
# app themes Bevel made (your own app configs were never touched)
rm -rf "$HOME/.local/share/audacious/Skins/Bevel" "$HOME"/.vscode*/extensions/bevel.bevel-theme-*
rm -f "$CONFIG/nvim/colors/bevel.lua" "$CONFIG/btop/themes/bevel.theme" "$CONFIG/cmus/bevel.theme" "$CONFIG/zathura/bevel-colors"
for f in "$CONFIG/hypr/hypridle.conf" "$CONFIG/mpv/mpv.conf" "$CONFIG/mpv/script-opts/osc.conf" "$CONFIG/imv/config" "$CONFIG/cava/config" "$CONFIG/cmus/rc"; do
    grep -q "bevel-generated" "$f" 2>/dev/null && rm -f "$f"
done
[ -f "$CONFIG/zathura/zathurarc" ] && sed -i '/^include bevel-colors$/d' "$CONFIG/zathura/zathurarc"
rm -rf "$HOME/.themes/Bevel" "$HOME/.themes/Bevel-"* "$HOME/.local/share/bevel" "$HOME/.local/share/icons/Chicago95"
# the 9x mouse pointers
rm -rf "$HOME/.local/share/icons/Bevel-Cursors"
grep -q "bevelctl" "$HOME/.icons/default/index.theme" 2>/dev/null && rm -f "$HOME/.icons/default/index.theme"
gsettings reset org.gnome.desktop.interface cursor-theme 2>/dev/null || true
sudo rm -f /usr/local/bin/bevelctl
sudo rm -rf /usr/local/lib/bevel
if [ -d /usr/share/sddm/themes/bevel ]; then
    sudo rm -rf /usr/share/sddm/themes/bevel /etc/sddm.conf.d/bevel.conf /usr/share/icons/Bevel-Cursors
    echo "Removed the Bevel login screen (SDDM falls back to its default theme)."
fi
hyprctl reload >/dev/null 2>&1 || true
echo "Restored. Your wallpapers and ~/.config/hypr/user.lua were left alone."
