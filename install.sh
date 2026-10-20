#!/usr/bin/env bash
# Bevel Setup — installer for the Bevel rice (Hyprland + Quickshell)
#
#   ./install.sh              the setup wizard: pick what you want, then it installs it all
#   ./install.sh --apps       only the "apps" page (add preconfigured apps later)
#   ./install.sh --no-pkgs    update the config without reinstalling the rice packages
#                             (apps you tick in the wizard are still installed)
#   ./install.sh --yes        no wizard, install the recommended set
#   ./install.sh --update     install a newer Bevel over this one: no wizard, no packages, your
#                             choices from last time are kept (`bevelctl update` runs this)
#   ./install.sh --no-upgrade don't update the system (pacman -Syu) before installing packages
#
# Everything it replaces is copied to ~/.config/bevel-backup-<date>/ first;
# ./uninstall.sh puts it back.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$CONFIG/bevel-backup-$STAMP"
PKGS=1
ASSUME_YES=0
APPS_ONLY=0
UPDATE=0
SYSUPGRADE=1

for a in "$@"; do
    case "$a" in
        --update) UPDATE=1 ;;
        --no-upgrade) SYSUPGRADE=0 ;;
        --no-pkgs) PKGS=0 ;;
        --yes|-y) ASSUME_YES=1 ;;
        --apps) APPS_ONLY=1 ;;
        -h|--help) awk 'NR > 1 && /^#/ { if ($0 ~ />>>|===|<<<|^#\|/) next; sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
        *) echo "unknown option: $a"; exit 1 ;;
    esac
done

[ "$(id -u)" -eq 0 ] && { echo "Run this as your normal user, not root."; exit 1; }
# ---- which distro: Arch, or one built on it (CachyOS, EndeavourOS, Manjaro, Garuda, Artix…)
DISTRO_ID=arch DISTRO_NAME="Arch Linux" DISTRO_LIKE=""
if [ -r /etc/os-release ]; then
    DISTRO_ID="$(. /etc/os-release 2>/dev/null; echo "${ID:-arch}")"
    DISTRO_NAME="$(. /etc/os-release 2>/dev/null; echo "${NAME:-Arch Linux}")"
    DISTRO_LIKE="$(. /etc/os-release 2>/dev/null; echo "${ID_LIKE:-}")"
fi
DISTRO_SHORT="${DISTRO_NAME% GNU/Linux}"; DISTRO_SHORT="${DISTRO_SHORT% Linux}"
if ! command -v pacman >/dev/null; then
    echo "Bevel Setup installs with pacman, so it runs on Arch Linux and the distros built on it"
    echo "(CachyOS, EndeavourOS, Manjaro, Garuda, Artix and friends). $DISTRO_NAME isn't one of them yet."
    exit 1
fi
# ---- the init system: systemd almost everywhere; Artix also comes with OpenRC, runit, dinit or s6
INIT=systemd
if [ ! -d /run/systemd/system ]; then
    if command -v rc-service >/dev/null; then INIT=openrc
    elif command -v dinitctl >/dev/null; then INIT=dinit
    elif command -v s6-rc >/dev/null; then INIT=s6
    elif [ -d /run/runit ] || command -v sv >/dev/null; then INIT=runit
    else INIT=unknown; fi
fi
# an AUR helper, for the few packages a distro's own repos might not have yet
AUR=""
for h in paru yay pikaur trizen; do command -v "$h" >/dev/null && { AUR="$h"; break; }; done

# ====================================================================== choices
# components (1 = yes)
declare -A ON=(
    [hypr]=1 [sddm]=1 [sddm_dm]=1 [icons]=1 [firefox]=1
    [w_ocean]=1 [w_ember]=0 [w_moss]=0
)
FRESH=1; [ -f "$CONFIG/bevel/settings.json" ] && FRESH=0
WELCOME_WHAT="system: Hyprland with the Quickshell bar, widgets and a dock,"
CUR_DM=""
[ -L /etc/systemd/system/display-manager.service ] && CUR_DM="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")"
# without systemd, Setup installs the login screen but shows how to switch to it rather than doing it
[ "$INIT" != systemd ] && ON[sddm_dm]=0
# keep the login manager you have unless it is already SDDM or there is none
[ -n "$CUR_DM" ] && [ "$CUR_DM" != "sddm.service" ] && ON[sddm_dm]=0

# apps: id | packages | name | what you get | on by default
APPS=(
    "#|Coding"
    "vscode|code|Visual Studio Code|Code - OSS with a Bevel colour theme, block cursor, no ligatures|1"
    "neovim|neovim|Neovim|Terminal editor with a matching 'bevel' colour scheme|0"
    "#|Music & video"
    "audacious|audacious audacious-plugins|Audacious|MP3 player, Winamp-style, with a skin in your colours|1"
    "cmus|cmus|cmus|Music player for the terminal, themed|0"
    "mpv|mpv|mpv|Video player with a boxy 9x control panel|1"
    "celluloid|celluloid|Celluloid|mpv with normal menus (uses the 9x window theme)|0"
    "cava|cava|cava|Audio visualizer bars in your colours|0"
    "#|Pictures & documents"
    "imv|imv|imv|Image viewer|1"
    "zathura|zathura zathura-pdf-mupdf|Zathura|PDF viewer, keyboard-driven, themed|1"
    "#|Tools"
    "btop|btop|btop|System monitor with square boxes and block graphs|1"
    "ark|ark|Ark|Open and make .zip / .7z / .tar archives from Dolphin|1"
    "qalculate|qalculate-gtk|Qalculate!|Calculator that also does units and currencies|0"
    "mousepad|mousepad|Mousepad|Simple notepad-style text editor|0"
    "#|Fun"
    "kolourpaint|kolourpaint|KolourPaint|The MS Paint you remember|0"
    "games|kpat kmines|Solitaire + Minesweeper|The two classics, in Bevel colours|0"
    "cmatrix|cmatrix|cmatrix|Matrix rain in the terminal. Some secrets look better with it|0"
)
app_installed() {   # app_installed "pkg pkg…": all of them installed?
    local p; for p in $1; do pacman -Q "$p" >/dev/null 2>&1 || return 1; done
}
declare -A HAVE=()
for a in "${APPS[@]}"; do
    IFS='|' read -r id pk _ _ dflt <<<"$a"
    [ "$id" = "#" ] && continue
    HAVE[$id]=0; app_installed "$pk" && HAVE[$id]=1
    ON[app_$id]="$dflt"
    [ "${HAVE[$id]}" = 1 ] && ON[app_$id]=1     # already there: keep it themed
done

# ---- --update: the new version over the old one, with what you picked last time
if [ "$UPDATE" = 1 ]; then
    [ "$FRESH" = 1 ] && { echo "Bevel isn't installed yet: run ./install.sh first."; exit 1; }
    PKGS=0; ASSUME_YES=1
    ON[sddm_dm]=0
    if [ -d /usr/share/sddm/themes/bevel ]; then ON[sddm]=1; else ON[sddm]=0; fi
    if [ "$(bevelctl get style.icons 2>/dev/null | tr -d '"')" = retro ]; then ON[icons]=1; else ON[icons]=0; fi
    if [ "$(bevelctl get firefox.theme 2>/dev/null)" = false ]; then ON[firefox]=0; else ON[firefox]=1; fi
    for k in "${!ON[@]}"; do case "$k" in app_*) ON[$k]=0 ;; esac; done
