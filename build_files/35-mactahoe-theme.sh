#!/bin/bash
set -ouex pipefail

### Clone MacTahoe GTK theme
REPO_DIR="/usr/share/MacTahoe-gtk-theme"
git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git "$REPO_DIR"

### Install default GTK theme system-wide
cd "$REPO_DIR"
./install.sh -d /usr/share/themes

### Install Firefox first-login setup (user-profile-specific, runs silently at graphical session)
install -Dm755 /ctx/mactahoe/mactahoe-firefox-setup.sh \
    /usr/libexec/mactahoe-firefox-setup.sh

install -Dm644 /ctx/mactahoe/mactahoe-firefox-setup.service \
    /usr/lib/systemd/user/mactahoe-firefox-setup.service

mkdir -p /usr/lib/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/mactahoe-firefox-setup.service \
       /usr/lib/systemd/user/graphical-session.target.wants/mactahoe-firefox-setup.service
