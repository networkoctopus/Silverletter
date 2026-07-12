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
test -f /usr/share/themes/MacTahoe-Light/gnome-shell/gnome-shell.css
test -f /usr/share/themes/MacTahoe-Dark/gnome-shell/gnome-shell.css

### Install the companion icon and cursor themes system-wide.
ICON_REPO_DIR="/tmp/MacTahoe-icon-theme"
git clone --depth=1 https://github.com/vinceliuice/MacTahoe-icon-theme.git \
    "$ICON_REPO_DIR"
mkdir -p /usr/share/icons
"$ICON_REPO_DIR/install.sh" -d /usr/share/icons

# Verify the default, light, and dark entries are visible to theme selectors.
for variant in MacTahoe MacTahoe-light MacTahoe-dark; do
    test -f "/usr/share/icons/$variant/index.theme"
    test -e "/usr/share/icons/$variant/cursors/default"
done
rm -rf "$ICON_REPO_DIR"

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

### Fix Fedora's Firefox homepage default.
# Firefox 152 renders the legacy data:text/plain preference literally instead
# of extracting the intended Fedora start-page URL (RHBZ #2490879).
FIREFOX_DEFAULT_PREFS="/usr/lib64/firefox/browser/defaults/preferences/firefox-redhat-default-prefs.js"
if [[ -f "$FIREFOX_DEFAULT_PREFS" ]]; then
    sed -i \
        's#data:text/plain,browser\.startup\.homepage=https://start\.fedoraproject\.org/#https://start.fedoraproject.org/#g' \
        "$FIREFOX_DEFAULT_PREFS"
fi
