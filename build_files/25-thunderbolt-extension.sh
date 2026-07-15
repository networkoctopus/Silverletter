#!/bin/bash
set -ouex pipefail

### ── Thunderbolt hot-plug kernel argument ──
install -Dm644 /ctx/thunderbolt-extension/linuxbook-air-thunderbolt.toml \
    /usr/lib/bootc/kargs.d/linuxbook-air-thunderbolt.toml

### ── Privileged control and suspend safety ──
install -Dm755 /ctx/thunderbolt-extension/linuxbook-air-thunderbolt-control \
    /usr/libexec/linuxbook-air-thunderbolt-control

install -Dm644 /ctx/thunderbolt-extension/io.github.networkoctopus.linuxbookair.thunderbolt.policy \
    /usr/share/polkit-1/actions/io.github.networkoctopus.linuxbookair.thunderbolt.policy

install -Dm644 /ctx/thunderbolt-extension/linuxbook-air-thunderbolt-sleep.service \
    /usr/lib/systemd/system/linuxbook-air-thunderbolt-sleep.service
systemctl enable linuxbook-air-thunderbolt-sleep.service

### ── GNOME Shell indicator ──
THUNDERBOLT_UUID="thunderbolt@linuxbook-air.local"
THUNDERBOLT_EXTENSION_DIR="/usr/share/gnome-shell/extensions/${THUNDERBOLT_UUID}"
install -d -m 0755 "$THUNDERBOLT_EXTENSION_DIR"
cp -a /ctx/thunderbolt-extension/extension/. "$THUNDERBOLT_EXTENSION_DIR/"
chmod -R a+rX "$THUNDERBOLT_EXTENSION_DIR"

EXTENSIONS_DCONF="/etc/dconf/db/local.d/00-extensions"
if ! grep -Fq "'${THUNDERBOLT_UUID}'" "$EXTENSIONS_DCONF"; then
    sed -i \
        "/^enabled-extensions=/ s/]$/, '${THUNDERBOLT_UUID}']/" \
        "$EXTENSIONS_DCONF"
fi
grep -Fq "'${THUNDERBOLT_UUID}'" "$EXTENSIONS_DCONF"
dconf update

# Supplied by the Fedora GNOME base image. Fail the build if a future base
# change removes a runtime dependency needed by this optional feature.
command -v pkexec >/dev/null