fi

# ====================================================================== text output
B=$'\e'
bold() { printf '%s[1m%s%s[0m\n' "$B" "$*" "$B"; }
info() { printf '   %s[36m•%s[0m %s\n' "$B" "$B" "$*"; }
warn() { printf '   %s[33m!%s[0m %s\n' "$B" "$B" "$*"; }

STEP=0; STEPS=1
step() {
    STEP=$((STEP + 1))
    local cols; cols=$(tput cols 2>/dev/null || echo 80); [ "$cols" -gt 72 ] && cols=72
    local barw=$((cols - 12)) fill=$(( (STEP - 1) * (cols - 12) / STEPS )) bar="" i
    for ((i = 0; i < barw; i++)); do if [ "$i" -lt "$fill" ]; then bar+="█"; else bar+="░"; fi; done
    printf '\n%s[1;97;44m %-*s%s[0m\n' "$B" "$((cols - 1))" "Bevel Setup  ·  step $STEP of $STEPS  ·  $*" "$B"
    printf '%s[34m %s %3d%%%s[0m\n' "$B" "$bar" "$(( (STEP - 1) * 100 / STEPS ))" "$B"
}

# ====================================================================== the wizard (9x setup look)
# the wizard draws with box characters: make sure string lengths count characters, not bytes
case "$(locale charmap 2>/dev/null)" in UTF-8) ;; *) export LC_ALL=C.UTF-8 ;; esac
TUI=0
if [ "$ASSUME_YES" = 0 ] && [ -t 0 ] && [ -t 1 ]; then
    L=$(tput lines 2>/dev/null || echo 0); C=$(tput cols 2>/dev/null || echo 0)
    [ "$L" -ge 24 ] && [ "$C" -ge 80 ] && TUI=1
fi

c_desk="$B[0;97;46m"; c_face="$B[0;30;47m"; c_hi="$B[0;97;47m"; c_sh="$B[0;90;47m"
c_title="$B[1;97;44m"; c_sel="$B[1;97;44m"; c_dim="$B[0;90;47m"; c_shadow="$B[0;40m"; c_r="$B[0m"
cup() { printf '%s[%d;%dH' "$B" "$1" "$2"; }
rep() { local s="" i; for ((i = 0; i < $2; i++)); do s+="$1"; done; printf '%s' "$s"; }
padto() { local w=$1 s="${2:0:$1}"; printf '%s%*s' "$s" $((w - ${#s})) ''; }   # pad by characters

tui_on() {
    STTY_SAVE="$(stty -g)"
    printf '%s[?1049h%s[?25l' "$B" "$B"
    stty -echo
    trap tui_off EXIT
    trap 'tui_off; echo; echo "Setup cancelled."; exit 1' INT
}
tui_off() {
    printf '%s[0m%s[2J%s[H%s[?25h%s[?1049l' "$B" "$B" "$B" "$B" "$B"
    [ -n "${STTY_SAVE:-}" ] && stty "$STTY_SAVE"
    STTY_SAVE=""
    trap - EXIT INT
}

W=72; H=21
desktop() {
    L=$(tput lines); C=$(tput cols)
    printf '%s%s[2J' "$c_desk" "$B"
    local r; for ((r = 1; r < L; r++)); do cup "$r" 1; printf '%*s' "$C" ''; done   # some terminals don't fill on clear
    cup 1 2; printf '%s[1;97;46mBevel Setup%s' "$B" "$c_desk"
    cup 2 2; printf '%s' "$(rep '▔' 11)"
    cup "$L" 1; printf '%s %-*s' "$c_face" "$((C - 1))" "${HINT:-}"
    T=$(( (L - H) / 2 )); [ "$T" -lt 3 ] && T=3; [ $((T + H)) -ge "$L" ] && T=$((L - H - 1))
    LEFT=$(( (C - W) / 2 + 1 ))
}
box() {   # box TITLE  (uses T LEFT H W)
    local r
    printf '%s' "$c_shadow"
    for ((r = T + 1; r <= T + H; r++)); do cup "$r" $((LEFT + W)); printf '  '; done
    cup $((T + H)) $((LEFT + 2)); printf '%*s' "$W" ''
    for ((r = T; r < T + H; r++)); do cup "$r" "$LEFT"; printf '%s%*s' "$c_face" "$W" ''; done
    cup "$T" "$LEFT"; printf '%s┌%s%s┐' "$c_hi" "$(rep ─ $((W - 2)))" "$c_sh"
    for ((r = T + 1; r < T + H - 1; r++)); do
        cup "$r" "$LEFT"; printf '%s│' "$c_hi"; cup "$r" $((LEFT + W - 1)); printf '%s│' "$c_sh"
    done
    cup $((T + H - 1)) "$LEFT"; printf '%s└%s┘' "$c_sh" "$(rep ─ $((W - 2)))"
    cup $((T + 1)) $((LEFT + 1)); printf '%s %-*s%s[0;30;47m▁▫✕%s' "$c_title" $((W - 6)) "$1" "$B" "$c_face"
}
put() { cup $((T + $1)) $((LEFT + $2)); printf '%s%s' "${3:-$c_face}" "$4"; }
buttons() {   # buttons "< Back" "Next >" "Cancel"   (the middle one is the default)
    local x=$((LEFT + W - 2)) i lab
    for ((i = $#; i >= 1; i--)); do
        lab="${!i}"; x=$((x - ${#lab} - 5))
        cup $((T + H - 3)) "$x"
        if [ "$i" -eq 2 ] || [ "$#" -eq 1 ]; then
            printf '%s▕%s %s %s▏' "$c_hi" "$B[1;30;47m" "$lab" "$c_sh"
        else
            printf '%s▕%s %s %s▏' "$c_hi" "$c_face" "$lab" "$c_sh"
        fi
    done
}
readkey() {
    local k rest
    IFS= read -rsn1 k
    if [ "$k" = "$B" ]; then
        IFS= read -rsn2 -t 0.05 rest || true
        case "$rest" in "[A") KEY=up ;; "[B") KEY=down ;; "[C") KEY=right ;; "[D") KEY=left ;; *) KEY=esc ;; esac
    elif [ -z "$k" ]; then KEY=enter
    elif [ "$k" = " " ]; then KEY=space
    elif [ "$k" = $'\x7f' ] || [ "$k" = "b" ] || [ "$k" = "B" ]; then KEY=back
    elif [ "$k" = "q" ] || [ "$k" = "Q" ]; then KEY=esc
    else KEY="$k"
    fi
}
confirm_cancel() {
    local saveH=$H saveW=$W saveT=$T saveL=$LEFT
    H=8; W=46; T=$((saveT + 6)); LEFT=$((saveL + 13))
    box "Exit Setup"
    put 3 3 "$c_face" "Bevel is not installed yet."
    put 4 3 "$c_face" "Do you want to exit Setup?"
    buttons "Exit (Y)" "Stay (N)"
    H=$saveH; W=$saveW; T=$saveT; LEFT=$saveL
    while true; do
        readkey
        case "$KEY" in y|Y) tui_off; echo "Setup cancelled — nothing was changed."; exit 0 ;; n|N|esc|enter) return ;; esac
    done
}

# ---- a page of text: returns 0 = next, 1 = back
page_text() {   # page_text TITLE NEXT_LABEL line...
    local title="$1" next="$2"; shift 2
    HINT="ENTER=Continue   B=Back   ESC=Exit Setup"
    while true; do
        desktop; box "$title"
        local r=3 ln
        for ln in "$@"; do put "$r" 3 "$c_face" "$ln"; r=$((r + 1)); done
        buttons "< Back" "$next" "Cancel"
        readkey
        case "$KEY" in enter) return 0 ;; back|left) return 1 ;; esc) confirm_cancel ;; esac
    done
}

