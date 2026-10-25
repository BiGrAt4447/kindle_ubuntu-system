#!/bin/sh
set -e

ROOT="/mnt/us/ubuntu"
IMG="$ROOT/ubuntu.ext4"
SIZE_MB=4000 #<-- change the size of the Ubuntu root here
# Change URL if you want a different Ubuntu release (this is the armhf release)
URL="https://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04-base-armhf.tar.gz"

echo "[installer] Ensure to have at least $SIZE_MB MB free on your kindle storage (3 dots menu in the upper right --> settings --> device options --> storage management)"

mkdir -p "$ROOT"
cd "$ROOT"

echo "[installer] Downloading ubuntu"
wget --no-check-certificate "$URL"
cat ubuntu-base* > ubuntu.tar.gz
rm ubuntu-base*

echo "[installer] Creating ext4 image of $SIZE_MB MB (this might take while)..."
dd if=/dev/zero of="$IMG" bs=1M count=$SIZE_MB
mkfs.ext4 -F "$IMG"

echo "[installer] Mounting image..."
mkdir -p "$ROOT/mnt"
mount -o loop "$IMG" "$ROOT/mnt"

echo "[installer] Extracting rootfs (this may take a while)..."
tar -xzf ubuntu.tar.gz -C "$ROOT/mnt"

echo "[installer] Binding system mounts..."
mount -o bind /dev "$ROOT/mnt/dev"
mount -o bind /dev/pts "$MNT/dev/pts"
mount -o bind /proc "$ROOT/mnt/proc"
mount -o bind /sys "$ROOT/mnt/sys"

echo "[installer] Setting DNS..."
echo "nameserver 8.8.8.8" > "$ROOT/mnt/etc/resolv.conf"

echo "[installer] Running initial setup inside chroot..."
chroot "$ROOT/mnt" /bin/bash <<'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive
EOF

echo "[installer] Syncing and unmounting..."
sync
umount "$ROOT/mnt/dev" || true
umount "$ROOT/mnt/proc" || true
umount "$ROOT/mnt/sys" || true
umount "$ROOT/mnt" || true

echo "[installer] Installation complete."
echo ""

echo "[installer] Rebooting to finalize installation"
sleep 2
reboot