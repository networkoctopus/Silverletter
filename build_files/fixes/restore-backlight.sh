#!/bin/bash
# Author xortim, jirkafm
# Description Workaround for intel backlight brightness quirk.
# Script should be put into /usr/lib/systemd/system-sleep 

case "${1}" in
 post)
 echo 1 > /sys/class/backlight/intel_backlight/brightness
 cat /tmp/pre_suspend_brt > /sys/class/backlight/intel_backlight/brightness
 ;;
 pre)
 cat /sys/class/backlight/intel_backlight/brightness > /tmp/pre_suspend_brt
 ;;
 *)
 exit 1
esac
