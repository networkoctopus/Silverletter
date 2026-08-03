#!/bin/bash
# Disable d3cold for the SATA controller to fix resume hang on MacBookAir7,1
# Ref: https://github.com/Dunedan/mbp-2016-linux/issues/37#issuecomment-540202102
echo 0 > /sys/bus/pci/devices/0000:04:00.0/d3cold_allowed