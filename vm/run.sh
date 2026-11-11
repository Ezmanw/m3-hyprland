#!/bin/sh
# Boot the M3 Hyprland test VM.
#   ./run.sh          headless (no window, no sound)
#   ./run.sh --show   open a window so you can use the desktop yourself
cd "$(dirname "$0")"
display="-display none"
[ "$1" = "--show" ] && display="-display gtk,zoom-to-fit=on"
exec qemu-system-x86_64 \
	-enable-kvm -cpu host -smp 6 -m 6144 \
	-drive file=m3.qcow2,if=virtio \
	-drive file=seed.iso,media=cdrom,readonly=on \
	-device virtio-vga,xres=1920,yres=1080 \
	-device virtio-tablet-pci -device virtio-keyboard-pci \
	-nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2223-:22 \
	-qmp unix:qmp.sock,server=on,wait=off \
	$display
