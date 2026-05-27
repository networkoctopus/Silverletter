#!/bin/bash
set -ouex pipefail

### ── uupd (ublue automatic updates) ──
systemctl enable uupd.timer
echo "ublue automatic updates enabled"

### ── Disable rpm-ostree automatic updates ──
# uupd handles updates; rpm-ostreed-automatic would conflict
sed -i 's/^AutomaticUpdatePolicy=.*/AutomaticUpdatePolicy=none/' /etc/rpm-ostreed.conf
systemctl disable rpm-ostreed-automatic.timer
echo "rpm-ostree automatic updates disabled"

### ── GNOME Software / PackageKit ──
# Prevent gnome-software from trying to update packages and failing
# Updates handled with uupd
rm -f /usr/lib64/gnome-software/plugins-*/libgs_plugin_dnf5.so
systemctl mask packagekit
echo "gnome-software dnf5 plugin removed"
