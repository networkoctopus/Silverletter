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
    build_files/fixes/fix-sleep.sh \
    build_files/fixes/fix-macbook-wakeup \
    build_files/thunderbolt-extension/silverletter-thunderbolt-control; do
    grep -q 'silverletter-model require MacBookAir7,1' \
        "$repo_root/$guarded_script"
done

# The MacBook9,1 build must not invoke any Air-only configuration stage.
! grep -q '/ctx/20-power.sh' "$repo_root/Containerfile.macbook9"
! grep -q '/ctx/25-thunderbolt-extension.sh' "$repo_root/Containerfile.macbook9"
! grep -q '/ctx/30-fixes.sh' "$repo_root/Containerfile.macbook9"

echo "hardware gating checks passed"
