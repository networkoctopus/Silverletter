#!/bin/bash
# Assemble the pinned driver's kernel-derived files, without installing anything.
set -euo pipefail

source_tree=${1:?pinned driver checkout is required}
kernel_version=${2:?kernel release is required}
archive=${3:?verified kernel.org source archive is required}
test "$(git -C "$source_tree" rev-parse HEAD)" = 0c7cc3c7c05d97911fd400af1d48a6ebb4b55570
source_tree=$(cd "$source_tree" && pwd)
source_version=${kernel_version%%-*}
[[ "$source_version" =~ ^(6\.18|7\.2)(\.[0-9]+)?$ ]] || {
    echo "CS4208 candidate has not been reviewed for kernel $kernel_version" >&2
    exit 1
}
series=${BASH_REMATCH[1]}
tag=v${source_version}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Feed the upstream assembler an OFFLINE cache from the exact kernel archive,
# not its default older kernel tag. The caller verifies the archive checksum.
# A checksum verified upstream release is our trust anchor for previously
# unrecorded tags; existing upstream lockfile entries must still match.
paths=(
    sound/hda/codecs/cirrus/cs420x.c
    sound/hda/common/hda_local.h
    sound/hda/common/hda_auto_parser.h
    sound/hda/common/hda_jack.h
    sound/hda/common/hda_beep.h
    sound/hda/codecs/generic.h
)
members=()
for path in "${paths[@]}"; do members+=("linux-$source_version/$path"); done
tar -xJf "$archive" --no-same-owner -C "$work" "${members[@]}"
cache=$work/cache/$tag
mkdir -p "$cache/upstream" "$cache/kheaders"
install -m644 "$work/linux-$source_version/${paths[0]}" "$cache/upstream/cs420x.c"
for path in "${paths[@]:1}"; do
    install -m644 "$work/linux-$source_version/$path" "$cache/kheaders/${path##*/}"
done
bash "$source_tree/packaging/fetch-upstream.sh" \
    --tag "$tag" --cache "$work/cache" --offline --accept-new

# These identify the candidate on disk; upstream's MODULE_VERSION/source ID
# also hashes this addition into the module's runtime identity.
printf '\nMODULE_INFO(silverletter_audio_fix, "weegee-20261021.01-v1");\n' \
    >> "$source_tree/src/cs420x-a1534/$series/cs420x.c"
printf 'MODULE_INFO(silverletter_audio_source, "0c7cc3c7c05d97911fd400af1d48a6ebb4b55570");\n' \
    >> "$source_tree/src/cs420x-a1534/$series/cs420x.c"