# ---- a checklist: items are "kind|key|label|description"
#      kind: h = heading, c = checkbox, r:<group> = radio button, x = always on, i:<parent> = indented checkbox
page_list() {   # page_list TITLE INTRO item...
    local title="$1" intro="$2"; shift 2
    local items=("$@") n=$# cur=0 top=0 rows=$((H - 12)) i
    while [ "${items[$cur]%%|*}" = "h" ]; do cur=$((cur + 1)); done
    HINT="↑↓=Move   SPACE=Select   ENTER=Continue   B=Back   ESC=Exit Setup"
    desktop; box "$title"
    while true; do
        put 3 3 "$c_face" "$intro"
        [ "$cur" -lt "$top" ] && top=$cur
        [ "$cur" -ge $((top + rows)) ] && top=$((cur - rows + 1))
        # sunken list frame
        put 4 2 "$c_sh" "┌$(rep ─ $((W - 6)))"; printf '%s┐' "$c_hi"
        for ((i = 0; i < rows; i++)); do
            local idx=$((top + i)) line="" col="$B[0;30;107m"
            put $((5 + i)) 2 "$c_sh" "│"
            if [ "$idx" -lt "$n" ]; then
                IFS='|' read -r kind key label _ <<<"${items[$idx]}"
                case "$kind" in
                    h) line=" ── $label "; col="$B[1;34;107m" ;;
                    x) line="   [■] $label" ;;
                    c) if [ "${ON[$key]}" = 1 ]; then line="   [x] $label"; else line="   [ ] $label"; fi ;;
                    i:*) if [ "${ON[$key]}" = 1 ]; then line="       [x] $label"; else line="       [ ] $label"; fi
                         [ "${ON[${kind#i:}]}" = 1 ] || col="$B[0;37;107m" ;;
                    r:*) if [ "${ON[$key]}" = 1 ]; then line="   (•) $label"; else line="   ( ) $label"; fi ;;
                esac
                [ "$idx" -eq "$cur" ] && col="$c_sel"
            fi
            printf '%s' "$col"; padto $((W - 6)) "$line"
            printf '%s│' "$c_hi"
        done
        put $((5 + rows)) 2 "$c_sh" "└"; printf '%s%s┘' "$c_hi" "$(rep ─ $((W - 6)))"
        # description of the highlighted line + scroll hint
        IFS='|' read -r _ _ _ desc <<<"${items[$cur]}"
        put $((6 + rows)) 3 "$c_face" "$(printf '%-*s' $((W - 6)) "")"
        put $((7 + rows)) 3 "$c_face" "$(printf '%-*s' $((W - 6)) "")"
        local dl=(); mapfile -t dl < <(fold -s -w $((W - 6)) <<<"$desc")
        put $((6 + rows)) 3 "$c_dim" "${dl[0]:-}"; put $((7 + rows)) 3 "$c_dim" "${dl[1]:-}"
        if [ "$n" -gt "$rows" ]; then put 4 $((W - 14)) "$c_dim" " $((top + 1))-$((top + rows < n ? top + rows : n)) of $n "; fi
        buttons "< Back" "Next >" "Cancel"
        readkey
        case "$KEY" in
            up)   i=$cur; while [ "$i" -gt 0 ]; do i=$((i - 1)); [ "${items[$i]%%|*}" != "h" ] && { cur=$i; break; }; done ;;
            down) i=$cur; while [ "$i" -lt $((n - 1)) ]; do i=$((i + 1)); [ "${items[$i]%%|*}" != "h" ] && { cur=$i; break; }; done ;;
            space)
                IFS='|' read -r kind key _ _ <<<"${items[$cur]}"
                case "$kind" in
                    c|i:*) if [ "${ON[$key]}" = 1 ]; then ON[$key]=0; else ON[$key]=1; fi ;;
                    r:*) for i in "${items[@]}"; do
                             IFS='|' read -r k2 key2 _ _ <<<"$i"; [ "$k2" = "$kind" ] && ON[$key2]=0
                         done; ON[$key]=1 ;;
                esac ;;
            enter) return 0 ;;
            back|left) return 1 ;;
            esc) confirm_cancel; desktop; box "$title" ;;
        esac
    done
}

app_items() {
    local a id pk name desc
    for a in "${APPS[@]}"; do
        IFS='|' read -r id pk name desc _ <<<"$a"
        if [ "$id" = "#" ]; then echo "h||$pk|"
        elif [ "${HAVE[$id]}" = 1 ]; then echo "c|app_$id|$name  (installed)|$desc"
        else echo "c|app_$id|$name|$desc"; fi
    done
}

