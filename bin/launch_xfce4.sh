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

chroot "$MNT" /bin/bash -c '
set -eu

export DEBIAN_FRONTEND=noninteractive
export LANG=fr_FR.UTF-8
export LC_ALL=fr_FR.UTF-8
export HOME=/root
export DISPLAY=:1
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
SIZE=$(xwininfo -root -display :0 | egrep "geometry" | cut -d" " -f4 | cut -d"+" -f1) 

echo "[info] Your display size is $SIZE"
echo "[launcher] Starting D-Bus..."
mkdir -p /tmp /run/dbus
rm -f /run/dbus/pid
dbus-daemon --system --fork

echo "[launcher] Launching Xephyr and XFCE4"
sleep 5
env DISPLAY=:0 Xephyr :1 -title "L:D_N:application_ID:xephyr" -ac -br -screen $SIZE -cc 4 -reset -terminate & sleep 3 && env DISPLAY=:1 xfce4-session
killall Xephyr
'

cleanup() {
    umount "$MNT/dev/pts" 2>/dev/null || true
    umount "$MNT/dev/" 2>/dev/null || true
    umount "$MNT/proc" 2>/dev/null || true
    umount "$MNT/sys" 2>/dev/null || true
    umount "$MNT" 2>/dev/null || true
}

trap cleanup EXIT HUP INT TERM

CHROOT_PID=$!

wait "$CHROOT_PID"
STATUS=$?
CHROOT_PID=""

echo "[launcher] Relaunching lab126_gui"
start lab126_gui

echo "[launcher]Session end with the code $STATUS."
echo "[launcher]$STATUS"

exit "$STATUS"