#!/usr/bin/bash
set -eoux pipefail

cat > /usr/lib/dracut/dracut.conf.d/99-linuxbook-air.conf << 'EOF'
# LinuxBook-Air: trim initramfs for MacBook Air 7,1 hardware
# Exclude irrelevant GPU firmware (no Nvidia, no AMD)
omit_drivers+=" amdgpu radeon nouveau nvidia "
# Exclude irrelevant dracut modules
omit_dracutmodules+=" nss-softokn fido2 pkcs11 pcsc tpm2-tss systemd-pcrphase "
# Include wl for early wifi
force_drivers+=" wl lib80211_crypt_tkip "
EOF

KERNEL_VERSION="$(rpm -q --queryformat="%{evr}.%{arch}" kernel-core)"

export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "${KERNEL_VERSION}" --reproducible -v --add ostree -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"