wizard() {
    local page=0 dm_label
    if [ "$INIT" = unknown ]; then dm_label="Show me how to make it my login manager"
    elif [ "$INIT" != systemd ]; then dm_label="Show me how to make it my login manager ($INIT)"
    elif [ -z "$CUR_DM" ]; then dm_label="Use it as my login manager (none is set up yet)"
    elif [ "$CUR_DM" = "sddm.service" ]; then dm_label="Use it as my login manager (SDDM already is)"
    else dm_label="Use it as my login manager (now: ${CUR_DM%.service})"; fi
    mapfile -t app_list < <(app_items)
    [ "$APPS_ONLY" = 1 ] && page=3
    while true; do
        case $page in
        0)  page_text "Welcome" "Next >" \
                "" \
                "   ██▄  ██▀  █ █  ██▀  █" \
                "   █▄█  █▄▄  ▀▄▀  █▄▄  █▄▄      9x-flavoured rice for $DISTRO_SHORT" \
                "" \
                "Welcome to Bevel Setup. This wizard puts the Bevel look on your" \
                "$WELCOME_WHAT" \
                "a matching login screen and apps, all coloured from your wallpaper." \
                "" \
                "Your current config files are backed up first, and ./uninstall.sh" \
                "puts them back." \
                "" \
                "Press ENTER to continue, or ESC to exit Setup."
            [ $? -eq 0 ] && page=6 ;;
        6)  local hv hnote
            hv="$(Hyprland --version 2>/dev/null | grep -oE 'v?[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | tr -d v)"
            if [ -z "$hv" ]; then hnote="Hyprland isn't installed yet — Setup can install it."
            elif [ "$(printf '%s\n0.55\n' "$hv" | sort -V | head -1)" != "0.55" ]; then hnote="Your Hyprland is $hv — Bevel needs 0.55 or newer (Lua config)."
            else hnote="Your Hyprland is $hv — good."; fi
            local notes=("  • $hnote")
            [ "$DISTRO_ID" != arch ] && notes+=("  • You're on $DISTRO_SHORT, which is built on Arch: it should work.")
            if [ "$INIT" = unknown ]; then notes+=("  • No systemd found: you may have to switch services on yourself.")
            elif [ "$INIT" != systemd ]; then notes+=("  • No systemd here: services are set up for $INIT instead."); fi
            local tail=("" "Press ENTER if that's OK with you.")
            [ "${#notes[@]}" -gt 2 ] && tail=("Press ENTER if that's OK with you.")
            page_text "Before You Install" "I understand >" \
                "" \
                "Bevel is a hobby project, written almost entirely by Claude (an AI)" \
                "and tested on two computers. On yours some things might break or" \
                "look wrong — especially with other graphics cards, several monitors" \
                "or an older Hyprland. You install it at your own risk: no warranty." \
                "" \
                "${notes[@]}" \
                "  • Your config is backed up first; ./uninstall.sh puts it back." \
                "  • It replaces your Hyprland config (hyprland.lua; your own" \
                "    tweaks go in user.lua) and kitty's colours." \
                "  • Something broken? Super+I → About → Make a bug report." \
                "${tail[@]}"
            if [ $? -eq 0 ]; then page=1; else page=0; fi ;;
        1)  local comp=(
                "x|hypr|Bevel for Hyprland (always)|The bar, control panel, widgets, animations, Alt+Tab, clipboard, settings and themes. Needs Hyprland 0.55+."
                "h||Extras|"
                "c|sddm|Login screen (SDDM theme)|A 9x 'Log On' dialog that follows your wallpaper colours."
                "i:sddm|sddm_dm|$dm_label|Switches the login manager from the next boot."
                "c|icons|Retro icons (Chicago95, ~31 MB download)|Windows 95 icons for apps, the Run menu, dock and taskbar."
                "c|firefox|Firefox in Bevel colours|Compact 9x toolbar and a themed new tab page."
            )
            if [ "$FRESH" = 1 ]; then
                comp+=("h||Starting wallpaper|"
                       "r:wall|w_ocean|Ocean (blue)|Pixel-art sunset, cool blues. Change it any time with Super+I."
                       "r:wall|w_ember|Ember (orange)|Pixel-art sunset, warm oranges."
                       "r:wall|w_moss|Moss (green)|Pixel-art sunset, greens.")
            fi
            page_list "Select Components" "Choose what to install:" "${comp[@]}"
            if [ $? -ne 0 ]; then page=6
            else page=3; fi ;;
        3)  page_list "Select Apps" "Apps that come preconfigured in your colours:" "${app_list[@]}"
            if [ $? -eq 0 ]; then page=4
            elif [ "$APPS_ONLY" = 1 ]; then page=3
            else page=1; fi ;;
        4)  local lines=("Setup has enough information to start installing." "") picked="" a id name
            if [ "$APPS_ONLY" = 0 ]; then
                [ "${ON[hypr]}" = 1 ] && lines+=("  • Bevel for Hyprland")
                [ "${ON[sddm]}" = 1 ] && lines+=("  • Login screen$([ "${ON[sddm_dm]}" = 1 ] && echo ' (as your login manager)')")
                [ "${ON[icons]}" = 1 ] && lines+=("  • Retro icons (Chicago95)")
                [ "${ON[firefox]}" = 1 ] && lines+=("  • Firefox theme")
            fi
            for a in "${APPS[@]}"; do
                IFS='|' read -r id _ name _ _ <<<"$a"
                [ "$id" != "#" ] && [ "${ON[app_$id]}" = 1 ] && picked+="${picked:+, }$name"
            done
            if [ -n "$picked" ]; then
                local wrapped; mapfile -t wrapped < <(fold -s -w $((W - 14)) <<<"$picked")
                lines+=("  • Apps: ${wrapped[0]}")
                for a in "${wrapped[@]:1}"; do lines+=("          $a"); done
            fi
            [ "$PKGS" = 1 ] && [ "$SYSUPGRADE" = 1 ] && lines+=("  • A system update first (pacman -Syu), so everything fits")
            lines+=("" "pacman will ask for your password once. Press ENTER to install.")
            page_text "Ready to Install" "Install" "${lines[@]}"
            if [ $? -eq 0 ]; then return 0; else page=3; fi ;;
        esac
    done
}

finish_screen() {
    tui_on
    HINT="ENTER=Finish"
    desktop; box "Bevel Setup"
    local r=3 ln
    for ln in "$@"; do put "$r" 3 "$c_face" "$ln"; r=$((r + 1)); done
    buttons "Finish"
    while true; do readkey; [ "$KEY" = enter ] && break; [ "$KEY" = esc ] && break; done
    tui_off
}

if [ "$TUI" = 1 ]; then
    tui_on
    wizard
    tui_off
elif [ "$ASSUME_YES" = 0 ]; then
    echo
    bold "Bevel Setup"
    echo "  Your terminal is too small for the setup wizard (needs 80×24), so the"
    echo "  recommended set will be installed: everything, plus the apps marked as default."
    read -r -p "  Continue? [Y/n] " r
    [[ -z "$r" || "$r" =~ ^[Yy] ]] || exit 0
fi

# ====================================================================== install
WALLNAME=bevel-ocean; [ "${ON[w_ember]}" = 1 ] && WALLNAME=bevel-ember; [ "${ON[w_moss]}" = 1 ] && WALLNAME=bevel-moss
APP_IDS=(); APP_PKGS=(); NOT_INSTALLED=()
for a in "${APPS[@]}"; do
    IFS='|' read -r id pk _ _ _ <<<"$a"
    [ "$id" = "#" ] && continue
    if [ "${ON[app_$id]}" = 1 ]; then APP_IDS+=("$id"); read -ra p <<<"$pk"; APP_PKGS+=("${p[@]}"); fi
done
if [ "$APPS_ONLY" = 1 ]; then
    STEPS=3
else
    STEPS=6
    [ "${ON[sddm]}" = 1 ] && STEPS=$((STEPS + 1))
    [ "${ON[icons]}" = 1 ] && STEPS=$((STEPS + 1))
    [ "${#APP_IDS[@]}" -gt 0 ] && STEPS=$((STEPS + 1))
fi
echo
if [ "$UPDATE" = 1 ]; then bold "  Updating Bevel to $(cat "$HERE/VERSION" 2>/dev/null || echo "the newest version")…"
else bold "  Bevel Setup is installing. Sit back."; fi

