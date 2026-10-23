#!/bin/bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
model_helper="$repo_root/build_files/hardware/silverletter-model"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

mkdir -p "$test_root/dmi"

assert_profile() {
    local product_name=$1 expected_profile=$2
    printf '%s\n' "$product_name" > "$test_root/dmi/product_name"
    actual=$(SILVERLETTER_DMI_ROOT="$test_root/dmi" "$model_helper" identify)
    [[ "$actual" == "$expected_profile" ]]
}

assert_profile MacBookAir7,1 macbookair7
SILVERLETTER_DMI_ROOT="$test_root/dmi" "$model_helper" require MacBookAir7,1
! SILVERLETTER_DMI_ROOT="$test_root/dmi" "$model_helper" require MacBook9,1

assert_profile MacBook9,1 macbook9
SILVERLETTER_DMI_ROOT="$test_root/dmi" "$model_helper" require MacBook9,1
! SILVERLETTER_DMI_ROOT="$test_root/dmi" "$model_helper" require MacBookAir7,1

assert_profile OtherComputer1,1 unknown
! SILVERLETTER_DMI_ROOT="$test_root/dmi" "$model_helper" require MacBookAir7,1
! SILVERLETTER_DMI_ROOT="$test_root/dmi" "$model_helper" require MacBook9,1

for guarded_script in \
    build_files/power/aspm-tune.sh \
    build_files/power/tb-powerdown.sh \
    build_files/fixes/fix-macbook-wakeup \
    build_files/thunderbolt-extension/silverletter-thunderbolt-control; do
    grep -q 'silverletter-model require MacBookAir7,1' \
        "$repo_root/$guarded_script"
done

# The storage workaround supports both models and must be present in the
# dedicated image. Other power and suspend fixes remain Air-only.
grep -q 'MacBookAir7,1)' "$repo_root/build_files/fixes/fix-sleep.sh"
grep -q 'MacBook9,1)' "$repo_root/build_files/fixes/fix-sleep.sh"
grep -q '/ctx/30-fixes.sh' "$repo_root/Containerfile.macbook9"

# Exercise the MacBook9,1 profile against an isolated sysfs tree.
mkdir -p \
    "$test_root/pci/0000:00:1c.0" \
    "$test_root/pci/0000:01:00.0"
printf '0x8086\n' > "$test_root/pci/0000:00:1c.0/vendor"
printf '0x9d10\n' > "$test_root/pci/0000:00:1c.0/device"
printf '1\n' > "$test_root/pci/0000:00:1c.0/d3cold_allowed"
printf '0x106b\n' > "$test_root/pci/0000:01:00.0/vendor"
printf '0x2003\n' > "$test_root/pci/0000:01:00.0/device"
printf '1\n' > "$test_root/pci/0000:01:00.0/d3cold_allowed"
printf 'MacBook9,1\n' > "$test_root/dmi/product_name"
SILVERLETTER_DMI_ROOT="$test_root/dmi" \
SILVERLETTER_MODEL_HELPER="$model_helper" \
SILVERLETTER_PCI_ROOT="$test_root/pci" \
    bash "$repo_root/build_files/fixes/fix-sleep.sh"
[[ "$(<"$test_root/pci/0000:00:1c.0/d3cold_allowed")" == 0 ]]
[[ "$(<"$test_root/pci/0000:01:00.0/d3cold_allowed")" == 0 ]]

# An unexpected controller identity must fail before either setting changes.
printf '1\n' > "$test_root/pci/0000:00:1c.0/d3cold_allowed"
printf '1\n' > "$test_root/pci/0000:01:00.0/d3cold_allowed"
printf '0xffff\n' > "$test_root/pci/0000:01:00.0/device"
! SILVERLETTER_DMI_ROOT="$test_root/dmi" \
SILVERLETTER_MODEL_HELPER="$model_helper" \
SILVERLETTER_PCI_ROOT="$test_root/pci" \
    bash "$repo_root/build_files/fixes/fix-sleep.sh" 2>/dev/null
[[ "$(<"$test_root/pci/0000:00:1c.0/d3cold_allowed")" == 1 ]]
[[ "$(<"$test_root/pci/0000:01:00.0/d3cold_allowed")" == 1 ]]

# Preserve the existing MacBookAir7,1 target while sharing the service.
mkdir -p "$test_root/pci/0000:04:00.0"
printf '1\n' > "$test_root/pci/0000:04:00.0/d3cold_allowed"
printf 'MacBookAir7,1\n' > "$test_root/dmi/product_name"
SILVERLETTER_DMI_ROOT="$test_root/dmi" \
SILVERLETTER_MODEL_HELPER="$model_helper" \
SILVERLETTER_PCI_ROOT="$test_root/pci" \
    bash "$repo_root/build_files/fixes/fix-sleep.sh"
[[ "$(<"$test_root/pci/0000:04:00.0/d3cold_allowed")" == 0 ]]

! grep -q '/ctx/20-power.sh' "$repo_root/Containerfile.macbook9"
! grep -q '/ctx/25-thunderbolt-extension.sh' "$repo_root/Containerfile.macbook9"

# The Bluetooth rebuild must refuse other profiles before accessing the
# toolchain, downloading sources, or installing modules.
for profile in macbookair7 asahi unknown; do
    ! SILVERLETTER_HARDWARE_PROFILE="$profile" \
        bash "$repo_root/build_files/bluetooth/build-bluetooth.sh" invalid-kernel
done

echo "hardware gating checks passed"
