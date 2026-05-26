#!/bin/bash
set -ouex pipefail

### ── Toshy first-login setup ──
# Toshy is per-user by design; these scripts handle first-login
# installation of the Python venv and user systemd units

install -Dm755 /ctx/toshy/toshy-first-login-setup.sh \
    /usr/libexec/toshy-first-login-setup.sh

install -Dm755 /ctx/toshy/toshy-first-login-launch.sh \
    /usr/libexec/toshy-first-login-launch.sh

install -Dm644 /ctx/toshy/toshy-first-login-setup.service \
    /usr/lib/systemd/user/toshy-first-login-setup.service

# Enable for all users via systemd user preset / wants symlink
mkdir -p /usr/lib/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/toshy-first-login-setup.service \
       /usr/lib/systemd/user/graphical-session.target.wants/toshy-first-login-setup.service
