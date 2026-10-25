# CS4208 Weegee driver integration

Status: default MacBook9,1 audio driver on the `testing` branch, at the user's
request; **not physically validated on Silverletter yet**. It replaces the
existing leifliddy driver and its stereo soft-volume policy. The previous
`cs4208-resume-order-v1` candidate did not restore speakers after deep sleep;
this candidate replaces it rather than stacking more patches on it.

## Source and scope

- Driver: <https://github.com/Weegee/macbook91-cs4208-pub>
- Pinned commit: `0c7cc3c7c05d97911fd400af1d48a6ebb4b55570`
- Upstream version: `20261021.01`
- Silverletter marker: `weegee-20261021.01-v1`

The driver gates its new path on MacBook9,1 DMI and matching CS4208 codec
identity. It explicitly programs the speaker converter's separate channel-count
register, uses the physical speaker converter, and fixes playback at four
channels, 44.1 kHz, S16_LE. The paired WirePlumber/ACP files provide software
volume, stereo-to-four-channel duplication, and a route that remains available
when headphones are inserted. The driver handles jack routing itself. The old
stereo soft-volume policy is not installed alongside these files.

The upstream maintainer reports repeated successful deep sleeps on this model.
Those results are **not proof on our host**. Our earlier unsuccessful Boot Camp
replay also wrote the converter channel-count register, so that register alone
is not a confirmed explanation here. Latest release hardware results are
carried forward from code-identical earlier releases, not a fresh hardware run.
Headset-call and HDMI behavior are not fully validated upstream.

We build directly, without DKMS, against the exact image kernel-devel package.
`prepare-weegee.sh` supplies upstream's assembler an offline cache extracted
from the kernel.org archive matching that kernel release. The archive is checked
against kernel.org's published SHA-256 checksum (HTTPS, not independent OpenPGP
signature verification), on every use. This cache is shared with our existing
Bluetooth builder. Thus the private HDA headers and baseline codec source match
the kernel.org release, rather than the driver's older bundled snapshot; Fedora
patches are not separately reconstructed. Upstream's existing lock entries
remain enforced, and its patches apply with zero fuzz. New tag hashes are
recorded in the disposable build checkout, anchored by the archive checksum.
Only the reviewed 6.18 and 7.2 series are accepted; another series fails closed
until reviewed. Exact-kernel assembly is a Silverletter adaptation, so upstream
hardware results cannot establish its behavior either.

No live reload, suspend hook, automatic suspend, global power-saving change, or
kernel-argument change is installed. The unproven `a1534_amp` programming path
remains off by default; do not enable it. The separate instant wake from
open-lid deep sleep is not claimed fixed. MacBookAir and Asahi builds are unchanged.

## Local validation (2026-10-25)

- Exact-release source assembly and private-header byte comparisons passed for
  Linux 7.2.11; source manifests and vendored-sequence checksums passed.
- The candidate compiled and installed in a disposable Fedora container against
  `7.2.11-200.fc44.x86_64`, with matching vermagic, expected module/source markers
  and module version `20261021.01+65ffca6f1eac5c16`. Companion policy copies
  matched upstream and the old policy was absent. Optional BTF generation was
  skipped because vmlinux was unavailable; pahole was also unavailable.
- New shell scripts passed ShellCheck. Hardware gating, shell syntax and workflow
  YAML parsing passed. The earlier experimental publication guard was removed
  when this driver became the default on `testing`.
- The upstream suite, using its released source assembly in a separate
  unprivileged container environment, reported **237 passed, 0 failed, 14
  blocked**. The blocked checks require kernel build headers in that test
  container, Arch packaging facilities/artifacts, or physical hardware. This
  is not a complete upstream release qualification.
- No full candidate bootc image has been built here, and no candidate module
  has been loaded on the host. Initramfs/image validation and audible
  suspend/resume behavior remain pending.

## Build and identify

In GitHub's manual build workflow select:

- branch: `testing`
- variant: `macbook9`
- tag: `testing` (or another normal manual-build tag)
- publish: enabled when ready to deploy

No extra audio flag, build argument or special tag is needed: every MacBook9,1
build from this branch uses the driver and companion profiles. Local builds use
`Containerfile.macbook9` normally. Image validation checks module selection,
identity, companion files and initramfs inclusion, but cannot establish audible
output or resume reliability. Existing workflow triggers/publication rules are
unchanged; pushing `testing` alone does not automatically publish an image.

After booting the candidate (not by live-loading it):

```sh
modinfo -F silverletter_audio_fix snd_hda_codec_cs420x
# weegee-20261021.01-v1
modinfo -F silverletter_audio_source snd_hda_codec_cs420x
# 0c7cc3c7c05d97911fd400af1d48a6ebb4b55570
cat /sys/module/snd_hda_codec_cs420x/version
cat /sys/module/snd_hda_codec_cs420x/parameters/a1534_amp
# N
```

`modinfo` identifies the file on disk. The sysfs version identifies the loaded
module and should match `modinfo -F version snd_hda_codec_cs420x`.

## Physical validation

Keep a known-working bootc deployment for rollback and boot the candidate
normally. **Never unload, unbind or rebind the audio driver:** our earlier live
reload caused a kernel Oops. If an Oops occurs, stop and reboot/roll back.

Start at a low desktop volume (e.g. 10%); confirm the slider actually attenuates
speakers before increasing it. Check speaker/headphone playback, plug/unplug
both ways, internal microphone, and recording during jack changes. A stored
stereo profile may no longer exist: if necessary select the new internal
speakers/headphones four-channel profile in Sound Settings. Do not clear all
WirePlumber state or change unrelated network audio devices automatically.

Once baseline audio works, select deep sleep for this boot only:

```sh
echo deep | sudo tee /sys/power/mem_sleep
cat /sys/power/mem_sleep
```

Leave runtime audio power-saving and other settings unchanged. Test lid-close
sleep first; menu/open-lid sleep previously woke immediately. Confirm lid-open
wake and audible output, not merely a successful resume log. Inspect:

```sh
journalctl -k -b --no-pager | grep -E 'A1534|CS4208|PM: suspend|Oops:|BUG:|timeout'
```

Exercise at least five cycles, both idle and playing across suspend, headphones
connected/disconnected, and jack changes after wake. Include a longer sleep,
microphone recording after wake, ordinary playback after runtime idle, and clean
reboot/shutdown. Record failures honestly; successful compilation is not a fix.

## Offline regression checks

```sh
bash tests/test-hardware-gating.sh
bash tests/test-cs4208-driver.sh /path/to/pinned/checkout \
  /path/to/linux-7.2.11.tar.xz /path/to/sha256sums.asc \
  7.2.11-200.fc44.x86_64
```

These checks use disposable source copies and never access audio hardware.
Compile testing belongs in a disposable build container, not a live install.
