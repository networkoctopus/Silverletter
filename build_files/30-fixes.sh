#!/bin/bash
set -ouex pipefail

### ── Sleep hooks ──

# Restore Intel backlight brightness after S3 resume
# (intel_backlight driver may leave brightness at 0 after wake)
install -Dm755 /ctx/fixes/restore-backlight.sh \
    /usr/lib/systemd/system-sleep/restore-backlight.sh

# Speed up display pipeline resume on MacBook Air 7,1
# Works around a kernel regression causing slow/dark display after S3
# by offlining non-boot CPUs before sleep and onlining after wake
install -Dm755 /ctx/fixes/fix-macbook-wakeup \
    /usr/lib/systemd/system-sleep/fix-macbook-wakeup

