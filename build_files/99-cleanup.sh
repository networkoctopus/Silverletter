#!/bin/bash
set -ouex pipefail

# Disable ublue-os repo
dnf5 -y copr disable ublue-os/packages

### ── Disable leftover third-party repos ──
for repo in negativo17-fedora-multimedia fedora-cisco-openh264; do
    if [[ -f "/etc/yum.repos.d/${repo}.repo" ]]; then
        sed -i 's@enabled=1@enabled=0@g' "/etc/yum.repos.d/${repo}.repo"
    fi
done

# Disable any remaining COPR repos
for i in /etc/yum.repos.d/_copr:*.repo; do
    [[ -f "$i" ]] && sed -i 's@enabled=1@enabled=0@g' "$i"
done

# Disable ublue-os akmods COPR if present
if [[ -f "/etc/yum.repos.d/_copr_ublue-os-akmods.repo" ]]; then
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_ublue-os-akmods.repo
fi

# Disable RPM Fusion repos
for i in /etc/yum.repos.d/rpmfusion-*.repo; do
    [[ -f "$i" ]] && sed -i 's@enabled=1@enabled=0@g' "$i"
done

# Disable fedora-coreos-pool if present
if [[ -f /etc/yum.repos.d/fedora-coreos-pool.repo ]]; then
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-coreos-pool.repo
fi

### Clean up packages
dnf5 autoremove -y

# Remove tmp files and everything in dirs that make bootc unhappy
rm -rf /tmp/* || true
rm -rf /run/dnf
rm -rf /usr/etc
rm -rf /boot && mkdir /boot
# Preserve cache mounts
find /var/* -maxdepth 0 -type d \! -name cache \! -name log -exec rm -rf {} \;
find /var/cache/* -maxdepth 0 -type d \! -name libdnf5 -exec rm -rf {} \;

# Make sure /var/tmp is properly created
mkdir -p /var/tmp
chmod -R 1777 /var/tmp
