#!/bin/sh
# run a command inside the VM's Hyprland session: ./hc.sh 'hyprctl clients'
d="$(dirname "$0")"
exec "$d/ssh.sh" 'export XDG_RUNTIME_DIR=/run/user/$(id -u); export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t $XDG_RUNTIME_DIR/hypr | head -1); export WAYLAND_DISPLAY=$(ls $XDG_RUNTIME_DIR | grep -m1 "^wayland-[0-9]*$"); export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus; export PATH=$HOME/.local/bin:$PATH; '"$1"