PACLOG="$(mktemp -t bevel-pacman.XXXXXX)"
pacman_try() {   # sudo pacman ARGS --noconfirm, output also kept in $PACLOG to spot signature trouble
    sudo pacman "$@" --noconfirm 2>&1 | tee -a "$PACLOG"
    return "${PIPESTATUS[0]}"
}
explain_pacman() {   # turn pacman's scariest errors into words, once
    [ -n "${EXPLAINED:-}" ] && return 0
    if grep -qiE "invalid or corrupted package|signature .*(unknown trust|is invalid)|could not be looked up|key .* is disabled|corrupted \(PGP signature\)" "$PACLOG"; then
        EXPLAINED=1
        warn "pacman says the packages are \"corrupted\". They almost never are: their security signatures"
        warn "didn't check out. The usual causes are a wrong clock or old package keys. To fix it:"
        warn "    sudo timedatectl set-ntp true"
        warn "    sudo pacman -Sy archlinux-keyring && sudo pacman -Syu   (plus your distro's own …-keyring)"
        warn "then run ./install.sh again."
    elif grep -qiE "failed retrieving file|404|could not resolve host|failed to synchronize" "$PACLOG"; then
        EXPLAINED=1
        warn "pacman couldn't download some packages: check your internet connection, or update your"
        warn "mirror list (Arch: sudo pacman -S reflector, then reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist)."
    fi
}
SYS_READY=0
prepare_pacman() {   # before installing anything: correct clock, fresh package keys, an up-to-date system
    [ "$SYS_READY" = 1 ] && return 0
    SYS_READY=1
    # package signatures are checked against the clock, so a wrong one makes every package look corrupted
    if [ "$INIT" = systemd ] && [ "$(timedatectl show -p NTPSynchronized --value 2>/dev/null)" != yes ]; then
        sudo timedatectl set-ntp true >/dev/null 2>&1 && info "switched on network time (package signatures need a correct clock)"
    fi
    if [ "$SYSUPGRADE" = 0 ]; then
        info "not updating the system first (--no-upgrade)"
        return 0
    fi
    # the keyrings first (archlinux-keyring, cachyos-keyring, artix-keyring…): old ones reject new packages
    local keys=()
    mapfile -t keys < <(pacman -Qq 2>/dev/null | grep -E -- '-keyring$')
    info "updating your system first (pacman -Syu), so the new packages fit what you have"
    if [ "${#keys[@]}" -gt 0 ]; then
        pacman_try -Sy --needed "${keys[@]}" >/dev/null || { explain_pacman; warn "couldn't update the package keys"; }
    fi
    pacman_try -Syu || {
        warn "the update needs a decision from you — running it again with questions"
        sudo pacman -Syu || { explain_pacman; warn "the system update didn't finish; Setup carries on, but packages may fail"; }
    }
}

pacman_install() {   # install what is missing; never stops the whole setup
    local want=() missing=() p
    for p in "$@"; do
        pacman -Q "$p" >/dev/null 2>&1 && continue
        if pacman -Si "$p" >/dev/null 2>&1 || pacman -Sg "$p" >/dev/null 2>&1; then want+=("$p"); else missing+=("$p"); fi
    done
    local core=() rest=()
    for p in "${missing[@]}"; do
        case " $CORE_PKGS " in *" $p "*) core+=("$p") ;; *) rest+=("$p") ;; esac
    done
    [ "${#rest[@]}" -gt 0 ] && warn "not in your repos, skipped: ${rest[*]}"
    if [ "${#want[@]}" -gt 0 ]; then
        info "installing: ${want[*]}"
        pacman_try -S --needed "${want[@]}" || {
            warn "pacman needs a decision from you — running it again with questions"
            sudo pacman -S --needed "${want[@]}" || { explain_pacman; warn "some packages were not installed"; }
        }
    elif [ "${#core[@]}" -eq 0 ]; then
        info "everything is already installed"
    fi
    # Bevel can't run without these; some Arch-based distros don't carry them (yet), the AUR does
    if [ "${#core[@]}" -gt 0 ]; then
        if [ -n "$AUR" ]; then
            info "not in your repos: ${core[*]} — building them from the AUR with $AUR (this can take a while)"
            "$AUR" -S --needed --noconfirm "${core[@]}" || warn "$AUR couldn't install: ${core[*]}"
        else
            warn "not in your repos: ${core[*]} — Bevel needs them. Install them from the AUR (with paru or yay), then run Setup again."
        fi
    fi
}
# what Bevel can't do without (fetched from the AUR when the repos don't have them)
CORE_PKGS="quickshell hyprland hyprlock hypridle hyprpolkitagent xdg-desktop-portal-hyprland hyprsunset awww swww cliphist"

# ---- services, on whatever init you have
svc_enable() {   # svc_enable NAME [OTHER_NAME…]: enable and start the first one this system has
    local n
    for n in "$@"; do
        case "$INIT" in
            systemd) sudo systemctl enable --now "$n" >/dev/null 2>&1 && return 0 ;;
            openrc)  [ -e "/etc/init.d/$n" ] || continue
                     sudo rc-update add "$n" default >/dev/null 2>&1; sudo rc-service "$n" start >/dev/null 2>&1; return 0 ;;
            runit)   [ -d "/etc/runit/sv/$n" ] || continue
                     [ -e "/run/runit/service/$n" ] || sudo ln -s "/etc/runit/sv/$n" /run/runit/service/ >/dev/null 2>&1; return 0 ;;
            dinit)   [ -e "/etc/dinit.d/$n" ] || continue
                     sudo dinitctl enable "$n" >/dev/null 2>&1; return 0 ;;
            s6)      sudo s6-service add default "$n" >/dev/null 2>&1 || continue
                     sudo s6-db-reload >/dev/null 2>&1; return 0 ;;
        esac
    done
    return 1
}
svc_enabled() {   # svc_enabled NAME [OTHER_NAME…]
    local n
    for n in "$@"; do
        case "$INIT" in
            systemd) systemctl is-enabled "$n" >/dev/null 2>&1 && return 0 ;;
            openrc)  rc-update show default 2>/dev/null | grep -qw "$n" && return 0 ;;
            runit)   [ -e "/run/runit/service/$n" ] && return 0 ;;
            dinit)   [ -e "/etc/dinit.d/boot.d/$n" ] && return 0 ;;
        esac
    done
    return 1
}
init_pkgs() {   # Artix ships service files as <package>-<init>; print the ones that exist
    [ "$INIT" = systemd ] || [ "$INIT" = unknown ] && return 0
    local p
    for p in "$@"; do pacman -Si "$p-$INIT" >/dev/null 2>&1 && echo "$p-$INIT"; done
}

backup() {
    local src="$1"
    if [ -e "$src" ]; then
        local rel="${src#"$HOME"/}"
        mkdir -p "$BACKUP/$(dirname "$rel")"
        cp -a "$src" "$BACKUP/$rel"
        info "saved ~/$rel"
    fi
}

if [ "$APPS_ONLY" = 1 ]; then
    step "Installing apps"
    prepare_pacman
    pacman_install "${APP_PKGS[@]}"
else
# ---------------------------------------------------------------- packages
step "Packages"
if [ "$PKGS" = 1 ]; then
    prepare_pacman
    pkgs=(
        quickshell kitty dolphin
        python python-pillow python-fonttools
        qt6ct qt6-svg qt6-imageformats breeze-icons kio-extras
        pipewire wireplumber pipewire-pulse brightnessctl playerctl
        networkmanager upower libnotify bluez bluez-utils cava xdg-desktop-portal-gtk
        noto-fonts ttf-jetbrains-mono fontconfig curl fastfetch git btop qt6-shadertools librsvg
    )
    if [ "${ON[hypr]}" = 1 ]; then
        pkgs+=(hyprland hyprlock hypridle hyprpolkitagent xdg-desktop-portal-hyprland hyprsunset
               grim slurp wl-clipboard cliphist)
        if pacman -Si awww >/dev/null 2>&1; then pkgs+=(awww); else pkgs+=(swww); fi
    fi
    [ "${ON[sddm]}" = 1 ] && pkgs+=(sddm)
    # power modes for the control panel (skipped if you use TLP, which does the same job)
    NEW_PPD=0
    if ! pacman -Q tlp >/dev/null 2>&1 && ! pacman -Q power-profiles-daemon >/dev/null 2>&1; then pkgs+=(power-profiles-daemon); NEW_PPD=1; fi
    pkgs+=("${APP_PKGS[@]}")
    mapfile -t extra < <(init_pkgs "${pkgs[@]}")
    pkgs+=("${extra[@]}")
    pacman_install "${pkgs[@]}"
    [ "$NEW_PPD" = 1 ] && pacman -Q power-profiles-daemon >/dev/null 2>&1 && svc_enable power-profiles-daemon
    pacman -Q bluez >/dev/null 2>&1 && ! svc_enabled bluetooth bluetoothd && svc_enable bluetooth bluetoothd
