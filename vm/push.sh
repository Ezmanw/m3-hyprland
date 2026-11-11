#!/bin/sh
# copy the working tree's config + bin into the running VM and reload the desktop
d="$(cd "$(dirname "$0")" && pwd)"
cd "$d/.." && tar -cf - install.sh bin config | "$d/ssh.sh" 'tar -xf - -C ~/m3-hyprland && cd ~/m3-hyprland && cp -a config/hypr/hyprland.lua config/hypr/hyprlock.conf ~/.config/hypr/ && cp -a config/waybar/. ~/.config/waybar/ && cp -a config/swaync/. ~/.config/swaync/ && cp -a config/matugen/. ~/.config/matugen/ && install -m755 bin/* ~/.local/bin/'
"$d/hc.sh" 'm3-theme apply; pkill -x waybar; sleep 0.5; setsid -f waybar >/dev/null 2>&1; hyprctl configerrors'
