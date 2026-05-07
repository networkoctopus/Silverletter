#!/bin/bash
set -ouex pipefail

### Install packages

# Enable RPMFusion free and nonfree repos
# (not pre-enabled on vanilla Fedora Silverblue unlike Bluefin)
dnf5 install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# Install FaceTime HD camera driver (MacBook)
# facetimehd-kmod is a plain pre-built kmod RPM, not an akmod,
# so it installs cleanly as root without triggering any build scriptlets
#dnf5 -y copr enable mulderje/facetimehd-kmod
#dnf5 install -y facetimehd-kmod
#dnf5 -y copr disable mulderje/facetimehd-kmod

# this installs a package from fedora repos
dnf5 install -y tmux

# Install Toshy native dependencies ahead of the installer run
# (mirroring what setup_toshy.py would install for Fedora)
dnf5 install -y \
    cairo-devel \
    dbus-devel \
    dbus-python \
    evdev-utils \
    gcc \
    git \
    gobject-introspection-devel \
    inotify-tools \
    libappindicator-gtk3 \
    libnotify \
    python3-dbus \
    python3-devel \
    python3-pip \
    python3-tk \
    python3-venv \
    zenity

# Install Toshy (Mac-like keyboard shortcuts keymapper)
# --override-distro fedora: forces plain Fedora/dnf mode, avoiding rpm-ostree detection
# --skip-native: native deps already installed above
# User-space components (systemd user services, tray icon) are per-user and must
# be finalised at first login by running: toshy-systemd-setup
TOSHY_TMP=$(mktemp -d)
git clone --depth=1 https://github.com/RedBearAK/Toshy.git "$TOSHY_TMP/toshy"
cd "$TOSHY_TMP/toshy"
python3 ./setup_toshy.py install \
    --override-distro fedora \
    --skip-native
cd /
rm -rf "$TOSHY_TMP"

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File
systemctl enable podman.socket