else
    info "rice packages skipped (--no-pkgs)"
    # apps you ticked in the wizard are still installed: ticking one means "I want it"
    [ "${#APP_PKGS[@]}" -gt 0 ] && { prepare_pacman; pacman_install "${APP_PKGS[@]}"; }
fi

# ---------------------------------------------------------------- backup
step "Backing up your config"
mkdir -p "$BACKUP"
for f in \
    "$CONFIG/hypr/hyprland.lua" "$CONFIG/hypr/hyprland.conf" "$CONFIG/hypr/hyprlock.conf" \
    "$CONFIG/hypr/bevel_keybinds.lua" "$CONFIG/hypr/bevel_generated.lua" \
    "$CONFIG/kitty/kitty.conf" "$CONFIG/quickshell/bevel" "$CONFIG/qt6ct" "$CONFIG/kdeglobals" \
    "$CONFIG/gtk-3.0/gtk.css" "$CONFIG/gtk-4.0/gtk.css" "$CONFIG/bevel/settings.json" \
    "$CONFIG/fastfetch"; do
    backup "$f"
done
echo "$BACKUP" > "$CONFIG/.bevel-last-backup"
info "backup → $BACKUP"

# ---------------------------------------------------------------- files
step "Installing config"
mkdir -p "$CONFIG/hypr" "$CONFIG/kitty" "$CONFIG/quickshell" "$CONFIG/bevel/generated"
rm -rf "$CONFIG/quickshell/bevel"
cp -r "$HERE/config/quickshell/bevel" "$CONFIG/quickshell/bevel"
info "~/.config/quickshell/bevel"
# rebuild the animated backgrounds with this system's own shader compiler (matches its Qt exactly)
QSB=""; for q in /usr/lib/qt6/bin/qsb /usr/bin/qsb6 /usr/bin/qsb; do [ -x "$q" ] && { QSB="$q"; break; }; done
if [ -n "$QSB" ]; then
    ok=0; bad=0
    for f in "$CONFIG/quickshell/bevel/live/src/"*.frag; do
        n="$(basename "$f" .frag)"
        if "$QSB" --glsl "100 es,120,150" --hlsl 50 --msl 12 \
                -o "$CONFIG/quickshell/bevel/live/$n.frag.qsb.new" "$f" >/dev/null 2>&1; then
            mv "$CONFIG/quickshell/bevel/live/$n.frag.qsb.new" "$CONFIG/quickshell/bevel/live/$n.frag.qsb"; ok=$((ok + 1))
        else
            rm -f "$CONFIG/quickshell/bevel/live/$n.frag.qsb.new"; bad=$((bad + 1))
        fi
    done
    info "animated backgrounds built for your Qt ($ok ok$([ "$bad" -gt 0 ] && echo ", $bad kept prebuilt"))"
else
    info "animated backgrounds: using the prebuilt shaders (install qt6-shadertools to build them for your Qt)"
fi
if [ "${ON[hypr]}" = 1 ]; then
    cp "$HERE/config/hypr/hyprland.lua" "$CONFIG/hypr/hyprland.lua"
    cp "$HERE/config/hypr/bevel_keybinds.lua" "$CONFIG/hypr/bevel_keybinds.lua"
    [ -f "$CONFIG/hypr/user.lua" ] || printf -- '-- Your own Hyprland tweaks. Bevel never overwrites this file.\n' > "$CONFIG/hypr/user.lua"
    info "~/.config/hypr (hyprland.lua, bevel_keybinds.lua, user.lua)"
