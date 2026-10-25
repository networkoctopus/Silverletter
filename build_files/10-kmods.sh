#!/bin/bash
set -ouex pipefail

HARDWARE_PROFILE="${SILVERLETTER_HARDWARE_PROFILE:-macbookair7}"
install -Dm755 /ctx/hardware/silverletter-model \
    /usr/libexec/silverletter-model

pinned_clone() {
    local repository="$1"
    local commit="$2"
    local destination="$3"

    git init "$destination"
    git -C "$destination" remote add origin "$repository"
    git -C "$destination" fetch --depth 1 origin "$commit"
    git -C "$destination" checkout --detach FETCH_HEAD
    test "$(git -C "$destination" rev-parse HEAD)" = "$commit"
}

### ── Broadcom wl (via ublue akmods pre-built image) ──
# Avoids akmod-wl root build failure by using pre-compiled RPMs
# Mount the akmods image contents into a temp dir and install
if [[ "$HARDWARE_PROFILE" == "macbookair7" ]]; then
    dnf5 install -y \
        /var/tmp/akmods-common/rpms/ublue-os/ublue-os-akmods-addons*.rpm \
        /var/tmp/akmods-common/rpms/common/broadcom-wl*.rpm \
        /var/tmp/akmods-common/rpms/kmods/kmod-wl*.rpm
else
    # MacBook9,1 BCM4350 (14e4:43a3) uses in-tree brcmfmac. broadcom-wl
    # blacklists that driver globally and fails to bind this device.
    rm -f /usr/lib/modprobe.d/broadcom-wl-blacklist.conf
fi

### ── FacetimeHD (built from source) ──
# Install kernel-devel from akmods image (matches base kernel, avoids repo timing issues)
dnf5 install -y \
    /var/tmp/akmods-common/kernel-rpms/kernel-devel-*.rpm \
    /var/tmp/akmods-common/kernel-rpms/kernel-devel-matched-*.rpm

# Tools needed for kmod build and firmware extraction
dnf5 install -y curl cpio xz

KERNEL_VERSION=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)

# Build and install the facetimehd kernel module
pinned_clone \
    https://github.com/patjak/facetimehd.git \
    6dc8cd85e87993ff21cb01eb333ff42afb058551 \
    /tmp/facetimehd
cd /tmp/facetimehd
make KDIR="/usr/src/kernels/${KERNEL_VERSION}"
install -Dm644 facetimehd.ko \
    "/usr/lib/modules/${KERNEL_VERSION}/extra/facetimehd/facetimehd.ko"
depmod -a "${KERNEL_VERSION}"
cd /
rm -rf /tmp/facetimehd

# Extract Apple firmware blob and install
# Downloads Apple Boot Camp software at build time to extract the firmware binary
pinned_clone \
    https://github.com/patjak/facetimehd-firmware.git \
    60ee21228d9ca00a7bd84fdaefaff00a81f1db91 \
    /tmp/facetimehd-firmware
cd /tmp/facetimehd-firmware
make
make install PREFIX=/usr
cd /
rm -rf /tmp/facetimehd-firmware

### ── MacBook9,1 CS4208 audio (built from source) ──
if [[ "$HARDWARE_PROFILE" == "macbook9" ]]; then
    # Mainline detects the codec but does not initialize the 12-inch MacBook's
    # digital speaker path and external amplifier. Build the model-specific
    # replacement for the exact image kernel; do not carry DKMS into the image.
    pinned_clone \
        https://github.com/leifliddy/macbook12-audio-driver.git \
        4cdfcdbac2db3f300cc45d9679cfd21df6590a8a \
        /tmp/macbook12-audio-driver
    cd /tmp/macbook12-audio-driver
    # Opt-in candidate only: hardware validation after deep sleep is pending.
    if [[ "${SILVERLETTER_CS4208_RESUME_TEST:-0}" == 1 ]]; then
        dnf5 install -y patch
        patch --batch --forward --fuzz=0 -p1 < /ctx/audio/cs4208-resume-order.patch
        printf '\nMODULE_INFO(silverletter_audio_fix, "cs4208-resume-order-v1");\n' \
            >> patch_cirrus/cs420x.c
        printf '\nMODULE_INFO(silverletter_audio_fix, "cs4208-resume-order-v1");\n' \
            >> patch_cirrus/patch_cirrus.c
    fi
    MACBOOK12_AUDIO_KERNEL_CACHE=/var/cache/macbook12-audio-driver \
        ./prepare.cirrus.driver.sh "${KERNEL_VERSION}"
    make KERNELRELEASE="${KERNEL_VERSION}"
    make KERNELRELEASE="${KERNEL_VERSION}" install
    if [[ "${SILVERLETTER_CS4208_RESUME_TEST:-0}" == 1 ]]; then
        test "$(modinfo -k "$KERNEL_VERSION" -F silverletter_audio_fix snd_hda_codec_cs420x)" = \
            cs4208-resume-order-v1
    fi
    install -Dm644 \
        contrib/wireplumber/wireplumber.conf.d/51-macbook-cs4208-softvol.conf \
        /usr/share/wireplumber/wireplumber.conf.d/51-macbook-cs4208-softvol.conf
    cd /
    rm -rf /tmp/macbook12-audio-driver
fi

### ── MacBook9,1 Broadcom Bluetooth reconnect fix ──
if [[ "$HARDWARE_PROFILE" == "macbook9" ]]; then
    dnf5 install -y patch elfutils-libelf-devel openssl-devel
    bash /ctx/bluetooth/build-bluetooth.sh "${KERNEL_VERSION}"
fi

### ── mbpfan (fan control for MacBooks) ──
if [[ "$HARDWARE_PROFILE" == "macbookair7" ]]; then
    pinned_clone \
        https://github.com/linux-on-mac/mbpfan.git \
        a9c324db67470a222b20d8ddaa9b4e1e488e9771 \
        /tmp/mbpfan
    cd /tmp/mbpfan
    make
    make install
    install -Dm644 mbpfan.service /usr/lib/systemd/system/mbpfan.service
    install -Dm644 /ctx/hardware/mbpfan-model.conf \
        /usr/lib/systemd/system/mbpfan.service.d/10-silverletter-model.conf
    systemctl enable mbpfan.service
    cd /
    rm -rf /tmp/mbpfan
fi

# Remove build-time-only kmod toolchain (gcc/make/binutils cleaned by autoremove)
if [[ "$HARDWARE_PROFILE" == "macbook9" ]]; then
    dnf5 remove -y patch elfutils-libelf-devel openssl-devel
fi
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
