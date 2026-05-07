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

# Install Toshy native dependencies - extracted dynamically from upstream source
TOSHY_TMP=$(mktemp -d)
git clone --depth=1 https://github.com/RedBearAK/Toshy.git "$TOSHY_TMP/toshy"

TOSHY_PKGS=$(python3 -c "
import ast, re, sys

with open('$TOSHY_TMP/toshy/setup_toshy.py') as f:
    content = f.read()

match = re.search(r'pkg_groups_map\s*=\s*(\{.*?\n\})', content, re.DOTALL)
if not match:
    print('ERROR: Could not find pkg_groups_map', file=sys.stderr)
    sys.exit(1)

pkg_groups_map = ast.literal_eval(match.group(1))
pkgs = pkg_groups_map.get('fedora-based')
if not pkgs:
    print('ERROR: Could not find fedora-based key', file=sys.stderr)
    sys.exit(1)

print(' '.join(pkgs))
")

if [[ -z "$TOSHY_PKGS" ]]; then
    echo "ERROR: Failed to extract Toshy package list from upstream source" >&2
    exit 1
fi

echo "Installing Toshy deps: $TOSHY_PKGS"
dnf5 install -y --skip-unavailable $TOSHY_PKGS

rm -rf "$TOSHY_TMP"

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File
systemctl enable podman.socket
