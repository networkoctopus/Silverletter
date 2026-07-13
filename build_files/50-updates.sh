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

### ── Use unfiltered Flathub instead of Fedora Flatpaks ──
# Remove Fedora's filtered Flathub integration, install the official Flathub
# descriptor, and replace Fedora's first-boot Flatpak service. The replacement
# also removes Fedora remotes preserved in /var from an earlier image.
if rpm -q fedora-flathub-remote >/dev/null 2>&1; then
    dnf5 remove -y fedora-flathub-remote
fi

mkdir -p /etc/flatpak/remotes.d
curl --fail --location --retry 3 \
    --output /etc/flatpak/remotes.d/flathub.flatpakrepo \
    https://dl.flathub.org/repo/flathub.flatpakrepo

cat > /usr/lib/systemd/system/flatpak-add-flathub-repos.service <<'EOF'
[Unit]
Description=Add Flathub and remove Fedora Flatpak repositories
ConditionPathExists=!/var/lib/flatpak/.linuxbook-air-flathub-only-initialized
Before=flatpak-system-helper.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/flatpak remote-add --system --if-not-exists flathub /etc/flatpak/remotes.d/flathub.flatpakrepo
ExecStart=-/usr/bin/flatpak remote-delete --system --force fedora
ExecStart=-/usr/bin/flatpak remote-delete --system --force fedora-testing
ExecStartPost=/usr/bin/touch /var/lib/flatpak/.linuxbook-air-flathub-only-initialized

[Install]
WantedBy=multi-user.target
EOF

# Keep Fedora's enabled service name so its existing preset/wants links now run
# the replacement implementation, as Universal Blue does in silverblue-main.
mv -f \
    /usr/lib/systemd/system/flatpak-add-flathub-repos.service \
    /usr/lib/systemd/system/flatpak-add-fedora-repos.service
systemctl enable flatpak-add-fedora-repos.service
echo "unfiltered Flathub enabled; Fedora Flatpak remotes removed"

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
