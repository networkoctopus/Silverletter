# MacBook9,1 hardware baseline

Captured 2026-10-19 on the physical 2016 12-inch Retina MacBook before changing the image. Commands were read-only except for a live Wi-Fi driver probe. No reboot or suspend was performed.

## System and deployment

- DMI product: `Apple Inc. MacBook9,1`. Unique serial, network, storage, and host identifiers are intentionally not recorded.
- Fedora Silverblue 44.20261014.0, kernel `7.2.9-201.fc44.x86_64`.
- Booted image: `ghcr.io/networkoctopus/silverletter:latest`, digest `sha256:f8b5994918be66d82d0c50d980d736f3218ee65235b0886d467da3f5c6aff6c6`.
- Active image arguments included `acpi_osi=!Darwin` and `pci=hpbussize=8`.
- The deployment had the `code` package layered. `bootc status` consequently reported the booted deployment as incompatible; the unlayered image was retained as rollback deployment.

## Evidence and disposition

| Device or control | Baseline evidence and classification | Image change | Validation |
| --- | --- | --- | --- |
| Internal keyboard/trackpad | ACPI `APP000D` enumerated; `intel-lpss`, `spi_pxa2xx_platform`, and in-tree `applespi` loaded from the initramfs. Only `Apple SPI Keyboard` registered, no touchpad registered, and `applespi` logged `Command 1 timed out`. This is failed initialization, not a missing module or libinput configuration. A live unload blocked while draining the stuck transaction, so a reload service is unsafe. | Dedicated image explicitly includes the in-tree SPI modules and omits the Air's `acpi_osi=!Darwin`, allowing the kernel's Apple/Darwin ACPI path. No DKMS driver or global `irqpoll` workaround. | Required modules verified in the built image and initramfs; physical boot pending. |
| Wi-Fi | PCI `14e4:43a3`, subsystem `106b:0158` (BCM4350). `broadcom-wl` blacklisted `brcmfmac`; proprietary `wl` then failed with code 13 and left the device unbound. | Omit `broadcom-wl` and its blacklist; retain Fedora `brcmfmac-firmware`. | Live `brcmfmac` probe bound successfully, created `wlp2s0`, loaded `brcmfmac4350c2-pcie.bin`, and scanned 2.4/5 GHz networks. Association/resume pending. |
| Lid switch | `PNP0C0D` registered as a libinput switch and reported open. Default logind policy suspends on lid close and ignores it while docked; GNOME may hold a low-level inhibitor and take over policy. | No speculative policy override. | Enumeration verified; close/open event and policy pending because suspend was prohibited during investigation. |
| USB-C | xHCI hub, USB keyboard/mouse, Realtek USB Ethernet, mass storage, billboard device, and AC charging were present. The machine has no Thunderbolt PCI hierarchy. | Omit Thunderbolt blacklist, teardown, hot-plug argument, service, and UI. | USB data, Ethernet, and charging observed live; display alt mode pending. |
| Fan control | Apple SMC reported `fan=0`; `mbpfan` repeatedly failed with “could not detect any fan.” | Do not install `mbpfan` in the fanless MacBook9,1 image. Air service gains an exact-DMI execution guard. | Live root cause and image contents verified. |
| Air sleep workaround | Air-only `fix-sleep.service` attempted fixed PCI address `04:00.0`, which does not exist, and failed. | Omit Air fixes from MacBook9,1. Air scripts now require exact `MacBookAir7,1` DMI before fixed-address operations. | Live root cause verified; gating tests added. |
| Air ASPM override | The fixed address list modified MacBook9,1 root port `00:1c.0`, Wi-Fi `02:00.0`, and camera `03:00.0` solely because their addresses overlapped. | Omit from MacBook9,1 and exact-DMI gate the Air script. | Existing unintended writes observed in service log; gating tests added. |
| Bluetooth | UART BCM4350C0 controller enumerated, powered on, and unblocked. Kernel requested optional `brcm/BCM.hcd`, which Fedora does not ship for this board. | No external firmware added without a confirmed functional failure and redistributable provenance. | Controller state verified; pairing pending. |
| Audio | CS4208 analog playback/capture plus HDMI devices enumerated under `snd_hda_intel`. | None. | Enumeration only; speakers, headphone, and microphone pending. |
| Camera | PCI `14e4:1570` bound to `facetimehd`; firmware loaded and full memory verification succeeded. | Retain existing camera build. | Driver/firmware initialization verified; video capture pending. |
| Display and brightness | Intel HD 515 bound to `i915`; ACPI video input and backlight infrastructure enumerated. | None. | Enumeration only; brightness keys and external display pending. |
| Storage/battery | Apple S3X NVMe bound to `nvme`; battery capacity/status and AC adapter were reported. | Keep full MacBook9,1 initramfs rather than the Air-specific trim. | Root storage and charging active; suspend/resume pending. |

## Upstream references

- Linux's in-tree [`applespi` driver](https://github.com/torvalds/linux/blob/master/drivers/input/keyboard/applespi.c) enables the SPI interface through ACPI and contains the MacBook8/9/10 touchpad model geometry.
- The kernel's [`acpi_osi` documentation](https://github.com/torvalds/linux/blob/master/Documentation/admin-guide/kernel-parameters.txt) confirms that `acpi_osi=!Darwin` removes that OS interface string. The live kernel also reported that its normal Apple DMI rule had enabled Darwin before the image argument suppressed the query.
- [Linux Wireless brcmfmac documentation](https://wireless.docs.kernel.org/en/latest/en/users/drivers/brcm80211.html) describes the in-tree full-MAC driver and firmware/NVRAM behavior.
- Fedora 44's maintained [`brcmfmac-firmware` package](https://packages.fedoraproject.org/pkgs/linux-firmware/brcmfmac-firmware/fedora-44-updates.html) contains the BCM4350 PCIe firmware used successfully in the live probe.
- [`logind.conf`](https://www.freedesktop.org/software/systemd/man/latest/logind.conf.html) documents lid-close behavior, docked/external-display handling, and desktop-environment inhibitor ownership.
