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
# Prevent gnome-software from doing background updates
# Updates handled by uupd; UI still works for manual use
rm -f /usr/lib64/gnome-software/plugins-*/libgs_plugin_dnf5.so
systemctl mask packagekit
echo "gnome-software dnf5 plugin removed, packagekit masked"

### ── Disable gnome-software background updates via dconf (system-wide) ──
mkdir -p /etc/dconf/db/local.d /etc/dconf/db/local.d/locks
cat > /etc/dconf/db/local.d/01-gnome-software << 'EOF'
[org/gnome/software]
allow-updates=false
download-updates=false
EOF
cat > /etc/dconf/db/local.d/locks/gnome-software << 'EOF'
/org/gnome/software/allow-updates
/org/gnome/software/download-updates
EOF
dconf update
echo "gnome-software dconf policy applied and locked"