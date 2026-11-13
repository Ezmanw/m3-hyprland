#!/usr/bin/env bash
# Material 3 Hyprland installer
#
#   ./install.sh              install everything
#   ./install.sh --no-emote   skip the Emote emoji picker (Flatpak)
#   ./install.sh --login-screen          also install the Material 3 login screen. This makes
#                                        SDDM your display manager (replacing GDM, COSMIC's
#                                        greeter, LightDM...) from the next boot.
#   ./install.sh --remove-login-screen   go back to the display manager you had before
#
# Supported: Debian 13 (Hyprland from trixie-backports)
#            Ubuntu / Pop!_OS 24.04+ (Hyprland from ppa:cppiber/hyprland)
# Anything it replaces in ~/.config is first copied to ~/.config/m3-hyprland-backup-<date>.
# Run it as your normal user; it asks for sudo only to install packages.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN="$HOME/.local/bin"
MATUGEN_VERSION=4.2.0
ADW_GTK3_VERSION=6.5
WANT_EMOTE=1
WANT_LOGIN=0
REMOVE_LOGIN=0
for a in "$@"; do
    case "$a" in
        --no-emote) WANT_EMOTE=0 ;;
        --login-screen) WANT_LOGIN=1 ;;
        --remove-login-screen) REMOVE_LOGIN=1 ;;
        -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $a" >&2; exit 2 ;;
    esac
done
DM_STATE=/var/lib/m3-hyprland

say()  { printf '\n\033[1;35m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "run this as your normal user, not root"

if [ "$REMOVE_LOGIN" = 1 ]; then
    say "Removing the Material 3 login screen (sudo)"
    prev="$(cat "$DM_STATE/previous-display-manager" 2>/dev/null || true)"
    if [ -n "$prev" ] && systemctl cat "$prev" >/dev/null 2>&1; then
        sudo systemctl enable --force "$prev"
        echo "$prev is your display manager again from the next boot."
    else
        sudo systemctl disable sddm || true
        warn "no previous display manager was recorded - SDDM is just disabled"
    fi
    if [ -f "$DM_STATE/previous-default-display-manager" ]; then
        sudo cp "$DM_STATE/previous-default-display-manager" /etc/X11/default-display-manager
    fi
    sudo rm -f /etc/sddm.conf.d/10-m3.conf
    exit 0
fi
[ -d "$HERE/config" ] && [ -d "$HERE/bin" ] || die "config/ and bin/ must sit next to install.sh"

# ---------------------------------------------------------------- packages --
. /etc/os-release
APT="sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y"

HYPR_PKGS="hyprland hyprlock hypridle hyprpolkitagent hyprland-guiutils xdg-desktop-portal-hyprland"
HYPR_EXTRA="hyprsunset"   # night light; optional
PKGS="waybar fuzzel sway-notification-center foot nautilus gnome-system-monitor
      papirus-icon-theme bibata-cursor-theme fonts-roboto grim slurp wl-clipboard cliphist
      brightnessctl playerctl pavucontrol pipewire-pulse wireplumber librsvg2-bin swaybg
      xdg-desktop-portal-gtk dbus-user-session libnotify-bin zenity curl xz-utils fontconfig libglib2.0-bin
      python3 python3-gi gir1.2-gtk-4.0 gir1.2-adw-1 pulseaudio-utils bluez swayosd
      qt5ct qt6ct qt6-wayland gnome-keyring seahorse libsecret-tools"
[ "$WANT_EMOTE" = 1 ] && PKGS="$PKGS flatpak"

apt_each() { # install one by one so a single missing package doesn't stop everything
    local p
    for p in "$@"; do $APT "$p" >/dev/null 2>&1 || warn "could not install '$p' - skipping it"; done
}

say "Installing packages (sudo)"
case "${ID}:${VERSION_CODENAME:-}" in
    debian:trixie)
        if ! grep -rqs 'trixie-backports' /etc/apt/sources.list /etc/apt/sources.list.d; then
            echo 'deb http://deb.debian.org/debian trixie-backports main' |
                sudo tee /etc/apt/sources.list.d/trixie-backports.list >/dev/null
        fi
        sudo apt-get update
        # Hyprland's backport needs the matching pipewire / xkbcommon from backports too
        # shellcheck disable=SC2086
        $APT -t trixie-backports $HYPR_PKGS pipewire pipewire-pulse wireplumber libxkbregistry0
        $APT -t trixie-backports $HYPR_EXTRA >/dev/null 2>&1 || warn "could not install '$HYPR_EXTRA' - night light will be unavailable"
        ;;
    ubuntu:*|pop:*)
        command -v add-apt-repository >/dev/null || $APT software-properties-common
        sudo add-apt-repository -y ppa:cppiber/hyprland
        sudo apt-get update
        # shellcheck disable=SC2086
        $APT $HYPR_PKGS
        $APT $HYPR_EXTRA >/dev/null 2>&1 || warn "could not install '$HYPR_EXTRA' - night light will be unavailable"
        ;;
    *)
        if command -v Hyprland >/dev/null; then
            warn "untested distro '${PRETTY_NAME:-$ID}': Hyprland is already here, installing the rest with apt"
            sudo apt-get update || true
        else
            die "unsupported distro '${PRETTY_NAME:-$ID}'. Install Hyprland 0.55+ yourself, then run this again."
        fi
        ;;
