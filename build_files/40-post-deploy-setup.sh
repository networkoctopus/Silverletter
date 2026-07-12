#!/bin/bash
set -ouex pipefail

### ── Per-user first-login setup ──
# Waits for GNOME Initial Setup to finish, then installs Toshy, applies the
# Firefox styling, and restores the standard GNOME Flatpaks.

install -Dm755 /ctx/post-deploy-setup/post-deploy-setup.sh \
    /usr/libexec/linuxbook-air-post-deploy-setup.sh

install -Dm755 /ctx/post-deploy-setup/post-deploy-setup-launch.sh \
    /usr/libexec/linuxbook-air-post-deploy-setup-launch.sh

install -Dm644 /ctx/post-deploy-setup/post-deploy-setup.service \
    /usr/lib/systemd/user/linuxbook-air-post-deploy-setup.service

# Enable for all users via systemd user preset / wants symlink
mkdir -p /usr/lib/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/linuxbook-air-post-deploy-setup.service \
       /usr/lib/systemd/user/graphical-session.target.wants/linuxbook-air-post-deploy-setup.service