fi
cp "$HERE/config/kitty/kitty.conf" "$CONFIG/kitty/kitty.conf"
[ -f "$CONFIG/kitty/user.conf" ] || printf '# your own kitty tweaks\n' > "$CONFIG/kitty/user.conf"
info "~/.config/kitty"
# bevelctl: a small launcher in /usr/local/bin, the program next to your Bevel files (compiled once, then fast)
mkdir -p "$HOME/.local/share/bevel/lib"
install -m644 "$HERE/bin/bevelctl" "$HOME/.local/share/bevel/lib/bevelctl_main.py"
python3 -m compileall -q "$HOME/.local/share/bevel/lib" >/dev/null 2>&1 || true
sudo install -Dm644 "$HERE/bin/bevelctl" /usr/local/lib/bevel/bevelctl_main.py
sudo python3 -m compileall -q /usr/local/lib/bevel >/dev/null 2>&1 || true
sudo install -Dm755 "$HERE/bin/bevelctl-launcher" /usr/local/bin/bevelctl && info "/usr/local/bin/bevelctl"
mkdir -p "$HOME/.local/share/bevel"
# which version this is, and where it came from (so `bevelctl update` can fetch the next one)
install -m644 "$HERE/VERSION" "$HOME/.local/share/bevel/VERSION" 2>/dev/null || true
mkdir -p "$CONFIG/bevel"
printf '%s\n' "$HERE" > "$CONFIG/bevel/install-source"
rm -rf "$HOME/.local/share/bevel/chicago95"
cp -r "$HERE/gtk/chicago95" "$HOME/.local/share/bevel/chicago95"
info "9x GTK/window theme source (Chicago95, recoloured into ~/.themes/Bevel)"
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/bevel-settings.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=Bevel Settings
Comment=Wallpaper, colors and style of the Bevel rice
Exec=bevelctl settings
Icon=preferences-desktop-theme
Categories=Settings;DesktopSettings;
DESK
mkdir -p "$HOME/.local/share/bevel/themes/builtin"
cp "$HERE"/themes/*.bevel "$HOME/.local/share/bevel/themes/builtin/" 2>/dev/null && info "built-in themes (Settings → Themes)"
cat > "$HOME/.local/share/applications/bevel-controlpanel.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=Control Panel
Comment=Wi-Fi, Bluetooth, sound, brightness, battery and more
Exec=bevelctl controlpanel
Icon=preferences-system
Categories=Settings;
DESK
cat > "$HOME/.local/share/applications/bevel-welcome.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=Welcome to Bevel
Comment=A quick tour and every keyboard shortcut
Exec=bevelctl welcome
Icon=help-about
Categories=Settings;
DESK
cat > "$HOME/.local/share/applications/bevel-theme-import.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=Import Bevel theme
Exec=bevelctl theme import %f
Icon=preferences-desktop-theme
MimeType=application/x-bevel-theme;
NoDisplay=true
DESK
mkdir -p "$HOME/.local/share/mime/packages"
cat > "$HOME/.local/share/mime/packages/bevel-theme.xml" <<'MIME'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-bevel-theme">
    <comment>Bevel theme</comment>
    <glob pattern="*.bevel"/>
  </mime-type>
</mime-info>
MIME
update-mime-database "$HOME/.local/share/mime" >/dev/null 2>&1 || true
xdg-mime default bevel-theme-import.desktop application/x-bevel-theme >/dev/null 2>&1 || true
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
info "menu entries: Bevel Settings, Control Panel, Welcome to Bevel (and .bevel theme files open in Bevel)"
WALLDIR="$HOME/Pictures/Wallpapers"
mkdir -p "$WALLDIR" "$HOME/Pictures/Screenshots"
for w in "$HERE"/wallpapers/*; do
    [ -e "$WALLDIR/$(basename "$w")" ] || cp "$w" "$WALLDIR/"
done
info "wallpapers → ~/Pictures/Wallpapers"

# ---------------------------------------------------------------- fonts
step "Fonts (Pixelify Sans, VT323)"
FONTDIR="$HOME/.local/share/fonts/bevel"
mkdir -p "$FONTDIR"
fetch_font() {
    local out="$1"; shift
    if [ -s "$FONTDIR/$out" ]; then info "$out already there"; return; fi
    for url in "$@"; do
        if curl -fsSL --retry 2 -o "$FONTDIR/$out" "$url"; then info "$out"; return; fi
    done
    rm -f "$FONTDIR/$out"
    warn "could not download $out — the shell will fall back to another font"
}
fetch_font "PixelifySans.ttf" \
    "https://github.com/google/fonts/raw/main/ofl/pixelifysans/PixelifySans%5Bwght%5D.ttf" \
    "https://cdn.jsdelivr.net/fontsource/fonts/pixelify-sans@latest/latin-400-normal.ttf"
fetch_font "VT323-Regular.ttf" \
    "https://github.com/google/fonts/raw/main/ofl/vt323/VT323-Regular.ttf" \
    "https://cdn.jsdelivr.net/fontsource/fonts/vt323@latest/latin-400-normal.ttf"
fc-cache -f "$FONTDIR" >/dev/null 2>&1 || true
# Pixelify Sans draws its "fi"/"fl" ligatures wrong ("Firefox" → "ﬁrefox"); strip them from the font files
if python3 -c "import fontTools" 2>/dev/null; then
    bevelctl fix-fonts >/dev/null 2>&1 && info "fixed the fi/fl ligatures" || true
else
    warn "python-fonttools is missing — install it and run: bevelctl fix-fonts"
fi

# ---------------------------------------------------------------- theme
step "Generating the theme"
if [ "$FRESH" = 1 ]; then
    bevelctl set wallpaper.path "$WALLDIR/$WALLNAME.png" >/dev/null
    # Hyprland picks a display scale that fits your screen (Super+I → Windows & display changes it)
    bevelctl set display.scale auto >/dev/null
    # your keyboard layout, as the system has it (Super+I → Keyboard & touchpad changes it)
    KB="$(bevelctl keyboard detect 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("layout",""))' 2>/dev/null)"
    [ -n "$KB" ] && info "keyboard layout → $KB (from your system)"
fi
if [ "$(bevelctl get version 2>/dev/null || echo null)" = "null" ]; then
    bevelctl set style.fontSize 14 bar.height 30 version 2 >/dev/null
fi
bevelctl set firefox.theme "$([ "${ON[firefox]}" = 1 ] && echo true || echo false)" >/dev/null
bevelctl apply >/dev/null && info "colours generated from $(basename "$(bevelctl get wallpaper.path | tr -d '"')")"
# keep other notification daemons from being started by D-Bus (they'd steal Bevel's popups)
DBUSDIR="$HOME/.local/share/dbus-1/services"
mkdir -p "$DBUSDIR"
for svc in fr.emersion.mako org.knopwob.dunst org.erikreider.swaync; do
    printf '[D-BUS Service]\nName=org.freedesktop.Notifications\nExec=/bin/false\n# disabled by bevel\n' > "$DBUSDIR/$svc.service"
done
info "other notification daemons won't auto-start any more"

# ---------------------------------------------------------------- login screen
if [ "${ON[sddm]}" = 1 ]; then
    step "Login screen"
    SDDM_THEME=/usr/share/sddm/themes/bevel
    if pacman -Q sddm >/dev/null 2>&1; then
        sudo rm -rf "$SDDM_THEME"
        sudo cp -r "$HERE/sddm/bevel" "$SDDM_THEME"
        [ -s "$FONTDIR/PixelifySans.ttf" ] && sudo install -Dm644 "$FONTDIR/PixelifySans.ttf" "$SDDM_THEME/fonts/PixelifySans.ttf"
        # these two files are yours, so bevelctl can recolor the login screen without sudo
        sudo touch "$SDDM_THEME/theme.conf.user"
        sudo chown "$USER" "$SDDM_THEME/theme.conf.user" "$SDDM_THEME/background.png"
        sudo mkdir -p /etc/sddm.conf.d
        bevelctl apply >/dev/null
        # the 9x mouse pointer on the login screen too (a copy: the login screen can't read your home)
        if [ -f "$HOME/.local/share/icons/Bevel-Cursors/index.theme" ]; then
            sudo rm -rf /usr/share/icons/Bevel-Cursors
            sudo cp -r "$HOME/.local/share/icons/Bevel-Cursors" /usr/share/icons/Bevel-Cursors
            printf '[Theme]\nCurrent=bevel\nCursorTheme=Bevel-Cursors\n' | sudo tee /etc/sddm.conf.d/bevel.conf >/dev/null
        else
            printf '[Theme]\nCurrent=bevel\n' | sudo tee /etc/sddm.conf.d/bevel.conf >/dev/null
        fi
        info "theme installed (follows your wallpaper colours)"
        if [ "$INIT" != systemd ]; then
            if [ "${ON[sddm_dm]}" = 1 ] && ! svc_enabled sddm display-manager; then
                info "to make SDDM your login manager on $INIT (switch off the old one first):"
                case "$INIT" in
                    openrc) info "  set DISPLAYMANAGER=\"sddm\" in /etc/conf.d/display-manager, then: sudo rc-update add display-manager default" ;;
                    runit)  info "  sudo ln -s /etc/runit/sv/sddm /run/runit/service/" ;;
                    dinit)  info "  sudo dinitctl enable sddm" ;;
                    s6)     info "  sudo s6-service add default sddm && sudo s6-db-reload" ;;
                    *)      info "  enable the sddm service the way your init system does it" ;;
                esac
            fi
        elif [ "${ON[sddm_dm]}" = 1 ] && [ "$CUR_DM" != "sddm.service" ]; then
            [ -n "$CUR_DM" ] && sudo systemctl disable "$CUR_DM" >/dev/null 2>&1
            sudo systemctl enable sddm.service >/dev/null 2>&1 && info "SDDM is your login manager from the next boot"
        fi
    else
        warn "SDDM isn't installed, so the login screen was skipped"
    fi
fi

# ---------------------------------------------------------------- retro icons
if [ "${ON[icons]}" = 1 ]; then
    step "Retro icons"
    ICONDIR="$HOME/.local/share/icons/Chicago95"
    if [ "${ON[icons]}" = 1 ] && [ ! -f "$ICONDIR/index.theme" ]; then
        info "downloading the Chicago95 icons…"
        TMPI="$(mktemp -d)"
        if git clone -q --depth 1 --filter=blob:none --sparse https://github.com/grassmunk/Chicago95 "$TMPI/c95" \
           && git -C "$TMPI/c95" sparse-checkout set Icons/Chicago95; then
            mkdir -p "$HOME/.local/share/icons"
            cp -r "$TMPI/c95/Icons/Chicago95" "$ICONDIR"
            # icons the theme doesn't have fall back to Breeze instead of showing blank
            grep -q '^Inherits=' "$ICONDIR/index.theme" || sed -i '/^\[Icon Theme\]/a Inherits=breeze,hicolor' "$ICONDIR/index.theme"
            gtk-update-icon-cache -f "$ICONDIR" >/dev/null 2>&1 || true
            info "retro icons installed"
        else
            warn "could not download the icons — Bevel keeps the Breeze icons"
        fi
        rm -rf "$TMPI"
    fi
    [ -f "$ICONDIR/index.theme" ] && info "Chicago95 icons ready"
fi
bevelctl set style.icons "$([ "${ON[icons]}" = 1 ] && echo retro || echo modern)" >/dev/null 2>&1

fi   # not APPS_ONLY

# ---------------------------------------------------------------- apps
if [ "${#APP_IDS[@]}" -gt 0 ]; then
    step "Theming your apps"
    bevelctl apps-setup >/dev/null 2>&1
    NOT_INSTALLED=()
    for id in "${APP_IDS[@]}"; do
        for a in "${APPS[@]}"; do IFS='|' read -r i2 pk nm _ _ <<<"$a"; [ "$i2" = "$id" ] && break; done
        if ! app_installed "$pk"; then
            warn "$nm is NOT installed (pacman didn't install: $pk)"
            NOT_INSTALLED+=("$nm")
            continue
        fi
        case "$id" in
            vscode) info "Visual Studio Code: Bevel colour theme (follows your wallpaper)" ;;
            neovim) info "Neovim: 'bevel' colour scheme (~/.config/nvim/colors/bevel.lua)" ;;
            audacious) info "Audacious: Winamp-style interface with a Bevel skin" ;;
            cmus) info "cmus: 'bevel' colour scheme" ;;
            mpv) info "mpv: 9x control box, screenshots to ~/Pictures/Screenshots" ;;
            celluloid) info "Celluloid: uses the 9x window theme" ;;
            cava) info "cava: bars in your accent colours" ;;
            imv) info "imv: themed background and overlay" ;;
            zathura) info "Zathura: accent status bar, themed colours" ;;
            btop) info "btop: square boxes, block graphs, your colours" ;;
            *) for a in "${APPS[@]}"; do IFS='|' read -r i2 _ nm _ _ <<<"$a"; [ "$i2" = "$id" ] && info "$nm: uses the Bevel colours"; done ;;
        esac
    done
    # open files with the apps you picked
    MIME_SET=0
    setmime() { local app="$1"; shift; [ -f "/usr/share/applications/$app" ] && xdg-mime default "$app" "$@" 2>/dev/null && MIME_SET=1; }
    if command -v xdg-mime >/dev/null; then
        [ "${ON[app_mpv]}" = 1 ] && setmime mpv.desktop video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo
        [ "${ON[app_audacious]}" = 1 ] && setmime audacious.desktop audio/mpeg audio/flac audio/ogg audio/x-wav audio/mp4
        [ "${ON[app_imv]}" = 1 ] && setmime imv.desktop image/png image/jpeg image/gif image/webp image/bmp
        [ "${ON[app_zathura]}" = 1 ] && setmime org.pwmt.zathura.desktop application/pdf
        [ "$MIME_SET" = 1 ] && info "set as the default apps for their file types"
    fi
fi

# ---------------------------------------------------------------- start
step "Starting"
if [ "$APPS_ONLY" = 0 ]; then
    for d in dunst mako swaync; do pgrep -x "$d" >/dev/null && { info "stopping $d (Bevel shows its own notifications)"; pkill -x "$d" || true; }; done
    pgrep -x waybar >/dev/null && { warn "waybar is running — Bevel has its own bar. Stopping it for this session."; pkill -x waybar || true; }
    # other desktop shells a distro's Hyprland edition may start (CachyOS, Garuda…): their bars would sit on top of Bevel's
    for d in hyprpanel nwg-panel ags; do pgrep -x "$d" >/dev/null && { info "stopping $d (Bevel has its own bar)"; pkill -x "$d" || true; }; done
    if pgrep -af '(^|/)(qs|quickshell)( |$)' | grep -v -e '-c bevel' -e 'quickshell/bevel/' | grep -q .; then
        info "stopping the other Quickshell desktop that was running (Bevel replaces it)"
        pgrep -af '(^|/)(qs|quickshell)( |$)' | grep -v -e '-c bevel' -e 'quickshell/bevel/' | awk '{print $1}' | xargs -r kill 2>/dev/null || true
    fi
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ "${ON[hypr]}" = 1 ]; then
        pgrep -x awww-daemon >/dev/null || pgrep -x swww-daemon >/dev/null || \
            { (command -v awww-daemon >/dev/null && setsid -f awww-daemon) || (command -v swww-daemon >/dev/null && setsid -f swww-daemon) || true; } >/dev/null 2>&1
        pkill -f "qs -c bevel" 2>/dev/null || true
        sleep 0.3
        setsid -f qs -c bevel >/dev/null 2>&1 || true
        sleep 0.5
        bevelctl restore >/dev/null 2>&1 || true
        hyprctl reload >/dev/null 2>&1 || true
        info "running — try Super+R, Super+L, Super+I"
        # the Welcome tour, now — unless it has been seen before
        [ -e "$HOME/.config/bevel/.welcome-shown" ] || { sleep 1; bevelctl welcome >/dev/null 2>&1 || true; }
    else
        info "log into Hyprland and everything starts by itself"
    fi
fi
printf '%s[34m %s 100%%%s[0m\n' "$B" "$(rep █ 60)" "$B"

done_lines=(
    "$([ "$UPDATE" = 1 ] && echo "Bevel is updated to version $(cat "$HERE/VERSION" 2>/dev/null || echo "?")." || echo "Bevel Setup has finished installing.")"
    ""
)
if [ "$APPS_ONLY" = 0 ]; then
    done_lines+=(
        "  Super+A control panel  ·  Super+I settings  ·  Super+F1 all the keys"
        "  Super+R run  ·  Super+E files  ·  Super+W new wallpaper"
        "  The Welcome tour: menu → Welcome to Bevel (it also opens at your next login)."
        ""
        "Your old files are in:"
        "  ${BACKUP/#$HOME/\~}"
        "Undo everything with ./uninstall.sh"
    )
else
    done_lines+=("Your new apps are in the menu, already in your colours.")
fi
if [ "${#NOT_INSTALLED[@]}" -gt 0 ]; then
    done_lines+=("" "Not installed: ${NOT_INSTALLED[*]}" "Try again with: ./install.sh --apps")
elif [ "${ON[app_vscode]}" = 1 ]; then
    done_lines+=("" "VS Code: if it was open, reload it (Ctrl+Shift+P → Reload Window).")
fi
if [ "$TUI" = 1 ]; then
    finish_screen "${done_lines[@]}"
fi
echo
for ln in "${done_lines[@]}"; do echo "  $ln"; done
echo
rm -f "$PACLOG"
