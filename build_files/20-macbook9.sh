#!/bin/bash
set -ouex pipefail

[[ "${SILVERLETTER_HARDWARE_PROFILE:-}" == "macbook9" ]]

# The BCM4350 is supported by the in-tree brcmfmac driver and Fedora's
# brcmfmac-firmware package. Do not install broadcom-wl or its blacklist.
rpm -q brcmfmac-firmware
install -Dm644 /ctx/power/default-wifi-powersave-on.conf \
    /usr/lib/NetworkManager/conf.d/default-wifi-powersave-on.conf

# Be defensive if a future base image acquires any similarly named files.
rm -f \
    /usr/lib/bootc/kargs.d/silverletter.toml \
    /usr/lib/bootc/kargs.d/silverletter-thunderbolt.toml \
    /usr/lib/modprobe.d/thunderbolt-blacklist.conf \
    /usr/lib/udev/rules.d/99-thunderbolt-pm.rules
