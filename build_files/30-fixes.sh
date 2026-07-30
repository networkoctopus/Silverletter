#!/bin/bash
set -ouex pipefail

# Works around a kernel regression causing slow resume
# by offlining non-boot CPUs before sleep and onlining after wake
#source https://forums.linuxmint.com/viewtopic.php?t=456323
install -Dm755 /ctx/fixes/fix-macbook-wakeup \
    /usr/lib/systemd/system-sleep/fix-macbook-wakeup

### Broadcom wl WiFi interface reset on suspend/resume
install -Dm644 /ctx/fixes/wl-suspend.service /usr/lib/systemd/system/wl-suspend.service
install -Dm755 /ctx/fixes/wl-suspend.sh /usr/bin/wl-suspend.sh
systemctl enable wl-suspend.service


