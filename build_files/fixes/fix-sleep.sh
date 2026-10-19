#!/bin/bash
# Disable d3cold for the SATA controller to fix resume hang on MacBookAir7,1
# Ref: https://github.com/Dunedan/mbp-2016-linux/issues/37#issuecomment-540202102
set -eu

if ! /usr/libexec/silverletter-model require MacBookAir7,1; then
    echo "d3cold workaround is only supported on MacBookAir7,1; skipping"
    exit 0
fi

readonly D3COLD_PATH=/sys/bus/pci/devices/0000:04:00.0/d3cold_allowed
if [[ ! -w "$D3COLD_PATH" ]]; then
    echo "Expected MacBookAir7,1 storage controller is missing: $D3COLD_PATH" >&2
    exit 1
fi

echo 0 > "$D3COLD_PATH"
