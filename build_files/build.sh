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
# Enable powertop --autotune on startup
RUN systemctl enable powertop.service

# Install Toshy native dependencies
dnf5 install -y --skip-unavailable \
    cairo-devel \
    cairo-gobject-devel \
    dbus \
    dbus-devel \
    dbus-daemon \
    dbus-tools \
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

# Install theme native dependencies
dnf5 install -y gnome-tweaks sassc glib2-devel

### Install GNOME Shell extensions system-wide
GNOME_VERSION=$(rpm -q --queryformat '%{VERSION}' gnome-shell | cut -d. -f1)
EXTENSIONS_DIR="/usr/share/gnome-shell/extensions"
mkdir -p "$EXTENSIONS_DIR"

install_extension() {
    local ext_id="$1"
    local uuid="$2"

    echo "Installing extension $uuid (ID: $ext_id) for GNOME ${GNOME_VERSION}..."

    local version_tag
    version_tag=$(curl -sf "https://extensions.gnome.org/extension-info/?pk=${ext_id}&shell_version=${GNOME_VERSION}" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin)["version_tag"])')

    local tmpdir
    tmpdir=$(mktemp -d)
    curl -sL "https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?version_tag=${version_tag}" \
        -o "$tmpdir/ext.zip"
    unzip -q "$tmpdir/ext.zip" -d "${EXTENSIONS_DIR}/${uuid}"
    rm -rf "$tmpdir"

    echo "Done: $uuid"
}

install_extension 615  "appindicatorsupport@rgcjonas.gmail.com"
install_extension 5060 "xremap@k0kubun.com"
install_extension 1460 "Vitals@CoreCoding.com"
install_extension 19   "user-theme@gnome-shell-extensions.gcampax.github.com"
install_extension 307  "dash-to-dock@micxgx.gmail.com"
# Fix permissions so all users can read extensions
chmod -R a+rX /usr/share/gnome-shell/extensions/

# Compile GSettings schemas for extensions that need it
for schema_dir in /usr/share/gnome-shell/extensions/*/schemas; do
    if ls "$schema_dir"/*.gschema.xml &>/dev/null; then
        echo "Compiling schemas in $schema_dir"
        glib-compile-schemas "$schema_dir"
    fi
done

### Enable extensions system-wide via dconf
mkdir -p /etc/dconf/profile /etc/dconf/db/local.d
printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
cat > /etc/dconf/db/local.d/00-extensions << 'EOF'
[org/gnome/shell]
enabled-extensions=['appindicatorsupport@rgcjonas.gmail.com', 'xremap@k0kubun.com', 'Vitals@CoreCoding.com', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'dash-to-dock@micxgx.gmail.com']
disable-user-extensions=false
EOF
dconf update

#cleanup
#dnf5 autoremove -y && \
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