esac
# shellcheck disable=SC2086
$APT $PKGS || { warn "bulk install failed, retrying package by package"; apt_each $PKGS; }

Hyprland --version 2>/dev/null | head -1 || die "Hyprland did not install"
[ -e /usr/share/hypr/hyprland.lua ] || warn "this Hyprland looks older than 0.55 (no Lua config) - the config here needs 0.55+"

# ----------------------------------------------------------- user programs --
mkdir -p "$BIN" "$DATA/fonts/m3" "$DATA/themes" "$CFG"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fetch() { curl -fL --retry 3 --connect-timeout 20 -sS -o "$2" "$1"; }

if ! "$BIN/matugen" --version 2>/dev/null | grep -q "$MATUGEN_VERSION"; then
    say "Installing matugen $MATUGEN_VERSION (Material 3 palette generator)"
    case "$(uname -m)" in
        x86_64)
            fetch "https://github.com/InioX/matugen/releases/download/v$MATUGEN_VERSION/matugen-$MATUGEN_VERSION-x86_64.tar.gz" "$TMP/matugen.tgz"
            tar -xzf "$TMP/matugen.tgz" -C "$TMP"
            install -m755 "$(find "$TMP" -type f -name matugen | head -1)" "$BIN/matugen"
            ;;
        *)
            command -v matugen >/dev/null || die "no prebuilt matugen for $(uname -m): install it with 'cargo install matugen', then run this again"
            ;;
    esac
fi

say "Installing fonts (Google Sans Flex, Material Symbols Rounded)"
GF=https://github.com/google
[ -s "$DATA/fonts/m3/GoogleSansFlex.ttf" ] ||
    fetch "$GF/fonts/raw/main/ofl/googlesansflex/GoogleSansFlex%5BROND%2Copsz%2Cslnt%2Cwdth%2Cwght%5D.ttf" "$DATA/fonts/m3/GoogleSansFlex.ttf" ||
    warn "Google Sans Flex download failed - the desktop falls back to Roboto"
[ -s "$DATA/fonts/m3/MaterialSymbolsRounded.ttf" ] ||
    fetch "$GF/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" "$DATA/fonts/m3/MaterialSymbolsRounded.ttf" ||
    warn "Material Symbols download failed - bar icons will be missing"
fc-cache -f "$DATA/fonts" >/dev/null 2>&1 || true

if [ ! -d "$DATA/themes/adw-gtk3-dark" ]; then
    say "Installing adw-gtk3 (GTK3 theme that takes the M3 colours)"
    if fetch "https://github.com/lassekongo83/adw-gtk3/releases/download/v$ADW_GTK3_VERSION/adw-gtk3v$ADW_GTK3_VERSION.tar.xz" "$TMP/adw.tar.xz"; then
        tar -xJf "$TMP/adw.tar.xz" -C "$DATA/themes"
    else
        warn "adw-gtk3 download failed - GTK3 apps keep their default look"
    fi
fi

if [ "$WANT_EMOTE" = 1 ] && command -v flatpak >/dev/null; then
    if ! flatpak info com.tomjwatson.Emote >/dev/null 2>&1; then
        say "Installing Emote (emoji picker, Super+.)"
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo &&
            flatpak install --user -y --noninteractive flathub com.tomjwatson.Emote ||
            warn "Emote did not install - Super+. will do nothing until you install it"
    fi
    # let Emote read the M3 GTK colours
    flatpak override --user --filesystem=xdg-config/gtk-4.0:ro --filesystem=xdg-config/gtk-3.0:ro com.tomjwatson.Emote 2>/dev/null || true
