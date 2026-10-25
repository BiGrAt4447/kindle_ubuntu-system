#!/bin/sh

ROOT="/mnt/us/ubuntu"
MNT="$ROOT/mnt"

# This script must be run on a rooted Kindle
if [ "$(id -u)" != "0" ]; then
    echo "[launcher] Error : your Kindle must be rooted"
    exit 1
fi

#Check if Ubuntu image exist
if [ ! -f "$ROOT/ubuntu.ext4" ]; then
    echo "[launcher] Error : Ubuntu image not found."
    exit 1
fi

#Mounting if not mounted already
if [ ! -x "$MNT/bin/su" ] || [ ! -x "$MNT/bin/bash" ]; then
    echo "[launcher] Ubuntu is not mount"
    mkdir -p "$MNT"
    mount -o loop "$ROOT/ubuntu.ext4" "$MNT"

    mount -o bind /dev "$MNT/dev"
    mount -o bind /dev/pts "$MNT/dev/pts"
    mount -o bind /proc "$MNT/proc"
    mount -o bind /sys "$MNT/sys"
    mount -o bind /tmp "$MNT/tmp"
fi

#Check if user "kindle" exist
if ! grep -q '^kindle:' "$MNT/etc/passwd"; then
    echo "[launcher] Error : kindle user not found."
    exit 1
fi

cleanup() {
    echo "[launcher] Unmounting..."
    umount "$MNT/dev/pts" 2>/dev/null || :
    umount "$MNT/dev"     2>/dev/null || :
    umount "$MNT/proc"    2>/dev/null || :
    umount "$MNT/sys"     2>/dev/null || :
    umount "$MNT"         2>/dev/null || :
}

mkdir -p "$MNT"

echo "[launcher] Mounting Ubuntu…"

mount -o loop "$ROOT/ubuntu.ext4" "$MNT" || exit 1


mount -o bind /dev "$MNT/dev" || {
    umount "$MNT"
    exit 1
}

mount -o bind /dev/pts "$MNT/dev/pts" || {
    umount "$MNT/dev"
    umount "$MNT"
    exit 1
}

mount -t proc proc "$MNT/proc" || {
    cleanup
    exit 1
}

mount -t sysfs sysfs "$MNT/sys" || {
    cleanup
    exit 1
}

trap cleanup 0

echo "[launcher] Ubuntu: user kindle"
chroot "$MNT" /bin/su - kindle