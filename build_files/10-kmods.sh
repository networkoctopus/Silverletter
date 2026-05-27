#!/bin/bash
set -ouex pipefail

### ── Broadcom wl (via ublue akmods pre-built image) ──
# Avoids akmod-wl root build failure by using pre-compiled RPMs
# Mount the akmods image contents into a temp dir and install
dnf5 install -y \
    /var/tmp/akmods-common/rpms/ublue-os/ublue-os-akmods-addons*.rpm \
    /var/tmp/akmods-common/rpms/common/broadcom-wl*.rpm \
    /var/tmp/akmods-common/rpms/kmods/kmod-wl*.rpm

### ── FacetimeHD (built from akmod source) ──
# Install kernel-devel from akmods image (matches base kernel, avoids repo timing issues)
dnf5 install -y \
    /var/tmp/akmods-common/kernel-rpms/kernel-devel-*.rpm \
    /var/tmp/akmods-common/kernel-rpms/kernel-devel-matched-*.rpm

dnf5 -y copr enable mulderje/facetimehd-kmod
dnf5 install -y --setopt=tsflags=noscripts \
    facetimehd-kmod \
    facetimehd \
    facetimehd-firmware
dnf5 -y copr disable mulderje/facetimehd-kmod

KERNEL_VERSION=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)
akmods --force --kernels "${KERNEL_VERSION}"

dnf5 -y mark user facetimehd facetimehd-firmware

### ── mbpfan (fan control for MacBooks) ──
git clone --depth 1 --branch v2.4.0 https://github.com/linux-on-mac/mbpfan.git /tmp/mbpfan
cd /tmp/mbpfan
make
make install
install -Dm644 mbpfan.service /usr/lib/systemd/system/mbpfan.service
systemctl enable mbpfan.service
cd /
rm -rf /tmp/mbpfan

### Mark packages from packages.yml as user-installed so they aren't accidentally removed during cleanup
yq eval '.[][]' /ctx/packages.yml | xargs dnf5 -y mark user

# Remove build-time-only kmod toolchain
dnf5 remove -y \
    akmod-facetimehd \
    akmods \
    kmodtool \
    kernel-devel \
    kernel-devel-matched \
    kernel-headers \
    yq

### Cleanup up akmods temp file
rm -rf /var/cache/akmods /var/tmp/akmods-common /run/akmods /run/dnf

### ── akmods user cleanup ──
userdel akmods 2>/dev/null || true
groupdel akmods 2>/dev/null || true