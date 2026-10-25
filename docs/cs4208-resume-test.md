# CS4208 deep-resume experiment

Status: experimental candidate; physical validation is required. Not an upstream
fix and not enabled in ordinary image builds. The original silence is not yet
proven to be caused by initialization/cache ordering.

Local validation: the candidate module compiled against Fedora
`7.2.11-200.fc44.x86_64` with matching vermagic and the expected test metadata.
The build retained upstream missing-prototype warnings and skipped optional BTF
generation because vmlinux was unavailable. Patch application/reversal, source
scope/order checks, hardware gating, shell syntax, and workflow YAML parsing
passed. A full candidate bootc image build and physical tests remain pending.

## Hypothesis and scope

The pinned driver replays board initialization before generic initialization and
register-cache sync. The candidate reverses that order on system resume, then
selects the current headphone/speaker path. It overrides hardcoded replay stream
parameters with the cached live parameters when present, using physical speaker
converter 0x0a (headphones 0x02). Runtime idle resumes do not replay board setup.
Resume logs distinguish full replay, completion, and reported errors.

The sequence helpers are inherited from upstream and mostly ignore individual
verb failures; checking their return values does not guarantee every hardware
command succeeded. Boot initialization, normal PCM open/prepare, live jack
handling, microphone configuration, and driver removal are otherwise unchanged.
Do not assume this fixes the separate reload crash or the deep-sleep instant
wake with the lid open. No reload/resume systemd hooks are installed.

## Build

Use the normal GitHub manual build, selecting:

- variant: `macbook9`
- cs4208_resume_test: enabled
- tag: a separate candidate tag, e.g. `audio-resume-test`
- publish: enabled only when ready to deploy the candidate

Equivalent local build argument: `--build-arg CS4208_RESUME_TEST=1` with
`Containerfile.macbook9`. Default is 0. The image rebuilds against its exact
kernel and validates the module metadata; the existing initramfs check validates
that the replacement module is included. MacBookAir/Asahi builds are unchanged.

Identify a candidate without unloading anything:

```sh
modinfo -F silverletter_audio_fix snd_hda_codec_cs420x
# cs4208-resume-order-v1
```

## Physical validation

Keep a known-working deployment for bootc rollback. Boot the candidate normally;
do not install or reload this module into a running kernel. Before any suspend,
confirm speaker and headphone playback, software volume, microphone recording,
and plug/unplug routing. Avoid loud test signals: these speakers use software
attenuation and the board replay changes hardware state.

Once baseline audio works, select deep sleep for this boot only:

```sh
echo deep | sudo tee /sys/power/mem_sleep
cat /sys/power/mem_sleep
```

Leave runtime audio power-saving and other settings unchanged. Test lid-close
sleep first; menu/open-lid sleep previously woke immediately. After each resume,
test both physical outputs and microphone, and inspect:

```sh
journalctl -k -b --no-pager | grep -E 'CS4208 resume-order|PM: suspend|Oops:|BUG:'
```

Exercise at least five cycles, both idle and active playback across suspend,
with headphones connected/disconnected and jack changes after wake. Then check
ordinary playback after idle and a clean reboot/shutdown. If a kernel Oops
occurs, stop testing and reboot; do not unbind/rebind or unload modules. Roll
back if the candidate regresses baseline behavior. Successful compilation does
not establish a working or safe-on-hardware fix.

If no `begin` marker appears after deep sleep, investigate callback invocation
before adding more codec commands. If `complete` appears but audio is silent,
the ordering hypothesis is insufficient: compare actual codec/amp state and
trace the resume path rather than claiming success from the logs.

References:

- https://github.com/leifliddy/macbook12-audio-driver/issues/48
- https://github.com/leifliddy/macbook12-audio-driver/issues/70
- https://github.com/torvalds/linux/blob/master/sound/hda/common/codec.c
