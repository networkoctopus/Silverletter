#!/bin/bash
set -ouex pipefail

### ── Thunderbolt hot-plug kernel argument ──
install -Dm644 /ctx/thunderbolt-extension/silverletter-thunderbolt.toml \
    /usr/lib/bootc/kargs.d/silverletter-thunderbolt.toml

### ── Manual, boot-scoped Thunderbolt enablement ──
install -Dm755 /ctx/thunderbolt-extension/silverletter-thunderbolt-control \
    /usr/libexec/silverletter-thunderbolt-control

install -Dm644 \
    /ctx/thunderbolt-extension/silverletter-thunderbolt-state.conf \
    /usr/lib/tmpfiles.d/silverletter-thunderbolt-state.conf

install -Dm644 \
    /ctx/thunderbolt-extension/silverletter-thunderbolt-teardown.service \
    /usr/lib/systemd/system/silverletter-thunderbolt-teardown.service

install -Dm644 \
    /ctx/thunderbolt-extension/io.github.networkoctopus.silverletter.thunderbolt.policy \
    /usr/share/polkit-1/actions/io.github.networkoctopus.silverletter.thunderbolt.policy

# Do not carry any automatic hotplug activation, disconnect, or debug machinery
# from earlier experimental revisions. The sleep unit only unloads drivers
# before suspend and reloads them after resume; manual disable owns PCI removal.
systemctl disable \
    silverletter-thunderbolt-sleep.service \
    silverletter-thunderbolt-hotplug.service \
    silverletter-thunderbolt-disconnect.path \
    2>/dev/null || true
rm -f \
    /usr/bin/silverletter-thunderbolt-debug \
    /usr/lib/tmpfiles.d/silverletter-thunderbolt.conf \
    /usr/share/polkit-1/actions/io.github.networkoctopus.linuxbookair.thunderbolt.policy \
    /usr/lib/systemd/system/silverletter-thunderbolt-sleep.service \
    /usr/lib/systemd/system/silverletter-thunderbolt-hotplug.service \
    /usr/lib/systemd/system/silverletter-thunderbolt-disconnect.service \
    /usr/lib/systemd/system/silverletter-thunderbolt-disconnect.path

systemctl enable silverletter-thunderbolt-teardown.service

for runtime_cmd in flock logger modprobe pkexec udevadm; do
    command -v "$runtime_cmd" >/dev/null
done

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
