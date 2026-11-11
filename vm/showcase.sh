#!/bin/sh
# showcase.sh NAME m3-theme-args...   e.g. showcase.sh orange-dark color 8B5000 (no '#': it goes through ssh)
d="$(cd "$(dirname "$0")" && pwd)"; name="$1"; shift
"$d/hc.sh" "m3-theme $* >/dev/null; pkill nautilus; pkill gnome-system-mo; pkill foot; sleep 1
dd(){ hyprctl dispatch \"\$1\" >/dev/null; }
setsid -f nautilus --new-window >/dev/null 2>&1; sleep 2.5; setsid -f foot >/dev/null 2>&1; sleep 1.5; setsid -f gnome-system-monitor >/dev/null 2>&1; sleep 3.5
for c in org.gnome.Nautilus org.gnome.SystemMonitor foot; do dd \"hl.dsp.window.float({ action = 'enable', window = 'class:\$c' })\"; done
dd \"hl.dsp.window.resize({ x = 940, y = 600, window = 'class:org.gnome.Nautilus' })\"; dd \"hl.dsp.window.move({ x = 100, y = 120, window = 'class:org.gnome.Nautilus' })\"
dd \"hl.dsp.window.resize({ x = 720, y = 380, window = 'class:foot' })\"; dd \"hl.dsp.window.move({ x = 1100, y = 120, window = 'class:foot' })\"
dd \"hl.dsp.window.resize({ x = 1060, y = 480, window = 'class:org.gnome.SystemMonitor' })\"; dd \"hl.dsp.window.move({ x = 760, y = 540, window = 'class:org.gnome.SystemMonitor' })\"
dd \"hl.dsp.focus({ window = 'class:org.gnome.SystemMonitor' })\"; dd 'hl.dsp.window.bring_to_top()'; sleep 1.5"
python3 "$d/qmp.py" move 1880 600; sleep 0.8
python3 "$d/qmp.py" shot "$d/../screenshots/$name.png"
