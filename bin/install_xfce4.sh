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

mkdir -p "$MNT/dev" "$MNT/dev/pts" "$MNT/proc" "$MNT/sys" "$MNT/tmp"

mount -o bind /dev "$MNT/dev"
mount -o bind /dev/pts "$MNT/dev/pts"
mount -o bind /tmp "$MNT/tmp"
mount -t proc proc "$MNT/proc"
mount -t sysfs sysfs "$MNT/sys"

chroot "$MNT" /bin/bash <<EOF
set -e
export DEBIAN_FRONTEND=noninteractive

echo "[installer] Updating..."
apt update

echo "[installer] Installing XFCE4, Onboard and dependencies..."

apt install -y --no-install-recommends \
    xfce4 xfce4-session xfce4-panel xfce4-terminal \
    xfce4-settings xfce4-power-manager xfwm4 \
    lightdm lightdm-gtk-greeter \
    x11-utils x11-xserver-utils \
    xserver-xorg-core xserver-xorg-video-fbdev xserver-xephyr \
    xinit xinput dbus-x11 dbus \
    openssh-client gpg-agent \
    accountsservice \
    onboard onboard-data \
    gir1.2-atspi-2.0 \
    at-spi2-core \
    dconf-gsettings-backend \
    sudo

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

echo "[installer] Configuring Xorg framebuffer..."

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

echo "[installer] Configuring LightDM..."

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

echo "[installer] Configuring Onboard..."

# Remove the incorrect root autostart configuration, if present.
rm -f /root/.config/autostart/onboard.desktop

# Create the autostart directory for the actual desktop user.
install -d -o kindle -g kindle -m 0755 \
    /home/kindle/.config/autostart

cat > /home/kindle/.config/autostart/onboard.desktop <<'LEOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Onboard
Comment=On-screen keyboard
Exec=onboard
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
OnlyShowIn=XFCE;
LEOF

chown kindle:kindle /home/kindle/.config/autostart/onboard.desktop

# Configure Onboard to use GTK input events when this setting exists.
# Do not fail installation if this Onboard version lacks the setting.
if command -v gsettings >/dev/null 2>&1; then
    if su -s /bin/sh kindle -c \
        "gsettings writable org.onboard.keyboard input-event-source" \
        2>/dev/null | grep -qx true; then
        su -s /bin/sh kindle -c \
            "gsettings set org.onboard.keyboard input-event-source 'GTK'" \
            || true
    fi
fi

# Ensure the user owns their configuration directory.
chown -R kindle:kindle /home/kindle/.config

echo "[installer] Checking Onboard..."

if command -v onboard >/dev/null 2>&1; then
    echo "[installer] Onboard executable: $(command -v onboard)"
else
    echo "[installer] WARNING: onboard executable not found."
fi

apt clean
EOF

echo "[installer] XFCE4 and Onboard configured."
echo "[installer] Login: kindle / Password: kindle"

sh /mnt/us/extensions/kindle_ubuntu-system/bin/press_any_key.sh
