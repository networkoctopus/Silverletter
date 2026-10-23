#!/bin/bash
set -eoux pipefail

profile="${SILVERLETTER_HARDWARE_PROFILE:?hardware profile is required}"
kernel_version="$(rpm -q --queryformat='%{evr}.%{arch}' kernel-core)"
initramfs="/lib/modules/${kernel_version}/initramfs.img"

test -x /usr/libexec/silverletter-model
test -s "$initramfs"
test -x /usr/lib/systemd/scripts/fix-sleep.sh
systemctl is-enabled --quiet fix-sleep.service

case "$profile" in
    macbookair7)
        test -z "$(modinfo -k "$kernel_version" -F silverletter_bt_fix bluetooth)"
        rpm -q broadcom-wl
        test -f /usr/lib/modprobe.d/broadcom-wl-blacklist.conf
        test -f /usr/lib/bootc/kargs.d/silverletter.toml
        test -f /usr/lib/bootc/kargs.d/silverletter-thunderbolt.toml
        test -x /usr/libexec/tb-powerdown.sh
        systemctl is-enabled --quiet mbpfan.service
        ;;
    macbook9)
        ! rpm -q broadcom-wl
        test ! -e /usr/lib/modprobe.d/broadcom-wl-blacklist.conf
        test ! -e /usr/lib/bootc/kargs.d/silverletter.toml
        test ! -e /usr/lib/bootc/kargs.d/silverletter-thunderbolt.toml
        test ! -e /usr/lib/modprobe.d/thunderbolt-blacklist.conf
        test ! -e /usr/lib/udev/rules.d/99-thunderbolt-pm.rules
        test ! -e /usr/libexec/tb-powerdown.sh
        test ! -e /usr/libexec/silverletter-thunderbolt-control
        test ! -e /usr/share/gnome-shell/extensions/thunderbolt@silverletter.local
        test ! -e /usr/lib/systemd/system/mbpfan.service

        compgen -G "/lib/modules/${kernel_version}/kernel/drivers/input/keyboard/applespi.ko*"
        compgen -G "/lib/modules/${kernel_version}/kernel/drivers/spi/spi-pxa2xx-platform.ko*"
        compgen -G "/lib/modules/${kernel_version}/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac/brcmfmac.ko*"
        compgen -G "/lib/modules/${kernel_version}/kernel/drivers/net/wireless/broadcom/brcm80211/brcmfmac/wcc/brcmfmac-wcc.ko*"
        compgen -G '/usr/lib/firmware/brcm/brcmfmac4350c2-pcie.bin*'
        test "$(modinfo -k "$kernel_version" -n snd_hda_codec_cs420x)" = \
            "/lib/modules/${kernel_version}/updates/snd-hda-codec-cs420x.ko"
        test -f /usr/share/wireplumber/wireplumber.conf.d/51-macbook-cs4208-softvol.conf
        test "$(modinfo -k "$kernel_version" -n bluetooth)" = \
            "/lib/modules/${kernel_version}/updates/bluetooth.ko"
        test "$(modinfo -k "$kernel_version" -F silverletter_bt_fix bluetooth)" = \
            broadcom-legacy-adv-mask-v1

        lsinitrd "$initramfs" > /tmp/silverletter-initramfs-list
        grep -q '/applespi\.ko' /tmp/silverletter-initramfs-list
        grep -q '/spi-pxa2xx-platform\.ko' /tmp/silverletter-initramfs-list
        grep -q '/brcmfmac\.ko' /tmp/silverletter-initramfs-list
        grep -q '/brcmfmac-wcc\.ko' /tmp/silverletter-initramfs-list
        grep -q '/updates/snd-hda-codec-cs420x\.ko' /tmp/silverletter-initramfs-list
        grep -q '/updates/bluetooth\.ko' /tmp/silverletter-initramfs-list
        rm -f /tmp/silverletter-initramfs-list
        ;;
    *)
        echo "Unknown hardware profile: $profile" >&2
        exit 1
        ;;
esac
