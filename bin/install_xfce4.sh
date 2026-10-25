#!/bin/sh
set -eu

ROOT="/mnt/us/ubuntu"
MNT="$ROOT/mnt"
LANGUAGE="fr_FR.UTF-8"

echo "[installer] Mounting Ubuntu..."

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

chroot "$MNT" /bin/bash <<EOF
set -e
export DEBIAN_FRONTEND=noninteractive

echo "[installer] Updating…"
apt update

echo "[installer] Installing XFCE4 and utils…"
apt install -y --no-install-recommends \
    xfce4 xfce4-session xfce4-panel xfce4-terminal \
    xfce4-settings xfce4-power-manager xfwm4 \
    lightdm lightdm-gtk-greeter \
    x11-utils x11-xserver-utils \
    xserver-xorg-core xserver-xorg-video-fbdev xserver-xephyr \
    xinit xinput dbus-x11 dbus \
    openssh-client gpg-agent \
    accountsservice onboard

# Create the normal user if needed
if ! id kindle >/dev/null 2>&1; then
    useradd -m -s /bin/bash kindle
fi

echo 'kindle:kindle' | chpasswd
usermod -aG sudo kindle
usermod -s /bin/bash kindle

# Configure French locale
if ! grep -qxF "$LANGUAGE UTF-8" /etc/locale.gen; then
    echo "$LANGUAGE UTF-8" >> /etc/locale.gen
fi

locale-gen "$LANGUAGE"
update-locale LANG="$LANGUAGE"

echo "[installer] Configuring XFCE4"
# Configure Xorg framebuffer
mkdir -p /etc/X11

cat > /etc/X11/xorg.conf <<'XEOF'
Section "Device"
    Identifier "KindleFB"
    Driver "fbdev"
    Option "fbdev" "/dev/fb0"
EndSection

Section "Monitor"
    Identifier "KindleMonitor"
EndSection

Section "Screen"
    Identifier "KindleScreen"
    Device "KindleFB"
    Monitor "KindleMonitor"
    DefaultDepth 16
    SubSection "Display"
        Depth 16
        Modes "600x800"
    EndSubSection
EndSection
XEOF

# Configure LightDM
cat > /etc/lightdm/lightdm.conf <<'LEOF'
[LightDM]
minimum-display-number=0

[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=xfce
LEOF

# XFCE session
mkdir -p /usr/share/xsessions

cat > /usr/share/xsessions/xfce.desktop <<'XEOF'
[Desktop Entry]
Name=XFCE
Comment=XFCE Desktop Environment
Exec=startxfce4
Type=Application
DesktopNames=XFCE
XEOF

mkdir -p ~/.config/autostart && cat << 'LEOF' > ~/.config/autostart/onboard.desktop
[Desktop Entry]
Type=Application
Name=Onboard
Exec=onboard
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
OnlyShowIn=XFCE;
LEOF

apt clean
EOF

echo "[installer] XFCE4 and LightDM installed."
echo "[installer] Login: kindle / Password: kindle"

cleanup() {
    umount "$MNT/dev/pts" 2>/dev/null || true
    umount "$MNT/dev" 2>/dev/null || true
    umount "$MNT/proc" 2>/dev/null || true
    umount "$MNT/sys" 2>/dev/null || true
    umount "$MNT" 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

sh /mnt/us/extensions/kindle_ubuntu-system/bin/press_any_key.sh