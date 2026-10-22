#!/bin/bash
set -ouex pipefail

# Works around a kernel regression causing slow resume
# by offlining non-boot CPUs before sleep and onlining after wake
#source https://forums.linuxmint.com/viewtopic.php?t=456323
install -Dm755 /ctx/fixes/fix-macbook-wakeup \
    /usr/lib/systemd/system-sleep/fix-macbook-wakeup

# Apply model-specific storage D3cold workarounds for reliable resume.
install -Dm755 /ctx/fixes/fix-sleep.sh \
  /usr/lib/systemd/scripts/fix-sleep.sh

install -Dm644 /ctx/fixes/fix-sleep.service \
  /usr/lib/systemd/system/fix-sleep.service

systemctl enable fix-sleep.service
