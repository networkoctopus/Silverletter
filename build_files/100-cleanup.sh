#!/bin/bash
set -ouex pipefail

### ── DNF cleanup ──
dnf5 autoremove -y
rm -rf \
    /run/dnf \
    /var/cache/libdnf5

truncate -s 0 /var/log/dnf5.log

### ── General cache / tmp cleanup ──
rm -rf \
    /var/cache/* \
    /var/lib/dnf/repos/* \
    /var/lib/flatpak/repo/* \
    /run/dnf/* \
    /tmp/* \
    /var/tmp/*

rm -f \
    /var/cache/ldconfig/aux-cache \
    /var/lib/dnf/system-repo.lock \
    /var/lib/flatpak/.changed

### ── Log truncation ──
find /var/log -type f -exec truncate -s 0 {} \;
