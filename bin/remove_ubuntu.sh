#!/bin/sh
set -e

ROOT="/mnt/us/ubuntu"
ALREADYMOUNTED="no"
cd "$ROOT"

if mount | grep -q "on "$ROOT/mnt" "; then
    ALREADYMOUNTED="yes"
    echo "[uninstaller] image mounted, unmounting image…"
    umount "$ROOT/mnt/dev" || true
    umount "$ROOT/mnt/proc" || true
    umount "$ROOT/mnt/sys" || true
    umount "$ROOT/mnt" || true
    echo "[uninstaller] Starting to remove ubuntu"

else
    echo "[uninstaller] Starting to remove ubuntu"
    fi

mkdir -p "$ROOT"
cd "$ROOT"
rm -r *

echo "[uninstaller] Done"
echo ""

sh /mnt/us/extensions/kindle_ubuntu-system/bin/press_any_key.sh