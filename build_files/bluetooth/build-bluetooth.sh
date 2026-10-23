#!/bin/bash
set -euo pipefail

[[ "${SILVERLETTER_HARDWARE_PROFILE:-}" == macbook9 ]]
kernel_version=${1:?image kernel version is required}
kernel_source_version=${kernel_version%%-*}
if [[ ! "$kernel_source_version" =~ ^([0-9]+)\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Unsupported Bluetooth kernel source version: $kernel_source_version" >&2
    exit 1
fi
kernel_major=${BASH_REMATCH[1]}
kernel_build=/usr/src/kernels/$kernel_version
[[ "$(make -s -C "$kernel_build" kernelrelease)" == "$kernel_version" ]]
stock_vermagic=$(modinfo -k "$kernel_version" -F vermagic bluetooth)

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cache=/var/cache/silverletter-bluetooth
archive=linux-$kernel_source_version.tar.xz
base_url=https://cdn.kernel.org/pub/linux/kernel/v$kernel_major.x
mkdir -p "$cache"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Cache downloads across image builds, but verify the source on every build.
# Fetch checksums again when a new kernel is encountered.
if [[ ! -s "$cache/$archive" ]]; then
    curl --fail --location --retry 3 "$base_url/$archive" -o "$work/$archive"
    curl --fail --location --retry 3 "$base_url/sha256sums.asc" -o "$work/sha256sums.asc"
    awk -v archive="$archive" '$2 == archive { print }' "$work/sha256sums.asc" > "$work/source.sha256"
    test -s "$work/source.sha256"
    (cd "$work" && sha256sum --check source.sha256)
    mv "$work/source.sha256" "$cache/$archive.sha256"
    mv "$work/$archive" "$cache/$archive"
fi
(cd "$cache" && sha256sum --check "$archive.sha256")

tar -xJf "$cache/$archive" --no-same-owner -C "$work" \
    "linux-$kernel_source_version/net/bluetooth"
source_dir=$work/linux-$kernel_source_version
patch --batch --forward --fuzz=0 -d "$source_dir" -p1 < "$script_dir/broadcom-legacy-advertising.patch"
printf '\nMODULE_INFO(silverletter_bt_fix, "broadcom-legacy-adv-mask-v1");\n' \
    >> "$source_dir/net/bluetooth/af_bluetooth.c"

# Only rebuild the Bluetooth core. Fedora's transport drivers remain in use.
make -C "$kernel_build" M="$source_dir/net/bluetooth" -j2 bluetooth.ko
module=$source_dir/net/bluetooth/bluetooth.ko
[[ "$(modinfo -F vermagic "$module")" == "$stock_vermagic" ]]
[[ "$(modinfo -F silverletter_bt_fix "$module")" == broadcom-legacy-adv-mask-v1 ]]
install -Dm644 "$module" "/usr/lib/modules/$kernel_version/updates/bluetooth.ko"
depmod -a "$kernel_version"
[[ "$(modinfo -k "$kernel_version" -n bluetooth)" == "/lib/modules/$kernel_version/updates/bluetooth.ko" ]]
