#!/bin/bash
set -ouex pipefail

### ── Kernel arguments ──
# Tell firmware this is not macOS (creates Linux-accessible AHCI paths)
install -Dm644 /ctx/power/im-not-macos.toml \
    /usr/lib/bootc/kargs.d/im-not-macos.toml

### ── Kernel module config ──
# Disable Thunderbolt driver (reduces power draw on MacBook Air 7,1)
install -Dm644 /ctx/power/thunderbolt-blacklist.conf \
    /usr/lib/modprobe.d/thunderbolt-blacklist.conf

### ── udev rules ──
# Enable runtime PM for Thunderbolt PCIe devices
install -Dm644 /ctx/power/99-thunderbolt-pm.rules \
    /usr/lib/udev/rules.d/99-thunderbolt-pm.rules

### ── NetworkManager ──
# Enable WiFi powersave by default
install -Dm644 /ctx/power/default-wifi-powersave-on.conf \
    /usr/lib/NetworkManager/conf.d/default-wifi-powersave-on.conf

### ── powertop autotune ──
# Fedora powertop package includes the service file; just enable it
dnf5 install -y powertop intel-gpu-tools
systemctl enable powertop.service

### ── mbpfan (fan control for MacBooks) ──
dnf5 install -y make gcc git
git clone --depth 1 --branch v2.4.0 https://github.com/linux-on-mac/mbpfan.git /tmp/mbpfan
cd /tmp/mbpfan
make
make install
install -Dm644 mbpfan.service /usr/lib/systemd/system/mbpfan.service
systemctl enable mbpfan.service
cd /
rm -rf /tmp/mbpfan

### ── ASPM tuning ──
# Force stubborn devices to enable ASPM on boot and after resume
install -Dm755 /ctx/power/aspm-tune.sh /usr/bin/aspm-tune.sh

install -Dm644 /ctx/power/aspm-tune.service \
    /usr/lib/systemd/system/aspm-tune.service
systemctl enable aspm-tune.service

install -Dm644 /ctx/power/aspm-tune-resume.service \
    /usr/lib/systemd/system/aspm-tune-resume.service
systemctl enable aspm-tune-resume.service

### ── Power audit script (manual troubleshooting tool) ──
install -Dm755 /ctx/power/power-audit.sh /usr/bin/power-audit.sh
