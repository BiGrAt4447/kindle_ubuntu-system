#!/bin/sh
set -eu

ROOT="/mnt/us/ubuntu"
MNT="$ROOT/mnt"
LANGUAGE="fr_FR.UTF-8"
STARTGUI='#!/bin/sh
chmod a+w /dev/shm
SIZE=$(xwininfo -root -display :0 | egrep "geometry" | cut -d" " -f4 | cut -d"+" -f1)
env DISPLAY=:0 Xephyr :1 -title "L:D_N:application_ID:xephyr" -ac -br -screen "$SIZE" -cc 4 -reset -terminate & sleep 3 && env DISPLAY=:1 xfce4-session'

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

mntroot rw

# Copying Chromium to have web browser in Ubuntu
echo "[installer] Copying Chromium to Ubuntu…"
cp -rt /mnt/us/extensions/kindle_ubuntu-system/bin/chromium-armhf /mnt/us/ubuntu/mnt/opt
echo "[installer] Chromium copied successfully"
sleep 2

# Creating startgui.sh
echo "[installer] Creating startgui.sh…"
echo "$STARTGUI" > "$MNT/startgui.sh"
chmod +x "$MNT/startgui.sh"
echo "[installer] startgui.sh created successfully"
sleep 2

# Copying Ubuntu.conf
echo "[installer] Copying Ubuntu.conf to /etc/upstart…"
cp /mnt/us/extensions/kindle_ubuntu-system/bin/Ubuntu.conf /etc/upstart
echo "[installer] Ubuntu.conf copied successfully"
sleep 2

mntroot ro

chroot "$MNT" /bin/bash <<EOF
set -e
export DEBIAN_FRONTEND=noninteractive
mkdir -p /tmp /run/dbus

echo "[installer] Updating…"
apt update

echo "[installer] Installing XFCE4 and utils…"
apt install -y --no-install-recommends \
    xfce4 xfce4-session xfce4-panel xfce4-terminal \
    xfce4-settings xfce4-power-manager xfwm4  xfce4-systemload-plugin \
    x11-utils x11-xserver-utils \
    xserver-xorg-core xserver-xorg-video-fbdev xserver-xephyr \
    xinit xinput dbus-x11 dbus \
    openssh-client gpg-agent \
    accountsservice onboard caribou \
    luakit

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

# Configure Onboard
gsettings set org.onboard.keyboard input-event-source 'GTK'

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
