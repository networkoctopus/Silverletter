#!/bin/bash
set -ouex pipefail

### Install packages

# Enable RPMFusion free and nonfree repos
# (not pre-enabled on vanilla Fedora Silverblue unlike Bluefin)
#dnf5 install -y \
#    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
#    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

# Install some useful tools for debugging and profiling gpu and power usage
dnf5 install -y intel-gpu-tools powertop

# Install Toshy native dependencies
dnf5 install -y --skip-unavailable \
    cairo-devel \
    cairo-gobject-devel \
    dbus \
    dbus-devel \
    evtest \
    gcc \
    git \
    gobject-introspection-devel \
    libappindicator-gtk3 \
    libinput-utils \
    libjpeg-turbo-devel \
    libnotify \
    libxkbcommon-devel \
    python3-dbus \
    python3-devel \
    python3-pip \
    python3-tkinter \
    systemd-devel \
    wayland-devel \
    xorg-x11-utils \
    zenity

#cleanup
dnf5 autoremove -y && \
rm -rf /run/dnf

# Install Toshy native dependencies - extracted dynamically from upstream source
#TOSHY_TMP=$(mktemp -d)
#git clone --depth=1 https://github.com/RedBearAK/Toshy.git "$TOSHY_TMP/toshy"
#
#TOSHY_PKGS=$(python3 -c "
#import ast, re, sys
#
#with open('$TOSHY_TMP/toshy/setup_toshy.py') as f:
#    content = f.read()
#
#match = re.search(r'pkg_groups_map\s*=\s*(\{.*?\n\})', content, re.DOTALL)
#if not match:
#    print('ERROR: Could not find pkg_groups_map', file=sys.stderr)
#    sys.exit(1)
#
#pkg_groups_map = ast.literal_eval(match.group(1))
#pkgs = pkg_groups_map.get('fedora-based')
#if not pkgs:
#    print('ERROR: Could not find fedora-based key', file=sys.stderr)
#    sys.exit(1)
#
#print(' '.join(pkgs))
#")
#
#if [[ -z "$TOSHY_PKGS" ]]; then
#    echo "ERROR: Failed to extract Toshy package list from upstream source" >&2
#    exit 1
#fi
#
#echo "Installing Toshy deps: $TOSHY_PKGS"
#dnf5 install -y --skip-unavailable $TOSHY_PKGS
#
#rm -rf "$TOSHY_TMP"

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File
systemctl enable podman.socket
