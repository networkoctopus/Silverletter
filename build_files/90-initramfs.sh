#!/usr/bin/bash
set -eoux pipefail

HARDWARE_PROFILE="${SILVERLETTER_HARDWARE_PROFILE:-macbookair7}"

if [[ "$HARDWARE_PROFILE" == "macbookair7" ]]; then
cat > /usr/lib/dracut/dracut.conf.d/99-silverletter.conf << 'EOF'
# Silverletter: trim initramfs for MacBook Air 7,1 hardware
omit_drivers+=" qla2xxx qla4xxx lpfc mpt3sas mpt2sas qed qedf qedi intel_qat amdgpu radeon nouveau nvidia xe "
omit_dracutmodules+=" crypt fips fips-crypto-policies nss-softokn fido2 pkcs11 pcsc tpm2-tss systemd-pcrphase btrfs lvm mdraid nvdimm qemu virtiofs "
remove_items+=" /usr/lib/firmware/i915 /usr/lib/firmware/xe /usr/lib/firmware/intel/ish /usr/lib/firmware/intel/qat /usr/lib/firmware/dell /usr/lib/firmware/HP /usr/lib/firmware/LENOVO /usr/lib/firmware/mediatek /usr/lib/firmware/advansys /usr/lib/firmware/cavium /usr/lib/firmware/cxgb4 /usr/lib/firmware/isci /usr/lib/firmware/qlogic /usr/lib/firmware/ene-ub6250 /usr/lib/firmware/cis /usr/lib/firmware/cbfw-3.2.5.1.bin /usr/lib/firmware/ct2fw-3.2.5.1.bin /usr/lib/firmware/ctfw-3.2.5.1.bin /usr/lib/firmware/ql2100_fw.bin /usr/lib/firmware/ql2200_fw.bin /usr/lib/firmware/ql2300_fw.bin /usr/lib/firmware/ql2322_fw.bin /usr/lib/firmware/ql2400_fw.bin /usr/lib/firmware/ql2500_fw.bin "
compress="zstd"
compress_level_zstd="3"
EOF
elif [[ "$HARDWARE_PROFILE" == "macbook9" ]]; then
cat > /usr/lib/dracut/dracut.conf.d/99-silverletter.conf << 'EOF'
# MacBook9,1: use the Air's GPU, storage, and dracut exclusions, but retain
# Btrfs for the root filesystem and i915 firmware for Skylake display power
# management. Firmware globs also cover Fedora's compressed firmware files.
omit_drivers+=" qla2xxx qla4xxx lpfc mpt3sas mpt2sas qed qedf qedi intel_qat amdgpu radeon nouveau nvidia xe "
omit_dracutmodules+=" crypt fips fips-crypto-policies nss-softokn fido2 pkcs11 pcsc tpm2-tss systemd-pcrphase lvm mdraid nvdimm qemu virtiofs "
remove_items+=" /usr/lib/firmware/nvidia /usr/lib/firmware/amdgpu /usr/lib/firmware/radeon /usr/lib/firmware/xe /usr/lib/firmware/intel/ish /usr/lib/firmware/intel/qat /usr/lib/firmware/dell /usr/lib/firmware/HP /usr/lib/firmware/LENOVO /usr/lib/firmware/mediatek /usr/lib/firmware/advansys /usr/lib/firmware/cavium /usr/lib/firmware/cxgb4 /usr/lib/firmware/isci /usr/lib/firmware/qlogic /usr/lib/firmware/ene-ub6250 /usr/lib/firmware/cis /usr/lib/firmware/cbfw-3.2.5.1.bin* /usr/lib/firmware/ct2fw-3.2.5.1.bin* /usr/lib/firmware/ctfw-3.2.5.1.bin* /usr/lib/firmware/ql2100_fw.bin* /usr/lib/firmware/ql2200_fw.bin* /usr/lib/firmware/ql2300_fw.bin* /usr/lib/firmware/ql2322_fw.bin* /usr/lib/firmware/ql2400_fw.bin* /usr/lib/firmware/ql2500_fw.bin* "
# Keep the in-tree SPI top-case
# stack and the BCM4350 vendor plugin to be available during early boot. Intel
# LPSS is built into Fedora's kernel; these are the loadable pieces used by
# APP000D and brcmfmac's WCC firmware path. Force the model-specific CS4208
# and Bluetooth replacements to win over stock modules during early loading.
add_drivers+=" applespi spi_pxa2xx_core spi_pxa2xx_platform spi_pxa2xx_pci brcmfmac brcmfmac_wcc snd_hda_codec_cs420x bluetooth "
compress="zstd"
compress_level_zstd="3"
EOF
else
    echo "Unknown hardware profile: $HARDWARE_PROFILE" >&2
    exit 1
fi

KERNEL_VERSION="$(rpm -q --queryformat="%{evr}.%{arch}" kernel-core)"

export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "${KERNEL_VERSION}" --reproducible -v --add ostree -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"
