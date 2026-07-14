<h1>
  <img src="build_files/post-deploy-setup/linuxbook-air-setup.svg" width="48" align="absmiddle">
  LinuxBook-Air
</h1>

An immutable Fedora GNOME image for the Intel MacBook Air, built on [Universal Blue's `silverblue-main`](https://github.com/ublue-os/main/pkgs/container/silverblue-main). Currently tracking [Fedora 44](https://fedoraproject.org).

Instead of layering required packages onto stock Silverblue — which isn't the preferred convention with bootc/rpm-ostree - I created this instead. Along with serving as a playground on bootc - this became my daily driver since early 2026 - so I decided it was worth sharing.

This little project started with the great [Universal Blue image-template](https://github.com/ublue-os/image-template). The aim was to create a reliable out-of-box Fedora Silverblue experience on my 11-year-old, 11-inch Mac: all drivers included, kept close to stock GNOME, with a particular focus on **maximising battery life**.

At 50% display brightness with Wi-Fi enabled and no apps open, my machine draws around **4–4.5 W**, or roughly 10 hours of battery life (if you aren't doing anything else, of course :P).  Not that I use my machine this way, but for reference - with auto-brightness off and brightness at minimum, power usage drops to **3.3–3.5 W!**  Battery condition, open apps, Wi-Fi usage, peripherals, and exact hardware all contribute.

> [!IMPORTANT]
> **Thunderbolt is disabled by default to save power.** The top-bar Thunderbolt indicator can temporarily enable it for the current boot. The icon is white while disabled and red while enabled as a reminder of the substantially higher power use. Disconnect Thunderbolt storage before disabling the port.

Thunderbolt control events are recorded in the system journal. For troubleshooting, run `sudo journalctl -b -t linuxbook-air-thunderbolt`.

## What's in this image - credits to the maintainers of these projects

- A mostly stock Fedora GNOME experience on Universal Blue's [`silverblue-main`](https://github.com/ublue-os/main), delivered as a [bootc](https://github.com/bootc-dev/bootc) image
- Broadcom Wi-Fi from [Universal Blue akmods](https://github.com/ublue-os/akmods), plus the [FaceTime HD driver](https://github.com/patjak/facetimehd) and [firmware extractor](https://github.com/patjak/facetimehd-firmware), baked in
- PCIe ASPM tuning, firmware compatibility tweaks, and a MacBook Air display wake fix, Automatic [PowerTOP](https://github.com/fenrus75/powertop) tuning, Wi-Fi power saving 
- A smaller, hardware-focused initramfs that reduced boot time from ~40 to ~25 seconds on my machine. The initramfs in [`silverblue-main`](https://github.com/ublue-os/main) is ~230MB+ whereas this image's initramfs is ~75MB. Since updates occur on restart, I figured the faster boot was worth pursuing. 
- Mac-like shortcuts provided by the fantastic [Toshy](https://github.com/RedBearAK/Toshy) project
- A first-run Setup app that optionally installs Toshy, applies Mac style themes to the desktop and Firefox - aswell as restore the GNOME Flatpak apps from [Flathub](https://flathub.org/) that usually came with Silverblue (Firefox is already included in the image). The setup app can be re-run anytime to remove these additions.
- [mbpfan](https://github.com/linux-on-mac/mbpfan) for MacBook fan control
- [uupd](https://github.com/ublue-os/uupd) automatic image and Flatpak updates
- GNOME extensions installed and enabled system-wide: [AppIndicator and KStatusNotifierItem Support](https://extensions.gnome.org/extension/615/appindicator-support/), [Xremap](https://extensions.gnome.org/extension/5060/xremap/), [Vitals](https://extensions.gnome.org/extension/1460/vitals/), [User Themes](https://extensions.gnome.org/extension/19/user-themes/), [Dash to Dock](https://extensions.gnome.org/extension/307/dash-to-dock/), and the [uupd Indicator](https://github.com/Vyachean/uupd-indicator) with restart-required notifications
- A top-bar Thunderbolt control that keeps the port powered down by default and can temporarily enable it after administrator authentication; rebooting restores the power-saving default
- [WhiteSur GTK, Shell, and GDM styling](https://github.com/vinceliuice/WhiteSur-gtk-theme), selectable [WhiteSur icons](https://github.com/vinceliuice/WhiteSur-icon-theme), [WhiteSur cursors](https://github.com/vinceliuice/WhiteSur-cursors), and [MacTahoe icons and cursors](https://github.com/vinceliuice/MacTahoe-icon-theme), optional [MacTahoe Firefox CSS](https://github.com/vinceliuice/MacTahoe-gtk-theme), and MacTahoe day/night wallpapers that follow dark mode, with the day image also used by GDM


## Hardware compatibility

The image is developed and daily-tested on a **2015 11" MacBook Air (`MacBookAir7,1`)**. Its initramfs and power configuration are intentionally tailored to this generation.

These closely related Intel MacBook Airs are reasonable candidates, but are **untested unless stated otherwise**:

| Model identifier | Apple model | Confidence |
| --- | --- | --- |
| `MacBookAir7,1` | 11-inch, Early 2015 | Daily-tested target |
| `MacBookAir7,2` | 13-inch, Early 2015 or 2017 | Closest sibling; likely candidate |
| `MacBookAir6,1` | 11-inch, Mid 2013 or Early 2014 | Similar generation; untested |
| `MacBookAir6,2` | 13-inch, Mid 2013 or Early 2014 | Similar generation; untested |
| `MacBookAir5,1` | 11-inch, Mid 2012 | Earlier related hardware; least certain |
| `MacBookAir5,2` | 13-inch, Mid 2012 | Earlier related chassis; least certain |

Do not assume that other MacBooks or MacBook Pros are compatible. The trimmed initramfs omits drivers and storage features this specific machine does not need.

## Switch from another bootc system

If you already run a bootc-managed system, inspect its current state first:

```bash
sudo bootc status
```

Then switch to LinuxBook-Air and reboot into the new deployment:

```bash
sudo bootc switch ghcr.io/networkoctopus/linuxbook-air:latest
sudo systemctl reboot
```

After rebooting, verify the booted image:

```bash
sudo bootc status
```

The switch replaces the operating-system image but keeps data in `/var`, including home directories. Make a backup first. Layered packages or local system changes from a substantially different image may need to be removed before switching.

If the new deployment does not suit your machine, boot the previous deployment from the boot menu or roll back:

```bash
sudo bootc rollback
sudo systemctl reboot
```

## Install with the Anaconda ISO

The installer ISO is built weekly. Open the [Build disk images workflow](https://github.com/networkoctopus/LinuxBook-Air/actions/workflows/build-iso.yml), select the newest successful scheduled run, and download the artifact from the **Artifacts** section at the bottom of the run page. Extract the archive to get the Anaconda ISO, then write it to a USB drive with your preferred image writer.

Note: GitHub requires you to be signed in to download workflow artifacts.

> [!CAUTION]
> Installing an operating system will erase the selected disk. Back up anything important and carefully confirm the target drive in Anaconda.

## Updating

The bootc image is rebuilt **twice weekly**, every Wednesday and Sunday. Manual builds may also appear in the Actions history.

`uupd` checks for and stages operating-system and Flatpak updates automatically. The panel indicator shows update activity and tells you when a reboot is needed to enter the staged deployment. GNOME Software updates are disabled because `uupd` handles them.

## Check the power tuning

The image includes a diagnostic script that checks the power configuration and reports tunables that are active, missing, or unexpected:

```bash
sudo power-audit.sh
```

## Known issues

### Wi-Fi may disconnect during sustained heavy downloads

Very occasionally—roughly once every couple of weeks on the test machine—Wi-Fi may disconnect during a heavy download. Rejoining the network restores it. This appears to be caused by Wi-Fi power saving, which saves around **0.5–0.8 W**.

To revert, create a NetworkManager override which MAY help:

```bash
sudo nano /etc/NetworkManager/conf.d/wifi-powersave.conf
```

Add and save:

```ini
[connection]
wifi.powersave = 2
```

Then apply it:

```bash
sudo nmcli connection reload
sudo systemctl restart NetworkManager
```

### Rare failure to resume from suspend

The test machine once failed to return from suspend and required a hard reboot. The cause has not been identified or reproduced reliably.

## To do

- Add an option to the Setup app to toggle all power tunings

## Disclaimer

Have fun, but there are no warranties. This personal project is shared in the hope that it is useful. It makes deliberate hardware trade-offs, has only been validated on the test machine, and may fail to boot or work correctly elsewhere. Keep backups and know how to select an earlier deployment before experimenting.
