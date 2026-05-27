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
dnf5 -y copr enable mulderje/facetimehd-kmod
dnf5 install -y --setopt=tsflags=noscripts \
    facetimehd-kmod \
    facetimehd \
    facetimehd-firmware
dnf5 -y copr disable mulderje/facetimehd-kmod

echo "=== Builder kernel: $(uname -r) ==="
echo "=== Target kernel: $(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-devel) ==="

akmods --force --kernels "$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-devel)"

# Mark runtime packages as user-installed so autoremove keeps them
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

# Remove build-time-only kmod toolchain
dnf5 remove -y \
    akmod-facetimehd \
    akmods \
    kmodtool \
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