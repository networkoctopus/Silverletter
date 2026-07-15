#!/bin/bash
set -ouex pipefail

### ── Thunderbolt hot-plug kernel argument ──
install -Dm644 /ctx/thunderbolt-extension/linuxbook-air-thunderbolt.toml \
    /usr/lib/bootc/kargs.d/linuxbook-air-thunderbolt.toml

### ── Automatic hotplug control and suspend safety ──
install -Dm755 /ctx/thunderbolt-extension/linuxbook-air-thunderbolt-control \
    /usr/libexec/linuxbook-air-thunderbolt-control

install -Dm644 /ctx/thunderbolt-extension/linuxbook-air-thunderbolt-sleep.service \
    /usr/lib/systemd/system/linuxbook-air-thunderbolt-sleep.service
install -Dm644 /ctx/thunderbolt-extension/linuxbook-air-thunderbolt-hotplug.service \
    /usr/lib/systemd/system/linuxbook-air-thunderbolt-hotplug.service
install -Dm644 /ctx/thunderbolt-extension/linuxbook-air-thunderbolt.conf \
    /usr/lib/tmpfiles.d/linuxbook-air-thunderbolt.conf
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
