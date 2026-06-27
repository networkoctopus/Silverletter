#!/bin/bash
set -ouex pipefail

### ── Broadcom wl (via ublue akmods pre-built image) ──
# Avoids akmod-wl root build failure by using pre-compiled RPMs
# Mount the akmods image contents into a temp dir and install
dnf5 install -y \
    /var/tmp/akmods-common/rpms/ublue-os/ublue-os-akmods-addons*.rpm \
    /var/tmp/akmods-common/rpms/common/broadcom-wl*.rpm \
    /var/tmp/akmods-common/rpms/kmods/kmod-wl*.rpm

### ── FacetimeHD (built from source) ──
# Install kernel-devel from akmods image (matches base kernel, avoids repo timing issues)
dnf5 install -y \
    /var/tmp/akmods-common/kernel-rpms/kernel-devel-*.rpm \
    /var/tmp/akmods-common/kernel-rpms/kernel-devel-matched-*.rpm

# Tools needed for kmod build and firmware extraction
dnf5 install -y curl cpio xz

KERNEL_VERSION=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)

# Build and install the facetimehd kernel module
git clone --depth 1 https://github.com/patjak/facetimehd.git /tmp/facetimehd
cd /tmp/facetimehd
make KDIR="/usr/src/kernels/${KERNEL_VERSION}"
install -Dm644 facetimehd.ko \
    "/usr/lib/modules/${KERNEL_VERSION}/extra/facetimehd/facetimehd.ko"
depmod -a "${KERNEL_VERSION}"
cd /
rm -rf /tmp/facetimehd

# Extract Apple firmware blob and install
# Downloads Apple Boot Camp software at build time to extract the firmware binary
git clone --depth 1 https://github.com/patjak/facetimehd-firmware.git /tmp/facetimehd-firmware
cd /tmp/facetimehd-firmware
make
make install PREFIX=/usr
cd /
rm -rf /tmp/facetimehd-firmware

### ── mbpfan (fan control for MacBooks) ──
git clone --depth 1 --branch v2.4.0 https://github.com/linux-on-mac/mbpfan.git /tmp/mbpfan
cd /tmp/mbpfan
make
make install
install -Dm644 mbpfan.service /usr/lib/systemd/system/mbpfan.service
systemctl enable mbpfan.service
cd /
rm -rf /tmp/mbpfan

# Remove build-time-only kmod toolchain (gcc/make/binutils cleaned by autoremove)
dnf5 remove -y \
    kernel-devel \
    kernel-devel-matched \
    kernel-headers

### Clean up packages
dnf5 autoremove -y

### Cleanup up akmods temp file
rm -rf /var/cache/akmods /var/tmp/akmods-common /run/akmods /run/dnf

### ── akmods user cleanup ──
userdel akmods 2>/dev/null || true
groupdel akmods 2>/dev/null || true