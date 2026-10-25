#!/bin/bash
# Offline source assembly and integration checks, not hardware validation.
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_tree=${1:?usage: test-cs4208-driver.sh pinned-checkout kernel.tar.xz sha256sums [kernel-release]}
archive=$(realpath "${2:?kernel source archive is required}")
checksums=${3:?kernel.org sha256sums file is required}
kernel_version=${4:-7.2.11-200.fc44.x86_64}
source_version=${kernel_version%%-*}
series=${source_version%.*}
[[ "$source_version" =~ ^[0-9]+\.[0-9]+$ ]] && series=$source_version
test "$(git -C "$source_tree" rev-parse HEAD)" = 0c7cc3c7c05d97911fd400af1d48a6ebb4b55570
expected=$(awk -v archive="${archive##*/}" '$2 == archive { print $1 }' "$checksums")
[[ "$expected" =~ ^[[:xdigit:]]{64}$ ]]
[[ "$(sha256sum "$archive" | cut -d' ' -f1)" == "$expected" ]]
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git clone --quiet --no-hardlinks "$source_tree" "$work/source"
refuses() {
    if "$@"; then
        echo "Expected command to refuse: $*" >&2
        exit 1
    fi
}

# Guard failures must occur before downloading, building or installing anything.
for profile in macbookair7 asahi unknown; do
    refuses env SILVERLETTER_HARDWARE_PROFILE="$profile" \
        bash "$repo_root/build_files/audio/build-weegee.sh" /nonexistent invalid
done
for unsupported in 6.19.1-test 7.3.1-test invalid; do
    refuses env SILVERLETTER_HARDWARE_PROFILE=macbook9 \
        bash "$repo_root/build_files/audio/build-weegee.sh" /nonexistent "$unsupported"
    refuses bash "$repo_root/build_files/audio/prepare-weegee.sh" "$work/source" "$unsupported" /nonexistent
done

bash "$repo_root/build_files/audio/prepare-weegee.sh" "$work/source" "$kernel_version" "$archive"
module=$work/source/src/cs420x-a1534
[[ "$(<"$module/kheaders/KERNEL-SERIES")" == "$series" ]]
(cd "$module" && sha256sum --check UPSTREAM.sha256)
(cd "$module/vendored" && sha256sum --check PROVENANCE.sha256)
grep -q 'weegee-20261021.01-v1' "$module/$series/cs420x.c"
grep -q "tag v$source_version" "$module/UPSTREAM.lock"
grep -q 'AC_VERB_SET_CVT_CHAN_COUNT' "$module/a1534_pcm.h"
grep -q 'channels_min = 4' "$module/a1534_pcm.h"
grep -q 'channels_max = 4' "$module/a1534_pcm.h"
grep -q '^static bool a1534_amp;' "$module/a1534_i2c.h"
grep -q 'MacBook9,1' "$module/a1534_match.h"

# The headers in the assembly must be byte-for-byte those in the archive.
tar -xJf "$archive" --no-same-owner -C "$work" \
    "linux-$source_version/sound/hda/common" \
    "linux-$source_version/sound/hda/codecs/generic.h"
for name in hda_auto_parser hda_beep hda_jack hda_local; do
    cmp "$module/kheaders/$series/$name.h" "$work/linux-$source_version/sound/hda/common/$name.h"
done
cmp "$module/kheaders/$series/generic.h" "$work/linux-$source_version/sound/hda/codecs/generic.h"

# No local mutation of the routing, model gates, sequence or volume policy.
for name in a1534_pcm.h a1534_match.h a1534_snapshot.h a1534_i2c.h; do
    cmp "$module/$name" "$source_tree/src/cs420x-a1534/$name"
done
policy=$module/contrib/wireplumber/51-macbook91-cs4208.conf
grep -q 'api.alsa.soft-mixer = true' "$policy"
grep -q 'channelmix.upmix-method = simple' "$policy"
grep -q 'api.acp.auto-profile = false' "$policy"
grep -q 'api.acp.auto-port = false' "$policy"
grep -q 'device.profile-set = "/usr/share/macbook91-cs4208/acp/macbook91-cs4208.conf"' "$policy"
grep -q '^channel-map = front-left,front-right,rear-left,rear-right' "$module/contrib/acp/macbook91-cs4208.conf"
grep -Fq 'bash /ctx/audio/build-weegee.sh /tmp/macbook91-cs4208 "$KERNEL_VERSION"' "$repo_root/build_files/10-kmods.sh"
for file in Containerfile Containerfile.macbook9 .github/workflows/build.yml \
    build_files/10-kmods.sh build_files/95-hardware-validate.sh build_files/audio/build-weegee.sh; do
    refuses grep -Eq 'CS4208_RESUME_TEST|cs4208_resume_test' "$repo_root/$file"
done
refuses grep -q 'leifliddy/macbook12-audio-driver' "$repo_root/build_files/10-kmods.sh"
refuses grep -q 'cs4208-resume-order.patch' "$repo_root/build_files/10-kmods.sh"
echo 'CS4208 exact-kernel assembly, gating and policy checks passed (not hardware validation)'
