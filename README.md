# LinuxBook-Air

A practical, immutable Fedora GNOME image for Intel MacBook Airs, built on [Universal Blue's `silverblue-main`](https://github.com/ublue-os/main).

LinuxBook-Air aims to feel like stock Fedora GNOME while making an older MacBook a better Linux laptop: Mac-style keyboard shortcuts, working Broadcom Wi-Fi and FaceTime HD camera support, automatic transactional updates, sensible fan control, and aggressive power and boot-time tuning.

This image has been my daily workhorse for three months, so I decided it was time to share it.

> [!IMPORTANT]
> **Thunderbolt is intentionally disabled to save power.** Treat the Thunderbolt/Mini DisplayPort port as unsupported: attached devices and some display configurations may not work. If you rely on that port, this image is not currently for you. If you do not, disabling it can save multiple watts.

## What you get

- A mostly stock Fedora GNOME experience on the Universal Blue Silverblue base
- Mac-like shortcuts provided by [Toshy](https://github.com/RedBearAK/Toshy)
- Broadcom Wi-Fi and FaceTime HD camera drivers baked into the image
- [mbpfan](https://github.com/linux-on-mac/mbpfan) for MacBook fan control
- [uupd](https://github.com/ublue-os/uupd) automatic image and Flatpak updates
- The [uupd Indicator](https://github.com/Vyachean/uupd-indicator) GNOME extension, including restart-required notifications
- Wi-Fi power saving, PowerTOP auto-tuning, PCIe ASPM tuning, and Mac-specific sleep/wake fixes
- A deliberately smaller, hardware-focused initramfs; on the test machine this reduced boot time from 40 seconds to about 25 seconds
- A first-run GUI which installs Toshy and the standard GNOME Flatpak applications; Firefox is already included in the image

At 50% display brightness with Wi-Fi enabled, the test 11 inch machine typically draws around **4.5 W**. That is an observed figure, not a guarantee: battery condition, workload, radio activity, peripherals, and exact hardware all matter. (For reference when cranking brightness to minimum power usage is **3.3-3.5 W** ).

Because bootc updates are applied on reboot, the faster boot was worth pursuing even more than it would be on a traditional Fedora installation.

## Hardware compatibility

The image is developed and daily-tested on a **2015 MacBook Air (`MacBookAir7,1`)**. Its initramfs and power configuration are intentionally tailored to this generation.

These closely related Intel MacBook Airs are reasonable candidates, but are **untested unless stated otherwise**:

| Model identifier | Apple model | Confidence |
| --- | --- | --- |
| `MacBookAir7,1` | 11-inch, Early 2015 | Daily-tested target |
| `MacBookAir7,2` | 13-inch, Early 2015 or 2017 | Closest sibling; likely candidate |
| `MacBookAir6,1` | 11-inch, Mid 2013 or Early 2014 | Similar generation; untested |
| `MacBookAir6,2` | 13-inch, Mid 2013 or Early 2014 | Similar generation; untested |
| `MacBookAir5,1` | 11-inch, Mid 2012 | Earlier related hardware; least certain |
| `MacBookAir5,2` | 13-inch, Mid 2012 (`A1466`) | Earlier related chassis; least certain |

Check your identifier from Linux with:

```bash
cat /sys/class/dmi/id/product_name
```

Do not assume that other MacBooks or MacBook Pros are compatible merely because they are from the same year. The trimmed initramfs omits drivers and storage features this specific machine does not need, including LVM, MD RAID, encrypted-root support, and several GPU/storage drivers.

## Switch from another bootc system

If you already run a bootc-managed system, inspect its current state first:

```bash
sudo bootc status
```

Then switch to LinuxBook Air and reboot into the new deployment:

```bash
sudo bootc switch ghcr.io/networkoctopus/linuxbook-air:latest
sudo systemctl reboot
```

After rebooting, verify the booted image:

```bash
sudo bootc status
```

The switch replaces the operating-system image but keeps the data in `/var`, including home directories. Even so, make a backup first. Layered packages or local system changes from a substantially different image may need to be removed before switching.

If the new deployment does not suit your machine, boot the previous deployment from the boot menu or roll back:

```bash
sudo bootc rollback
sudo systemctl reboot
```

## Install with the Anaconda ISO

The installer ISO is built once a week. Open the [Build disk images workflow](https://github.com/networkoctopus/LinuxBook-Air/actions/workflows/build-iso.yml), select the newest successful scheduled run, and download the artifact from the **Artifacts** section at the bottom of the run page. Extract the downloaded archive to get the Anaconda ISO, then write it to a USB drive with your preferred image writer.

GitHub requires you to be signed in to download workflow artifacts. There is no permanent URL for the newest artifact, so the workflow page above is the stable link.

> [!CAUTION]
> Installing an operating system can erase the selected disk. Back up anything important and carefully confirm the target drive in Anaconda.

After the first login, the LinuxBook Air setup window appears on a later graphical login. It offers to install Toshy and restore the standard GNOME Flatpak application set. You can complete the setup, postpone it, or permanently skip it.

## Updates

The bootc image is rebuilt **twice weekly**, every Wednesday and Sunday. The installer ISO is rebuilt **once weekly**, every Sunday. Builds can also be started manually, so the Actions history may contain additional runs.

`uupd` checks for and stages operating-system and Flatpak updates automatically. The panel indicator shows update activity and tells you when a reboot is needed to enter the newly staged deployment.

## Check the power tuning

The image includes an audit tool which checks the installed power configuration and reports tunables that are active, missing, or unexpected:

```bash
sudo power-audit.sh
```

This is a diagnostic report, not a battery benchmark. For live consumption figures, run PowerTOP on battery after the machine has settled:

```bash
sudo powertop
```

## Known issues

### Wi-Fi may disconnect during sustained heavy downloads

Very occasionally—roughly once every couple of weeks on the test machine—the Wi-Fi connection may stop during a heavy but otherwise successful download. Rejoining the network restores the connection. This appears to be caused by the image enabling Wi-Fi power saving.

If the extra efficiency is not worth the occasional interruption, create a NetworkManager override:

```bash
sudo nano /etc/NetworkManager/conf.d/wifi-powersave.conf
```

Add the following content and save the file:

```ini
[connection]
wifi.powersave = 2
```

Then apply it:

```bash
sudo nmcli connection reload
sudo systemctl restart NetworkManager
```

Disabling Wi-Fi power saving increased observed consumption by approximately **0.5–0.8 W** on the test machine.

### Rare failure to resume from suspend

The test machine has once failed to return from suspend and required a hard reboot. The cause has not yet been identified or reproduced reliably.

## To do

- Add the [MacTahoe GTK theme](https://github.com/vinceliuice/MacTahoe-gtk-theme) and related desktop theming

## Built with

- [Universal Blue `silverblue-main`](https://github.com/ublue-os/main) — Fedora Silverblue base image
- [Universal Blue akmods](https://github.com/ublue-os/akmods) — prebuilt Broadcom kernel-module packages
- [Toshy](https://github.com/RedBearAK/Toshy) — Mac-style keyboard shortcuts on Linux
- [uupd](https://github.com/ublue-os/uupd) — automatic transactional updates
- [uupd Indicator](https://github.com/Vyachean/uupd-indicator) — GNOME update and restart notifications
- [mbpfan](https://github.com/linux-on-mac/mbpfan) — fan control for Apple laptops
- [FaceTime HD driver](https://github.com/patjak/facetimehd) and [firmware extractor](https://github.com/patjak/facetimehd-firmware) — built-in camera support
- [bootc](https://github.com/bootc-dev/bootc) — transactional, image-based operating-system delivery

## Disclaimer

Have fun, but there are no warranties. This is a personal project shared in the hope that it is useful. It makes deliberate hardware trade-offs, has only been validated on the test machine, and may fail to boot or work correctly elsewhere. Keep backups and know how to select an earlier deployment before experimenting.
