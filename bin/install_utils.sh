#!/bin/sh
set -e

ROOT="/mnt/us/ubuntu"
MNT="$ROOT/mnt"

KINDLE_LANG="fr_FR.UTF-8"

echo "[installer] Language: $KINDLE_LANG"

mkdir -p "$MNT/dev/pts" "$MNT/proc" "$MNT/sys"

echo "[installer] Mounting Ubuntu image..."
mount -o loop "$ROOT/ubuntu.ext4" "$MNT"

mount -o bind /dev "$MNT/dev"
mount -o bind /tmp "$MNT/tmp"
mount -o bind /dev/pts "$MNT/dev/pts"
mount -t proc proc "$MNT/proc"
mount -t sysfs sysfs "$MNT/sys"

echo "[installer] Configuring Ubuntu..."

chroot "$MNT" /bin/bash <<EOF
set -e
export DEBIAN_FRONTEND=noninteractive

# Create the kindle user if needed
if ! id kindle >/dev/null 2>&1; then
    useradd -m -s /bin/bash kindle
    echo "kindle:kindle" | chpasswd
    echo "[installer] User kindle created."
else
    echo "[installer] User kindle already exists."
    echo "kindle:kindle" | chpasswd
fi

# Ensure the home directory and shell exist
mkdir -p /home/kindle
chown kindle:kindle /home/kindle
usermod -s /bin/bash kindle

echo "[installer] Updating packages..."
apt update
apt upgrade -y

echo "[installer] Installing utilities..."
apt install -y --no-install-recommends \
    nano \
    apt-utils \
    inetutils-ping \
    wget \
    git \
    python3-virtualenv \
    sudo \
    locales

# Add kindle to sudo group
usermod -aG sudo kindle

# Configure French locale
if ! grep -qxF "$KINDLE_LANG UTF-8" /etc/locale.gen; then
    echo "$KINDLE_LANG UTF-8" >> /etc/locale.gen
fi

locale-gen "$KINDLE_LANG"
update-locale LANG="$KINDLE_LANG"

apt clean

echo "[installer] User details:"
id kindle
EOF

echo "[installer] Unmounting..."

umount "$MNT/dev/pts" || true
umount "$MNT/dev" || true
umount "$MNT/proc" || true
umount "$MNT/sys" || true
umount "$MNT" || true

echo "[installer] DONE: Ubuntu configured."
echo "[installer] Login: kindle"
echo "[installer] Password: kindle"

sh /mnt/us/extensions/kindle_ubuntu-system/bin/press_any_key.sh