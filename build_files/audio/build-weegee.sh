#!/bin/bash
# Image build only: no DKMS, live module reloads, or host audio changes.
set -euo pipefail

[[ "${SILVERLETTER_HARDWARE_PROFILE:-}" == macbook9 ]]
source_tree=${1:?pinned driver checkout is required}
kernel_version=${2:?image kernel release is required}
source_version=${kernel_version%%-*}
[[ "$source_version" =~ ^(6\.18|7\.2)(\.[0-9]+)?$ ]] || {
    echo "CS4208 candidate has not been reviewed for kernel $kernel_version" >&2
    exit 1
}
kernel_major=${source_version%%.*}
kernel_build=/usr/src/kernels/$kernel_version
[[ "$(make -s -C "$kernel_build" kernelrelease)" == "$kernel_version" ]]
stock_vermagic=$(modinfo -k "$kernel_version" -F vermagic snd_hda_codec_cs420x)
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source_tree=$(cd "$source_tree" && pwd)
test "$(git -C "$source_tree" rev-parse HEAD)" = 0c7cc3c7c05d97911fd400af1d48a6ebb4b55570

# Share the existing Bluetooth builder's verified kernel source cache. Both
# builders verify checksums on every use, even for a previously cached archive.
cache=/var/cache/silverletter-bluetooth
archive=linux-$source_version.tar.xz
base_url=https://cdn.kernel.org/pub/linux/kernel/v$kernel_major.x
mkdir -p "$cache"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
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
bash "$script_dir/prepare-weegee.sh" "$source_tree" "$kernel_version" "$cache/$archive"

module_tree=$source_tree/src/cs420x-a1534
version=$(<"$source_tree/VERSION")
test "$version" = 20261021.01
make -C "$module_tree" KDIR="$kernel_build" PKGVER="$version" -j2
module=$module_tree/snd-hda-codec-cs420x.ko
[[ "$(modinfo -F vermagic "$module")" == "$stock_vermagic" ]]
[[ "$(modinfo -F silverletter_audio_fix "$module")" == weegee-20261021.01-v1 ]]
[[ "$(modinfo -F silverletter_audio_source "$module")" == 0c7cc3c7c05d97911fd400af1d48a6ebb4b55570 ]]
[[ "$(modinfo -F version "$module")" == "$version+"* ]]
install -Dm644 "$module" "/usr/lib/modules/$kernel_version/updates/snd-hda-codec-cs420x.ko"
depmod -a "$kernel_version"
[[ "$(modinfo -k "$kernel_version" -n snd_hda_codec_cs420x)" == "/lib/modules/$kernel_version/updates/snd-hda-codec-cs420x.ko" ]]

# The four-channel ACP profile, always-available output path and software
# volume policy are required together. Do not install the old stereo policy.
rm -f /usr/share/wireplumber/wireplumber.conf.d/51-macbook-cs4208-softvol.conf
install -Dm644 "$module_tree/contrib/wireplumber/51-macbook91-cs4208.conf" \
    /usr/share/wireplumber/wireplumber.conf.d/51-macbook91-cs4208.conf
for file in macbook91-cs4208.conf macbook91-output-speaker.conf; do
    install -Dm644 "$module_tree/contrib/acp/$file" "/usr/share/macbook91-cs4208/acp/$file"
done
# ACP appends .conf to paths-output, including absolute paths. Supplying the
# suffix twice leaves an empty route with a raw label, unknown type and priority
# zero instead of loading the speaker path's translated label and mixer policy.
patch --batch --forward --fuzz=0 -p1 -d /usr/share/macbook91-cs4208/acp \
    < "$script_dir/acp-path-reference.patch"
# Retain licence notices for redistributed module and policy sources.
install -d /usr/share/licenses/macbook91-cs4208
cp -a "$source_tree/LICENSES/." /usr/share/licenses/macbook91-cs4208/
install -Dm644 "$source_tree/LICENSE" /usr/share/licenses/macbook91-cs4208/LICENSE
