#!/usr/bin/bash
set -eoux pipefail

mkdir -p /var/roothome

KERNEL_VERSION="$(rpm -q --queryformat="%{evr}.%{arch}" kernel-core)"
KMOD="kernel/drivers"

cat > /usr/lib/dracut/dracut.conf.d/99-linuxbook-air.conf << 'EOF'
# LinuxBook-Air: MacBook Air 7,1 hostonly strict initramfs

# Apple hardware + FaceTime camera drivers
force_drivers+=" applespi spi-pxa2xx-core spi-pxa2xx-platform hid-apple i915 coretemp intel_pmc_bxt iTCO_wdt dw_dmac drm_buddy drm_display_helper ttm wmi video cec mc videobuf2-common videobuf2-dma-sg videobuf2-memops videobuf2-v4l2 videodev i2c-algo-bit i2c-dev uhid uinput hid-logitech-hidpp "
omit_drivers+=" amdgpu radeon nouveau nvidia xe qla2xxx qla4xxx lpfc mpt3sas mpt2sas qed qedf qedi intel_qat "
omit_dracutmodules+=" nss-softokn fido2 pkcs11 pcsc tpm2-tss systemd-pcrphase btrfs lvm mdraid nvdimm qemu virtiofs "

# Faster decompression
compress="zstd"
compress_level_zstd="3"
EOF

export DRACUT_NO_XATTR=1
/usr/bin/dracut \
    --hostonly \
    --hostonly-mode strict \
    --kver "${KERNEL_VERSION}" \
    --reproducible -v \
    --add ostree \
    -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"


##!/usr/bin/bash
#set -eoux pipefail
#
## Ensure /root symlink target exists for dracut and rpm scriptlets
#mkdir -p /var/roothome
#
#KERNEL_VERSION="$(rpm -q --queryformat="%{evr}.%{arch}" kernel-core)"
#KMOD="kernel/drivers"
#
#cat > /usr/lib/dracut/dracut.conf.d/99-linuxbook-air.conf << 'EOF'
## LinuxBook-Air: trim initramfs for MacBook Air 7,1 hardware
#
## Omit irrelevant GPU and storage drivers
#omit_drivers+=" amdgpu radeon nouveau nvidia xe qla2xxx qla4xxx lpfc mpt3sas mpt2sas qed qedf qedi intel_qat "
#
## Omit irrelevant dracut modules
#omit_dracutmodules+=" nss-softokn fido2 pkcs11 pcsc tpm2-tss systemd-pcrphase btrfs lvm mdraid nvdimm qemu virtiofs "
#
## Include wl (Broadcom BCM4360) early
##force_drivers+=" wl "
#
## Faster decompression at boot
#compress="zstd"
#compress_level_zstd="3"
#EOF
#
## Append kernel-version-specific remove_items after conf is written
## (paths contain kernel version so cannot be in heredoc)
#cat >> /usr/lib/dracut/dracut.conf.d/99-linuxbook-air.conf << EOF
## Remove irrelevant firmware
#remove_items+=" \\
#    /usr/lib/firmware/i915 \\
#    /usr/lib/firmware/xe \\
#    /usr/lib/firmware/intel/ish \\
#    /usr/lib/firmware/intel/qat \\
#    /usr/lib/firmware/dell \\
#    /usr/lib/firmware/HP \\
#    /usr/lib/firmware/LENOVO \\
#    /usr/lib/firmware/mediatek \\
#    /usr/lib/firmware/advansys \\
#    /usr/lib/firmware/cavium \\
#    /usr/lib/firmware/cxgb4 \\
#    /usr/lib/firmware/isci \\
#    /usr/lib/firmware/qlogic \\
#    /usr/lib/firmware/ene-ub6250 \\
#    /usr/lib/firmware/cis \\
#    /usr/lib/firmware/cbfw-3.2.5.1.bin \\
#    /usr/lib/firmware/ct2fw-3.2.5.1.bin \\
#    /usr/lib/firmware/ctfw-3.2.5.1.bin \\
#    /usr/lib/firmware/ql2100_fw.bin \\
#    /usr/lib/firmware/ql2200_fw.bin \\
#    /usr/lib/firmware/ql2300_fw.bin \\
#    /usr/lib/firmware/ql2322_fw.bin \\
#    /usr/lib/firmware/ql2400_fw.bin \\
#    /usr/lib/firmware/ql2500_fw.bin \\
#    /usr/bin/vi \\
#    /usr/bin/btrfs \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/net/ethernet/chelsio \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/scsi/bfa \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/md/dm-vdo \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/block/drbd \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/infiniband \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/thunderbolt \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/target \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/gpu/drm/vmwgfx \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/gpu/drm/gma500 \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/gpu/drm/hyperv \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/gpu/drm/vboxvideo \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/scsi/elx \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/md/bcache \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/scsi/fnic \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/scsi/mpi3mr \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/scsi/pm8001 \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/nvme/target \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/scsi/megaraid \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/ufs \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/scsi/csiostor \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/nvdimm \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/net/wireless/mediatek \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/scsi/isci \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/scsi/aic7xxx \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/scsi/aacraid \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/scsi/libfc \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/hv \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/platform/surface \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/hid/surface-hid \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/hid/intel-ish-hid \\
#    /usr/lib/modules/${KERNEL_VERSION}/${KMOD}/hid/intel-thc-hid \\
#    "
#EOF
#
#export DRACUT_NO_XATTR=1
#/usr/bin/dracut --no-hostonly --kver "${KERNEL_VERSION}" --reproducible -v --add ostree -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
#chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"