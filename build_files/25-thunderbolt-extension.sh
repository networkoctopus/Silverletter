#!/bin/bash
set -ouex pipefail

### ── Thunderbolt hot-plug kernel argument ──
install -Dm644 /ctx/thunderbolt-extension/silverletter-thunderbolt.toml \
    /usr/lib/bootc/kargs.d/silverletter-thunderbolt.toml

### ── Automatic hotplug control and suspend safety ──
install -Dm755 /ctx/thunderbolt-extension/silverletter-thunderbolt-control \
    /usr/libexec/silverletter-thunderbolt-control
install -Dm755 /ctx/thunderbolt-extension/silverletter-thunderbolt-debug \
    /usr/bin/silverletter-thunderbolt-debug

install -Dm644 /ctx/thunderbolt-extension/silverletter-thunderbolt-sleep.service \
    /usr/lib/systemd/system/silverletter-thunderbolt-sleep.service
install -Dm644 /ctx/thunderbolt-extension/silverletter-thunderbolt-hotplug.service \
    /usr/lib/systemd/system/silverletter-thunderbolt-hotplug.service
install -Dm644 /ctx/thunderbolt-extension/silverletter-thunderbolt-disconnect.service \
    /usr/lib/systemd/system/silverletter-thunderbolt-disconnect.service
install -Dm644 /ctx/thunderbolt-extension/silverletter-thunderbolt-disconnect.path \
    /usr/lib/systemd/system/silverletter-thunderbolt-disconnect.path
install -Dm644 /ctx/thunderbolt-extension/silverletter-thunderbolt.conf \
    /usr/lib/tmpfiles.d/silverletter-thunderbolt.conf
systemctl enable silverletter-thunderbolt-sleep.service
systemctl enable silverletter-thunderbolt-disconnect.path

### ── GNOME Shell indicator ──
THUNDERBOLT_UUID="thunderbolt@silverletter.local"
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
