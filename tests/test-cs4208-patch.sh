#!/bin/bash
# Verify application against a caller-supplied checkout of the pinned driver.
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_tree=${1:?usage: test-cs4208-patch.sh /path/to/pinned/upstream/checkout}
test "$(git -C "$source_tree" rev-parse HEAD)" = 4cdfcdbac2db3f300cc45d9679cfd21df6590a8a
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git -C "$source_tree" archive HEAD patch_cirrus | tar -x -C "$work"
patch --batch --forward --fuzz=0 -d "$work" -p1 < "$repo_root/build_files/audio/cs4208-resume-order.patch"
# A repeated application must not silently succeed.
! patch --batch --forward --fuzz=0 --dry-run -d "$work" -p1 \
    < "$repo_root/build_files/audio/cs4208-resume-order.patch" >/dev/null 2>&1
header=$work/patch_cirrus/patch_cirrus_a1534_pcm.h
awk '
/^static int cs_4208_resume\(/ { inside=1 }
inside && /err = cs_4208_init_explicit/ { init=NR }
inside && /snd_hda_regmap_sync/ { sync=NR }
inside && /if \(!system_resume\)/ { guard=NR }
inside && /err = setup_a1534/ { replay=NR }
inside && /err = hp \? headphones_a1534/ { route=NR }
inside && /snd_hda_codec_setup_stream/ { stream=NR }
END { if (!(init < sync && sync < guard && guard < replay && replay < route && route < stream)) exit 1 }
' "$header"
grep -q 'nid = hp ? 0x02 : 0x0a;' "$header"
grep -q 'CS4208 resume-order-v1: failed' "$header"
# No unrelated source files, including driver lifetime code, change.
cmp "$work/patch_cirrus/cs420x.c" <(git -C "$source_tree" show HEAD:patch_cirrus/cs420x.c)
patch --batch --reverse --fuzz=0 -d "$work" -p1 < "$repo_root/build_files/audio/cs4208-resume-order.patch"
cmp "$header" <(git -C "$source_tree" show HEAD:patch_cirrus/patch_cirrus_a1534_pcm.h)
echo 'CS4208 patch application/order/scope checks passed (not hardware validation)'
