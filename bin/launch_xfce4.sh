
#!/bin/sh

set -eu

ROOT="/mnt/us/ubuntu"
MNT="$ROOT/mnt"
LANGUAGE="fr_FR.UTF-8"

echo "[launcher] Mounting Ubuntu..."

mkdir -p "$MNT"
mount -o loop "$ROOT/ubuntu.ext4" "$MNT"

cleanup() {
    umount "$MNT/dev/pts" 2>/dev/null || true
    umount "$MNT/dev" 2>/dev/null || true
    umount "$MNT/proc" 2>/dev/null || true
    umount "$MNT/sys" 2>/dev/null || true
    umount "$MNT" 2>/dev/null || true
}

trap cleanup EXIT HUP INT TERM

mount -o bind /dev "$MNT/dev"
mount -o bind /dev/pts "$MNT/dev/pts"
mount -o bind /tmp "$MNT/tmp"
mount -t proc proc "$MNT/proc"
mount -t sysfs sysfs "$MNT/sys"

echo "[launcher] Starting GUI"

chroot "$MNT" /bin/su - kindle -c '
set -eu

export LANG=fr_FR.UTF-8
export LC_ALL=fr_FR.UTF-8
export DISPLAY=:1
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE

echo "[info] User: $(id)"
echo "[info] HOME=$HOME DISPLAY=$DISPLAY"

SIZE=$(xwininfo -root -display :0 | egrep "geometry" | cut -d" " -f4 | cut -d"+" -f1)

echo "[info] Display size: $SIZE"

#if [ ! -S /run/dbus/system_bus_socket ]; then
#    dbus-daemon --system --fork
#fi

echo "[launcher] Starting Xephyr"
env DISPLAY=:0 Xephyr :1 \
    -title "L:D_N:application_ID:xephyr" \
    -ac -br -screen "$SIZE" -cc 4 -reset -terminate &

XEPHYR_PID=$!

cleanup_gui() {
    kill "$XEPHYR_PID" 2>/dev/null || true
}
trap cleanup_gui EXIT HUP INT TERM

sleep 3

echo "[launcher] Starting XFCE4"
DISPLAY=:1 xfce4-session
'

STATUS=$?

echo "[launcher] Relaunching lab126_gui"
start lab126_gui

echo "[launcher] Session ended with code $STATUS"
exit "$STATUS"
