#!/bin/bash
set -ouex pipefail

### ── Kernel arguments ──
# Tell firmware this is not macOS and reserve buses for Thunderbolt hot-plug.
install -Dm644 /ctx/power/linuxbook-air.toml \
    /usr/lib/bootc/kargs.d/linuxbook-air.toml

### ── Kernel module config ──
# Disable Thunderbolt driver (reduces power draw on MacBook Air 7,1)
# source: https://wiki.archlinux.org/title/Mac/Troubleshooting
install -Dm644 /ctx/power/thunderbolt-blacklist.conf \
    /usr/lib/modprobe.d/thunderbolt-blacklist.conf

### ── udev rules ──
# Enable runtime PM for Thunderbolt PCIe devices
# source: https://wiki.archlinux.org/title/Mac/Troubleshooting
install -Dm644 /ctx/power/99-thunderbolt-pm.rules \
    /usr/lib/udev/rules.d/99-thunderbolt-pm.rules

install -Dm755 /ctx/power/tb-powerdown.sh /usr/libexec/tb-powerdown.sh

# Privileged backend used by the GNOME Shell Thunderbolt indicator
install -Dm755 /ctx/thunderbolt-extension/linuxbook-air-thunderbolt-control \
    /usr/libexec/linuxbook-air-thunderbolt-control

install -Dm644 /ctx/thunderbolt-extension/io.github.networkoctopus.linuxbookair.thunderbolt.policy \
    /usr/share/polkit-1/actions/io.github.networkoctopus.linuxbookair.thunderbolt.policy

# Install and enable the LinuxBook-Air-specific GNOME Shell indicator. Keep
# this out of 15-packages.sh because that shared stage is also used by Asahi.
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

# These are supplied by the Fedora GNOME base image. Fail the image build if a
# future base change removes a runtime dependency used by the control path.
for runtime_cmd in flock logger lsmod modprobe pkexec udevadm; do
    command -v "$runtime_cmd" >/dev/null
done

### ── NetworkManager ──
# Enable WiFi powersave by default
install -Dm644 /ctx/power/default-wifi-powersave-on.conf \
    /usr/lib/NetworkManager/conf.d/default-wifi-powersave-on.conf

### ── powertop autotune ──
# Fedora powertop package includes the service file; just enable it
systemctl enable powertop.service

### ── ASPM tuning ──
# Force stubborn devices to enable ASPM on boot which allows higher package states
# source: https://www.reddit.com/r/linux_on_mac/comments/1hl5mac/comment/m99qo53/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button
install -Dm755 /ctx/power/aspm-tune.sh /usr/bin/aspm-tune.sh

install -Dm644 /ctx/power/aspm-tune.service \
    /usr/lib/systemd/system/aspm-tune.service
systemctl enable aspm-tune.service

### ── Power audit script (manual troubleshooting tool) ──
install -Dm755 /ctx/power/power-audit.sh /usr/bin/power-audit.sh