fi

# ------------------------------------------------------------------ config --
say "Installing configuration"
BACKUP="$CFG/m3-hyprland-backup-$(date +%Y%m%d-%H%M%S)"
backup() { # backup <path relative to ~/.config>
    if [ -e "$CFG/$1" ]; then
        mkdir -p "$BACKUP/$(dirname "$1")"
        cp -a "$CFG/$1" "$BACKUP/$1"
    fi
}
for p in hypr waybar swaync swayosd matugen fuzzel/fuzzel.ini foot/foot.ini gtk-3.0/gtk.css gtk-4.0/gtk.css \
         qt5ct/qt5ct.conf qt6ct/qt6ct.conf m3-theme.conf m3-settings.json; do
    backup "$p"
done

KEEP_USER_LUA=0; [ -f "$CFG/hypr/user.lua" ] && KEEP_USER_LUA=1
mkdir -p "$CFG"/{hypr,waybar,swaync,matugen,gtk-3.0,gtk-4.0,xdg-desktop-portal} "$DATA/applications"
[ "$KEEP_USER_LUA" = 1 ] && cp -a "$CFG/hypr/user.lua" "$TMP/user.lua"
cp -a "$HERE/config/hypr/."    "$CFG/hypr/"
cp -a "$HERE/config/waybar/."  "$CFG/waybar/"
cp -a "$HERE/config/swaync/."  "$CFG/swaync/"
cp -a "$HERE/config/matugen/." "$CFG/matugen/"
cp -a "$HERE/config/xdg-desktop-portal/." "$CFG/xdg-desktop-portal/"
cp -a "$HERE/config/gtk/gtk.css" "$CFG/gtk-3.0/gtk.css"
cp -a "$HERE/config/gtk/gtk.css" "$CFG/gtk-4.0/gtk.css"
install -m755 "$HERE"/bin/* "$BIN/"

[ "$KEEP_USER_LUA" = 1 ] && cp -a "$TMP/user.lua" "$CFG/hypr/user.lua"   # never overwrite personal tweaks

if [ ! -f "$CFG/m3-settings.json" ]; then
    # first install: carry over the keyboard layout this machine already uses
    LAYOUT="$(localectl status 2>/dev/null | awk -F': *' '/X11 Layout/{print $2}' | cut -d, -f1)"
    [ -n "$LAYOUT" ] || LAYOUT="$(. /etc/default/keyboard 2>/dev/null; echo "${XKBLAYOUT:-}" | cut -d, -f1)"
    case "$LAYOUT" in ''|*[!a-z0-9_]*) LAYOUT=us ;; esac
    printf '{\n  "kb_layout": "%s"\n}\n' "$LAYOUT" > "$CFG/m3-settings.json"
fi
"$BIN/m3-settings" --apply || warn "could not write ~/.config/hypr/settings.lua"

# These packages enable user services for every graphical session, so the bar, the
# notification daemon and the idle locker would also start inside COSMIC / GNOME.
# Hyprland starts them itself (hyprland.lua), so mask the units for this user.
systemctl --user mask waybar.service swaync.service hypridle.service hyprsunset.service \
    hyprpolkitagent.service >/dev/null 2>&1 || warn "could not mask the user services - they may also start in your other desktop"

# swaync older than 0.10 (Ubuntu 24.04) has no toggle buttons: make them plain buttons
if ! grep -qs 'update-command' /etc/xdg/swaync/configSchema.json; then
    python3 - "$CFG/swaync/config.json" <<'PY'
import json, sys
p = sys.argv[1]
c = json.load(open(p, encoding="utf-8"))
for a in c.get("widget-config", {}).get("buttons-grid", {}).get("actions", []):
    for k in ("type", "active", "update-command"):
        a.pop(k, None)
json.dump(c, open(p, "w", encoding="utf-8"), indent=4, ensure_ascii=False)
PY
fi

# keep helper entries out of the app search
for d in footclient foot-server gnome-system-monitor-kde; do
    [ -e "$DATA/applications/$d.desktop" ] ||
        printf '[Desktop Entry]\nType=Application\nName=%s\nNoDisplay=true\n' "$d" > "$DATA/applications/$d.desktop"
done
cat > "$DATA/applications/m3-settings.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Settings
Comment=Appearance, display, network, Bluetooth, sound and more
Exec=$BIN/m3-settings
Icon=preferences-system
Categories=Settings;
StartupWMClass=io.github.m3hyprland.Settings
EOF
cat > "$DATA/applications/m3-screenshot.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Snipping Tool
GenericName=Screenshot
Comment=Capture and annotate screenshots (Print / Super+Shift+S)
Exec=$BIN/m3-screenshot ui
Icon=applets-screenshooter
Categories=Utility;Graphics;
Keywords=screenshot;snip;capture;screen;
StartupWMClass=io.github.m3hyprland.Snip
EOF
# an old-style hyprland.conf would be ignored once hyprland.lua exists; it stays in the backup
[ -d "$BACKUP" ] && echo "previous config saved in $BACKUP"

# ------------------------------------------------------------ login screen --
if [ "$WANT_LOGIN" = 1 ]; then
    say "Installing the Material 3 login screen - SDDM (sudo)"
    # shellcheck disable=SC2086
    $APT --no-install-recommends sddm xserver-xorg
    apt_each qml6-module-qtquick qml-module-qtquick2
    THEME=/usr/share/sddm/themes/m3
    sudo mkdir -p "$THEME" /etc/sddm.conf.d /usr/local/share/fonts/m3 "$DM_STATE"
    sudo cp "$HERE"/config/sddm/m3/* "$THEME/"
    # SDDM 0.21 picks the Qt 6 greeter from this key; older SDDM only has Qt 5
    command -v sddm-greeter-qt6 >/dev/null || sudo sed -i '/^QtVersion=/d' "$THEME/metadata.desktop"
    # m3-theme keeps the login screen in the same colours through this file
    sudo touch "$THEME/theme.conf.user"
    sudo chown "$(id -un)" "$THEME/theme.conf.user"
    sudo cp "$DATA"/fonts/m3/*.ttf /usr/local/share/fonts/m3/ 2>/dev/null || warn "fonts missing - the login screen falls back to a default font"
    sudo fc-cache -f /usr/local/share/fonts >/dev/null 2>&1 || true
    # InputMethod= (empty) keeps Qt's on-screen keyboard from covering the login screen
    printf '[General]\nInputMethod=\n\n[Theme]\nCurrent=m3\nCursorTheme=Bibata-Modern-Classic\n' | sudo tee /etc/sddm.conf.d/10-m3.conf >/dev/null

    # remember the current display manager once, so --remove-login-screen can undo this
    cur="$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" 2>/dev/null || true)"
    if [ -n "$cur" ] && [ "$cur" != sddm.service ] && [ ! -f "$DM_STATE/previous-display-manager" ]; then
        echo "$cur" | sudo tee "$DM_STATE/previous-display-manager" >/dev/null
    fi
    if [ -f /etc/X11/default-display-manager ] && ! grep -q sddm /etc/X11/default-display-manager; then
        [ -f "$DM_STATE/previous-default-display-manager" ] ||
            sudo cp /etc/X11/default-display-manager "$DM_STATE/previous-default-display-manager"
    fi
    [ -d /etc/X11 ] && echo /usr/bin/sddm | sudo tee /etc/X11/default-display-manager >/dev/null
    sudo systemctl enable --force sddm
    echo "SDDM starts from the next boot. Undo with: ./install.sh --remove-login-screen"
fi

say "Generating the Material 3 theme"
"$BIN/m3-theme" apply || warn "theme generation failed - run 'm3-theme apply' after fixing the error above"

cat <<EOF

$(printf '\033[1;32mDone.\033[0m')  Log out and choose "Hyprland" on the login screen.

  Alt+Enter / tap Super   search apps        Alt+F4            close window
  Ctrl+Shift+Esc          task manager       Super+.           emoji picker (Emote)
  Super+E  files          Super+L  lock      Super+V           clipboard history
  Super+Shift+S           screenshot area    Super+I           settings
  Super+Up/Down           maximise/restore   Super+Ctrl+←/→    switch desktop
  Alt+Tab                 switch window      Ctrl+Alt+Del      power menu

  Settings: Super+I (colours, display, network, Bluetooth, sound, keyboard, default apps)
  Terminal: m3-theme color '#0061A4'  |  m3-theme light  |  m3-theme wallpaper ~/pic.jpg
  Tweaks:   ~/.config/hypr/user.lua (extra binds and anything Settings doesn't cover)
EOF
