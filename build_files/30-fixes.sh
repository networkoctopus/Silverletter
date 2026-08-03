#!/bin/bash
set -ouex pipefail

# Works around a kernel regression causing slow resume
# by offlining non-boot CPUs before sleep and onlining after wake
#source https://forums.linuxmint.com/viewtopic.php?t=456323
install -Dm755 /ctx/fixes/fix-macbook-wakeup \
    /usr/lib/systemd/system-sleep/fix-macbook-wakeup

### Use iwd as NetworkManager's WiFi backend, with broadcom-wl tuning
dnf5 install -y iwd
install -Dm644 /ctx/fixes/10-wifi-backend.conf \
    /usr/lib/NetworkManager/conf.d/10-wifi-backend.conf
install -Dm644 /ctx/fixes/main.conf \
    /usr/lib/iwd/main.conf
install -Dm644 /ctx/fixes/10-silverletter-config.conf \
    /usr/lib/systemd/system/iwd.service.d/10-silverletter-config.conf

### Broadcom wl WiFi interface reset on suspend/resume
#install -Dm644 /ctx/fixes/wl-suspend.service /usr/lib/systemd/system/wl-suspend.service
#install -Dm755 /ctx/fixes/wl-suspend.sh /usr/bin/wl-suspend.sh
#systemctl enable wl-suspend.service

# Disable d3cold for the SATA controller to fix resume hang on MacBookAir7,1
# Ref: https://github.com/Dunedan/mbp-2016-linux/issues/37#issuecomment-540202102
install -Dm755 /ctx/fixes/fix-sleep.sh \
    /usr/lib/systemd/scripts/fix-sleep.sh

install -Dm644 /ctx/fixes/fix-sleep.service \
    /usr/lib/systemd/system/fix-sleep.service

systemctl enable fix-sleep.service
