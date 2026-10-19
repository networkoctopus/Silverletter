#!/bin/bash
# Disable D3cold for storage paths that cannot recover after suspend.
set -eu

readonly MODEL_HELPER="${SILVERLETTER_MODEL_HELPER:-/usr/libexec/silverletter-model}"
readonly PCI_ROOT="${SILVERLETTER_PCI_ROOT:-/sys/bus/pci/devices}"

model=$("$MODEL_HELPER" product-name) || {
    echo "Unable to identify this computer; skipping the storage D3cold workaround"
    exit 0
}

targets=()
case "$model" in
    MacBookAir7,1)
        # Ref: https://github.com/Dunedan/mbp-2016-linux/issues/37#issuecomment-540202102
        targets+=("0000:04:00.0")
        ;;
    MacBook9,1)
        # The Apple S3X NVMe controller and its parent root port both fail to
        # recover reliably from D3cold on this model. These two writes were
        # verified together on physical MacBook9,1 hardware.
        targets+=("0000:00:1c.0" "0000:01:00.0")
        ;;
    *)
        echo "Storage D3cold workaround is not required on $model; skipping"
        exit 0
        ;;
esac

# Validate every target before changing any of them.
for address in "${targets[@]}"; do
    d3cold_path="$PCI_ROOT/$address/d3cold_allowed"
    if [[ ! -w "$d3cold_path" ]]; then
        echo "Expected $model storage path is missing: $d3cold_path" >&2
        exit 1
    fi
done

if [[ "$model" == "MacBook9,1" ]]; then
    for device in \
        "0000:00:1c.0:0x8086:0x9d10" \
        "0000:01:00.0:0x106b:0x2003"; do
        IFS=: read -r domain bus slot_function expected_vendor expected_device <<< "$device"
        address="$domain:$bus:$slot_function"
        actual_vendor=$(<"$PCI_ROOT/$address/vendor")
        actual_device=$(<"$PCI_ROOT/$address/device")
        if [[ "$actual_vendor" != "$expected_vendor" || "$actual_device" != "$expected_device" ]]; then
            echo "Unexpected PCI device at $address on MacBook9,1; refusing D3cold workaround" >&2
            exit 1
        fi
    done
fi

for address in "${targets[@]}"; do
    echo 0 > "$PCI_ROOT/$address/d3cold_allowed"
done
