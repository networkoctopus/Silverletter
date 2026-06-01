#!/usr/bin/bash
set -eoux pipefail

cat > /usr/lib/dracut/dracut.conf.d/99-linuxbook-air.conf << 'EOF'
# LinuxBook-Air: trim initramfs for MacBook Air 7,1 hardware
omit_drivers+=" amdgpu radeon nouveau nvidia xe "
omit_dracutmodules+=" nss-softokn fido2 pkcs11 pcsc tpm2-tss systemd-pcrphase btrfs lvm mdraid nvdimm qemu virtiofs "
force_drivers+=" wl "
compress="zstd"
compress_level_zstd="3"
remove_items+=" /usr/lib/firmware/i915 /usr/lib/firmware/xe /usr/lib/firmware/intel/ish /usr/lib/firmware/intel/qat /usr/lib/firmware/dell /usr/lib/firmware/HP /usr/lib/firmware/LENOVO /usr/lib/firmware/mediatek /usr/lib/firmware/advansys /usr/lib/firmware/cavium /usr/lib/firmware/cxgb4 /usr/lib/firmware/isci /usr/lib/firmware/qlogic /usr/lib/firmware/ene-ub6250 /usr/lib/firmware/cis /usr/lib/firmware/cbfw-3.2.5.1.bin /usr/lib/firmware/ct2fw-3.2.5.1.bin /usr/lib/firmware/ctfw-3.2.5.1.bin /usr/lib/firmware/ql2100_fw.bin /usr/lib/firmware/ql2200_fw.bin /usr/lib/firmware/ql2300_fw.bin /usr/lib/firmware/ql2322_fw.bin /usr/lib/firmware/ql2400_fw.bin /usr/lib/firmware/ql2500_fw.bin "
EOF

KERNEL_VERSION="$(rpm -q --queryformat="%{evr}.%{arch}" kernel-core)"

export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "${KERNEL_VERSION}" --reproducible -v --add ostree -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"