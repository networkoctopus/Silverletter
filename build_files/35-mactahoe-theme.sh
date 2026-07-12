#!/bin/bash
set -ouex pipefail

### Clone MacTahoe GTK theme
# Keep the repo so tweaks.sh can find Firefox CSS source files at first-login
REPO_DIR="/usr/share/MacTahoe-gtk-theme"
git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git "$REPO_DIR"

### Install the official prebuilt light and dark GTK themes system-wide.
# Using upstream's release archives avoids running its interactive source
# installer during the image build.
mkdir -p /usr/share/themes
cd "$REPO_DIR"
tar -xJf release/MacTahoe-Light.tar.xz -C /usr/share/themes
tar -xJf release/MacTahoe-Dark.tar.xz -C /usr/share/themes

# Fail the image build if upstream returned success without producing the two
# variants advertised as available in the image.
test -f /usr/share/themes/MacTahoe-Light/gtk-3.0/gtk.css
test -f /usr/share/themes/MacTahoe-Dark/gtk-3.0/gtk.css

### Install the paired GNOME wallpapers system-wide.
# GNOME selects filename-dark/picture-uri-dark whenever dark mode is active.
mkdir -p /usr/share/backgrounds /usr/share/gnome-background-properties
./wallpaper/install-gnome-backgrounds.sh
test -f /usr/share/backgrounds/MacTahoe/MacTahoe-day.jpeg
test -f /usr/share/backgrounds/MacTahoe/MacTahoe-night.jpeg
test -f /usr/share/gnome-background-properties/MacTahoe.xml
rm -rf "$REPO_DIR/.git"

### Use the MacTahoe wallpaper for new users while leaving GNOME's GTK and
# Shell themes at their defaults. The installed themes remain selectable.
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/10-mactahoe-theme <<'EOF'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/MacTahoe/MacTahoe-day.jpeg'
picture-uri-dark='file:///usr/share/backgrounds/MacTahoe/MacTahoe-night.jpeg'
picture-options='zoom'
EOF
dconf update

### Install per-user desktop and Firefox setup (runs silently at graphical session)
install -Dm755 /ctx/mactahoe/mactahoe-firefox-setup.sh \
    /usr/libexec/mactahoe-firefox-setup.sh

install -Dm644 /ctx/mactahoe/mactahoe-firefox-setup.service \
    /usr/lib/systemd/user/mactahoe-firefox-setup.service

mkdir -p /usr/lib/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/mactahoe-firefox-setup.service \
       /usr/lib/systemd/user/graphical-session.target.wants/mactahoe-firefox-setup.service
