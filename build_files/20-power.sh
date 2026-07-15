#!/bin/bash
set -ouex pipefail

### ── Kernel arguments ──
# Tell firmware this is not macOS (creates Linux-accessible AHCI paths).
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

install -Dm644 /ctx/power/linuxbook-air-thunderbolt-powerdown.service \
    /usr/lib/systemd/system/linuxbook-air-thunderbolt-powerdown.service
systemctl enable linuxbook-air-thunderbolt-powerdown.service

# These are supplied by the Fedora base image. Fail the image build if a future
# base change removes a dependency used by the always-disabled power-down path.
for runtime_cmd in flock logger lsmod modprobe udevadm; do
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
