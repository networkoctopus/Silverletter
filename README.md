<h1>
  <img src="build_files/post-deploy-setup/silverletter-setup.svg" width="48" align="absmiddle">
  Silverletter
</h1>

**A love letter to 'old' hardware, delivered as a bootc image**

Silverletter is a bootable container, based on [Universal Blue's `silverblue-main`](https://github.com/ublue-os/main/pkgs/container/silverblue-main). It is intended for selected Intel-based MacBook Air computers and currently tracks [Fedora 44](https://fedoraproject.org).

Instead of relegating my 11-year-old, 11-inch laptop to the gap in my couch - I wanted a reliable, modern/secure out-of-box system with the necessary drivers included, kept close to its upstream base, and carefully tuned to **maximise battery life***.

This began as a playground for bootc using the excellent [Universal Blue image-template](https://github.com/ublue-os/image-template). It became my daily driver in early 2026 and eventually felt worth sharing.

## What's in this image - credits to the maintainers of these projects

- A mostly stock Fedora GNOME experience on Universal Blue's [`silverblue-main`](https://github.com/ublue-os/main)
- Broadcom Wi-Fi from [Universal Blue akmods](https://github.com/ublue-os/akmods), plus the [FaceTime HD driver](https://github.com/patjak/facetimehd) and [firmware extractor](https://github.com/patjak/facetimehd-firmware), baked in
- PCIe ASPM tuning, firmware compatibility tweaks, and a MacBook Air display wake fix, Automatic [PowerTOP](https://github.com/fenrus75/powertop) tuning, Wi-Fi power saving 
- A smaller, hardware-focused initramfs that reduced boot time from ~40 to ~25 seconds on my machine. The initramfs in [`silverblue-main`](https://github.com/ublue-os/main) is ~230MB+ whereas this image's initramfs is ~75MB. Since updates occur on restart, I figured the faster boot was worth pursuing. 
- Shortcuts familiar to macOS users, provided by the fantastic [Toshy](https://github.com/RedBearAK/Toshy) project
- A first-run Setup app that optionally installs Toshy, applies macOS-inspired themes to the desktop and Firefox, and restores the GNOME Flatpak apps from [Flathub](https://flathub.org/) that usually came with Silverblue. A separate option replaces existing system Flatpaks with Flathub equivalents when the same application ID is available (Firefox is already included in the image). The setup app can be re-run anytime to remove these additions.
- [mbpfan](https://github.com/linux-on-mac/mbpfan) for MacBook fan control
- [uupd](https://github.com/ublue-os/uupd) automatic image and Flatpak updates
- GNOME extensions installed and enabled system-wide: [AppIndicator and KStatusNotifierItem Support](https://extensions.gnome.org/extension/615/appindicator-support/), [Xremap](https://extensions.gnome.org/extension/5060/xremap/), [Vitals](https://extensions.gnome.org/extension/1460/vitals/), [User Themes](https://extensions.gnome.org/extension/19/user-themes/), [Dash to Dock](https://extensions.gnome.org/extension/307/dash-to-dock/), and the [uupd Indicator](https://github.com/Vyachean/uupd-indicator) with restart-required notifications
- A top-bar Thunderbolt status indicator (to remind you its currently in use*)
- [WhiteSur GTK, Shell, and GDM styling](https://github.com/vinceliuice/WhiteSur-gtk-theme), selectable [WhiteSur icons](https://github.com/vinceliuice/WhiteSur-icon-theme), [WhiteSur cursors](https://github.com/vinceliuice/WhiteSur-cursors), and [MacTahoe icons and cursors](https://github.com/vinceliuice/MacTahoe-icon-theme), optional [MacTahoe Firefox CSS](https://github.com/vinceliuice/MacTahoe-gtk-theme), and MacTahoe day/night wallpapers that follow dark mode, with the day image also used by GDM

## Hardware compatibility

The image is developed and daily-tested on a **2015 11" MacBook Air (`MacBookAir7,1`)**. Its initramfs and power configuration are intentionally tailored to this generation.

Do not assume that other MacBook or MacBook Pro computers are compatible. The trimmed initramfs omits drivers and storage features this specific machine does not need.

These closely related Intel-based MacBook Air computers are reasonable candidates, but are **untested unless stated otherwise**:

| Model identifier | Apple model | Confidence |
| --- | --- | --- |
| `MacBookAir7,1` | 11-inch, Early 2015 | Daily-tested target |
| `MacBookAir7,2` | 13-inch, Early 2015 or 2017 | Closest sibling; likely candidate |
| `MacBookAir6,1` | 11-inch, Mid 2013 or Early 2014 | Similar generation; untested |
| `MacBookAir6,2` | 13-inch, Mid 2013 or Early 2014 | Similar generation; untested |
| `MacBookAir5,1` | 11-inch, Mid 2012 | Earlier related hardware; least certain |
| `MacBookAir5,2` | 13-inch, Mid 2012 | Earlier related chassis; least certain |


## *Battery

One of my goals was to maximise battery life - this image includes a number of optimisations to help in this regard. My machine draws around **4–4.5 W**, or roughly 10 hours of battery life (50% display brightness with Wi-Fi enabled and no apps running).  With auto-brightness off and brightness at minimum, power usage drops to **3.3–3.5 W!**  (Not that I use my machine this way, just for reference)

One of the unnecessary power draws on this hardware is [unused Thunderbolt controllers](https://wiki.archlinux.org/title/Mac/Troubleshooting#Disabling_Thunderbolt)

So, Thunderbolt is powered down when unused and activates automatically when a device is connected. Hotplug and suspend/resume have been tested with an Apple Thunderbolt to Gigabit Ethernet Adapter; other Thunderbolt devices may work but are not guaranteed.

Thunderbolt control events are recorded in the system journal. For troubleshooting, run `sudo journalctl -b -t silverletter-thunderbolt`.

The image includes a diagnostic script that checks the power configuration and reports tunables that are active, missing, or unexpected:

```bash
sudo power-audit.sh
```


## Switch from another bootc system

If you already run a bootc-managed system, inspect its current state first:

```bash
sudo bootc status
```

Then switch to Silverletter and reboot into the new deployment:

```bash
sudo bootc switch ghcr.io/networkoctopus/silverletter:latest
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

The installer ISO is built weekly. Open the [Build disk images workflow](https://github.com/networkoctopus/Silverletter/actions/workflows/build-iso.yml), select the newest successful scheduled run, and download the artifact from the **Artifacts** section at the bottom of the run page. Extract the archive to get the Anaconda ISO, then write it to a USB drive with your preferred image writer.

This installer ISO is for supported x86-based Mac computers only.

Note: GitHub requires you to be signed in to download workflow artifacts.

> [!CAUTION]
> Installing an operating system will erase the selected disk. Back up anything important and carefully confirm the target drive in Anaconda.

## Updating

The `latest` image is rebuilt after pushes and **twice weekly**, every Wednesday and Sunday. 

`uupd` checks for and stages operating-system and Flatpak updates automatically. The panel indicator shows update activity and tells you when a reboot is needed to enter the staged deployment. GNOME Software updates are disabled because `uupd` handles them.


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

## Disclaimer

Have fun, but there are no warranties. This personal project is shared in the hope that it is useful. It has only been validated on the test machine, and may fail to boot or work correctly elsewhere. Keep backups and know how to select an earlier deployment before experimenting.

Silverletter is not provided or supported by Apple, Intel, Red Hat, the Fedora Project, Universal Blue, or the Asahi Linux project. Official Fedora software is available from the [Fedora Project](https://fedoraproject.org/).

Apple, Mac, MacBook Air, MacBook Pro, macOS, and Apple silicon are trademarks of Apple Inc. Intel and Thunderbolt are trademarks of Intel Corporation or its subsidiaries. Fedora is a trademark of Red Hat, Inc. Linux® is the registered trademark of Linus Torvalds in the U.S. and other countries.


## Experimental Apple silicon build using Fedora Asahi Remix

I liked using the above for my 'old' hardware I decided to try it out on my 'new' M2 machine. It's being tested using the experimental [Fedora Asahi Remix Atomic Silverblue image](https://github.com/fedora-asahi-remix-atomic-desktops/images). It shares the desktop customisations without applying the x86 hardware workarounds.

The image is published separately as:

```text
ghcr.io/networkoctopus/silverletter-asahi:testing
```
