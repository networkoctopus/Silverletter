#!/bin/bash
set -ouex pipefail

### ── Per-user first-login setup ──
# Waits for GNOME Initial Setup to finish, then installs Toshy, applies the
# Firefox styling, and restores the standard GNOME Flatpaks.

DEFAULT_FLATPAKS_FILE=/usr/share/silverletter/default-flatpaks.txt
install -Dm644 /ctx/post-deploy-setup/default-flatpaks.txt \
    "$DEFAULT_FLATPAKS_FILE"

# Prefer the default Silverblue application list for the Fedora release used
# by this image. The checked-in list above remains in place if Fedora's source
# is unavailable or its format changes. FEDORA_VERSION comes from the base
# image tag selected in the Containerfile.
FEDORA_BRANCH="f${FEDORA_VERSION:?FEDORA_VERSION missing from Containerfile}"
FEDORA_ARCH=$(rpm --eval '%{_arch}')
PUNGI_URL="https://forge.fedoraproject.org/releng/pungi-fedora/raw/branch/${FEDORA_BRANCH}/fedora.conf"
PUNGI_CONF=$(mktemp)
GENERATED_FLATPAKS=$(mktemp)

if curl --fail --location --retry 3 --output "$PUNGI_CONF" "$PUNGI_URL" && \
    grep -m1 \
        "flatpak_remote_refs=.*Platform/${FEDORA_ARCH}/f${FEDORA_VERSION}.*app/org.gnome.baobab/${FEDORA_ARCH}/stable" \
        "$PUNGI_CONF" | \
        grep -oE 'app/[^/[:space:]"]+/[^/[:space:]"]+/stable' | \
        cut -d/ -f2 > "$GENERATED_FLATPAKS"; then
    GENERATED_COUNT=$(wc -l < "$GENERATED_FLATPAKS")
    if (( GENERATED_COUNT >= 15 && GENERATED_COUNT <= 30 )) && \
        grep -qx 'org.gnome.Calculator' "$GENERATED_FLATPAKS" && \
        grep -qx 'org.gnome.baobab' "$GENERATED_FLATPAKS"; then
        install -Dm644 "$GENERATED_FLATPAKS" "$DEFAULT_FLATPAKS_FILE"
        echo "installed $GENERATED_COUNT default Flatpak IDs from Fedora ${FEDORA_VERSION}"
    else
        echo "Fedora default Flatpak list failed validation; using fallback"
    fi
else
    echo "Fedora default Flatpak list could not be retrieved; using fallback"
fi
rm -f "$PUNGI_CONF" "$GENERATED_FLATPAKS"

install -Dm755 /ctx/post-deploy-setup/post-deploy-setup.sh \
    /usr/libexec/silverletter-post-deploy-setup.sh

install -Dm755 /ctx/post-deploy-setup/post-deploy-setup-launch.sh \
    /usr/libexec/silverletter-post-deploy-setup-launch.sh

install -Dm755 /ctx/post-deploy-setup/silverletter-setup-app.py \
    /usr/libexec/silverletter-setup-app.py

install -Dm644 /ctx/post-deploy-setup/post-deploy-setup.service \
    /usr/lib/systemd/user/silverletter-post-deploy-setup.service

install -Dm644 /ctx/post-deploy-setup/silverletter-setup.desktop \
    /usr/share/applications/io.github.networkoctopus.SilverletterSetup.desktop

install -Dm644 /ctx/post-deploy-setup/silverletter-setup.svg \
    /usr/share/icons/hicolor/scalable/apps/silverletter-setup.svg
gtk-update-icon-cache -f /usr/share/icons/hicolor

# Enable for all users via systemd user preset / wants symlink
mkdir -p /usr/lib/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/silverletter-post-deploy-setup.service \
       /usr/lib/systemd/user/graphical-session.target.wants/silverletter-post-deploy-setup.service
