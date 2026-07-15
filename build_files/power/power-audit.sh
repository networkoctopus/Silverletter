#!/bin/bash
# power-audit.sh — MacBook Air power tuning audit
# Run as root: sudo ./power-audit.sh

PASS="\033[01;32m PASS\033[00m"
FAIL="\033[01;31m FAIL\033[00m"
WARN="\033[01;33m WARN\033[00m"
INFO="\033[01;34m INFO\033[00m"
HEADER="\033[01;36m"
RESET="\033[00m"

ISSUES=0

header() {
    echo -e "\n${HEADER}══════════════════════════════════════════${RESET}"
    echo -e "${HEADER}  $1${RESET}"
    echo -e "${HEADER}══════════════════════════════════════════${RESET}"
}

pass()  { echo -e "  [${PASS} ] $1"; }
fail()  { echo -e "  [${FAIL} ] $1"; ISSUES=$((ISSUES+1)); }
warn()  { echo -e "  [${WARN} ] $1"; }
info()  { echo -e "  [${INFO} ] $1"; }

if [[ $(id -u) != 0 ]]; then
    echo "Run as root: sudo $0"
    exit 1
fi

TB_FEATURE_INSTALLED=0
if [[ -x /usr/libexec/linuxbook-air-thunderbolt-control ]]; then
    TB_FEATURE_INSTALLED=1
fi

# ─── PRE-FLIGHT CHECKLIST ──────────────────────────────────────────────────
echo -e "\n${HEADER}╔══════════════════════════════════════════╗${RESET}"
echo -e "${HEADER}║     MacBook Air Power Audit — Setup      ║${RESET}"
echo -e "${HEADER}╚══════════════════════════════════════════╝${RESET}"
echo -e "\nFor accurate power readings, please do the following before continuing:\n"
echo -e "  \033[01;33m1.\033[00m  Disconnect the charger (must run on battery)"
echo -e "  \033[01;33m2.\033[00m  Set screen brightness to ~50%"
echo -e "  \033[01;33m3.\033[00m  Quit all other applications\n"

# Check if already on battery
if [[ -f /sys/class/power_supply/BAT0/status ]]; then
    bat_status=$(cat /sys/class/power_supply/BAT0/status)
    if [[ "$bat_status" == "Discharging" ]]; then
        echo -e "  \033[01;32m[OK] Charger is disconnected (discharging)\033[00m\n"
    else
        echo -e "  \033[01;31m[!!] Charger appears to be connected (status: $bat_status)\033[00m"
        echo -e "      Please disconnect it for accurate power readings.\n"
    fi
fi

read -r -p "Press Enter when ready to begin the audit, or Ctrl+C to cancel... "
echo ""

echo -e "\n${HEADER}MacBook Air Power Tuning Audit${RESET}"
echo -e "$(date)"
echo -e "Kernel: $(uname -r)"
echo -e "Host:   $(hostname)"

# ─── 1. KERNEL ARGUMENTS ───────────────────────────────────────────────────
header "Kernel Arguments"

if grep -q 'acpi_osi=!Darwin' /proc/cmdline; then
    pass "acpi_osi=!Darwin is active"
else
    fail "acpi_osi=!Darwin is NOT in /proc/cmdline"
fi

if [[ $TB_FEATURE_INSTALLED -eq 1 ]] && grep -q 'pci=hpbussize=8' /proc/cmdline; then
    pass "pci=hpbussize=8 is active (Thunderbolt hot-plug bus space reserved)"
elif [[ $TB_FEATURE_INSTALLED -eq 1 ]]; then
    fail "Thunderbolt control is installed but pci=hpbussize=8 is NOT in /proc/cmdline"
elif grep -q 'pci=hpbussize=8' /proc/cmdline; then
    warn "pci=hpbussize=8 is active although the optional Thunderbolt control is not installed"
else
    info "Optional Thunderbolt hot-plug bus reservation is not installed"
fi

info "Full cmdline: $(cat /proc/cmdline)"

if [[ -f /usr/lib/bootc/kargs.d/linuxbook-air.toml ]]; then
    pass "kargs.d toml exists: $(cat /usr/lib/bootc/kargs.d/linuxbook-air.toml)"
else
    fail "kargs.d toml missing at /usr/lib/bootc/kargs.d/linuxbook-air.toml"
fi

if [[ $TB_FEATURE_INSTALLED -eq 1 ]]; then
    if [[ -f /usr/lib/bootc/kargs.d/linuxbook-air-thunderbolt.toml ]]; then
        pass "Thunderbolt kargs.d toml exists: $(cat /usr/lib/bootc/kargs.d/linuxbook-air-thunderbolt.toml)"
    else
        fail "Thunderbolt kargs.d toml missing at /usr/lib/bootc/kargs.d/linuxbook-air-thunderbolt.toml"
    fi
fi

# ─── 2. CONFIG FILES ───────────────────────────────────────────────────────
header "Config Files"

FILES=(
    "/usr/lib/modprobe.d/thunderbolt-blacklist.conf"
    "/usr/lib/udev/rules.d/99-thunderbolt-pm.rules"
    "/usr/lib/systemd/system/linuxbook-air-thunderbolt-powerdown.service"
    "/usr/lib/NetworkManager/conf.d/default-wifi-powersave-on.conf"
    "/usr/lib/systemd/system/powertop.service"
    "/usr/lib/systemd/system/aspm-tune.service"
    #"/usr/lib/systemd/system/aspm-tune-resume.service"
    "/usr/bin/aspm-tune.sh"
)

if [[ $TB_FEATURE_INSTALLED -eq 1 ]]; then
    FILES+=(
        "/usr/libexec/linuxbook-air-thunderbolt-control"
        "/usr/lib/systemd/system/linuxbook-air-thunderbolt-sleep.service"
        "/usr/share/polkit-1/actions/io.github.networkoctopus.linuxbookair.thunderbolt.policy"
        "/usr/share/gnome-shell/extensions/thunderbolt@linuxbook-air.local/extension.js"
    )
fi

for f in "${FILES[@]}"; do
    if [[ -f "$f" ]]; then
        pass "$f"
    else
        fail "$f — MISSING"
    fi
done

# ─── 3. THUNDERBOLT ────────────────────────────────────────────────────────
header "Thunderbolt"

TB_ENABLED=0
if [[ -e /run/linuxbook-air/thunderbolt-enabled ]]; then
    TB_ENABLED=1
    info "Temporary Thunderbolt enable is active"
fi

if lsmod | grep -q '^thunderbolt '; then
    if [[ $TB_ENABLED -eq 1 ]]; then
        pass "thunderbolt module is loaded by the temporary enable control"
    else
        fail "thunderbolt module is LOADED without the temporary enable marker"
    fi
else
    if [[ $TB_ENABLED -eq 1 ]]; then
        fail "temporary enable marker exists but thunderbolt module is not loaded"
    else
        pass "thunderbolt module not loaded"
    fi
fi

if grep -q 'install thunderbolt /bin/false' /usr/lib/modprobe.d/thunderbolt-blacklist.conf 2>/dev/null; then
    if [[ $TB_FEATURE_INSTALLED -eq 1 ]]; then
        fail "Hard block (install thunderbolt /bin/false) prevents temporary enable"
    else
        pass "Hard Thunderbolt module block present"
    fi
elif grep -q 'blacklist thunderbolt' /usr/lib/modprobe.d/thunderbolt-blacklist.conf 2>/dev/null; then
    if [[ $TB_FEATURE_INSTALLED -eq 1 ]]; then
        pass "Soft blacklist present (automatic load blocked; explicit enable permitted)"
    else
        pass "Soft Thunderbolt module blacklist present"
    fi
else
    fail "thunderbolt-blacklist.conf missing or empty"
fi

# Thunderbolt PCIe devices runtime PM
header "Thunderbolt PCIe Runtime PM"
TB_DEVS=(
    "0000:05:00.0"
    "0000:06:00.0"
    "0000:06:03.0"
    "0000:06:04.0"
    "0000:06:05.0"
    "0000:06:06.0"
    "0000:07:00.0"
)
for dev in "${TB_DEVS[@]}"; do
    if [[ -e "/sys/bus/pci/devices/$dev" ]]; then
        ctrl=$(cat /sys/bus/pci/devices/$dev/power/control 2>/dev/null)
        status=$(cat /sys/bus/pci/devices/$dev/power/runtime_status 2>/dev/null)
        if [[ $TB_ENABLED -eq 0 ]]; then
            fail "$dev — still present (expected the Thunderbolt hierarchy to be removed)"
        elif [[ "$ctrl" == "on" ]]; then
            pass "$dev — control=$ctrl status=$status (temporarily enabled)"
        else
            fail "$dev — control=$ctrl (expected on while temporarily enabled) status=$status"
        fi
    else
        info "$dev — not present on PCIe bus (expected if TB fully off)"
    fi
done

# ─── 4. WIFI POWERSAVE ─────────────────────────────────────────────────────
header "WiFi Powersave"

if [[ -f /usr/lib/NetworkManager/conf.d/default-wifi-powersave-on.conf ]]; then
    content=$(cat /usr/lib/NetworkManager/conf.d/default-wifi-powersave-on.conf)
    if echo "$content" | grep -q 'wifi.powersave.*[23]'; then
        pass "WiFi powersave config present and set correctly"
        info "Content: $content"
    else
        warn "WiFi powersave config present but check value (expect 2 or 3)"
        info "Content: $content"
    fi
else
    fail "WiFi powersave config missing"
fi

# Check actual interface state
iface=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
if [[ -n "$iface" ]]; then
    ps_state=$(iw dev "$iface" get power_save 2>/dev/null)
    if echo "$ps_state" | grep -q 'on'; then
        pass "WiFi power save ON on $iface"
    else
        warn "WiFi power save: $ps_state on $iface"
    fi
fi

# ─── 5. SYSTEMD SERVICES ───────────────────────────────────────────────────
header "Systemd Services"

SERVICES=(
    "powertop.service"
    "aspm-tune.service"
    "linuxbook-air-thunderbolt-powerdown.service"
    #"aspm-tune-resume.service"
)
if [[ $TB_FEATURE_INSTALLED -eq 1 ]]; then
    SERVICES+=("linuxbook-air-thunderbolt-sleep.service")
fi
for svc in "${SERVICES[@]}"; do
    enabled=$(systemctl is-enabled "$svc" 2>/dev/null)
    active=$(systemctl is-active "$svc" 2>/dev/null)

    if [[ "$enabled" == "enabled" ]]; then
        if [[ "$svc" == "powertop.service" ||
              "$svc" == "aspm-tune-resume.service" ||
              "$svc" == "linuxbook-air-thunderbolt-powerdown.service" ||
              "$svc" == "linuxbook-air-thunderbolt-sleep.service" ]]; then
            # Oneshot service — inactive after successful completion is normal.
            if [[ "$active" == "inactive" || "$active" == "active" ]]; then
                pass "$svc — enabled (oneshot, currently $active)"
            else
                fail "$svc — enabled but status: $active"
            fi
        elif [[ "$active" == "active" ]]; then
            pass "$svc — enabled and active"
        else
            fail "$svc — enabled but not active (status: $active)"
        fi
    else
        fail "$svc — NOT enabled (is-enabled: $enabled)"
    fi
done

# ─── 6. ASPM STATE ─────────────────────────────────────────────────────────
header "ASPM Link State"

aspm_enabled=0
aspm_disabled=0
current_addr=""

while IFS= read -r line; do
    if echo "$line" | grep -qP '^[0-9a-f]{2}:[0-9a-f]{2}\.[0-9a-f]'; then
        current_addr=$(echo "$line" | grep -oP '^[0-9a-f:.]+')
    fi
    if echo "$line" | grep -q 'LnkCtl:'; then
        # Extract everything from ASPM up to the semicolon e.g. "ASPM L0s L1 Enabled"
        aspm=$(echo "$line" | grep -oP 'ASPM [^;]+' | sed 's/[[:space:]]*$//')
        if echo "$aspm" | grep -q 'Disabled'; then
            warn "$current_addr — $aspm"
            aspm_disabled=$((aspm_disabled+1))
        elif echo "$aspm" | grep -q 'Enabled'; then
            pass "$current_addr — $aspm"
            aspm_enabled=$((aspm_enabled+1))
        fi
    fi
done < <(lspci -vv 2>/dev/null)

info "ASPM enabled: $aspm_enabled devices, disabled: $aspm_disabled devices"
if [[ $aspm_disabled -eq 0 && $aspm_enabled -gt 0 ]]; then
    pass "All $aspm_enabled ASPM-capable devices have ASPM enabled"
elif [[ $aspm_disabled -gt 0 ]]; then
    warn "$aspm_disabled device(s) have ASPM disabled"
fi

# ─── 7. PCIe RUNTIME PM ────────────────────────────────────────────────────
header "PCIe Runtime PM Summary"

total=0; auto=0; intentional_on=0; suspended=0; active_count=0
while IFS= read -r dev; do
    addr=$(basename "$dev")
    ctrl=$(cat "$dev/power/control" 2>/dev/null)
    status=$(cat "$dev/power/runtime_status" 2>/dev/null)
    total=$((total+1))
    [[ "$ctrl" == "auto" ]] && auto=$((auto+1))
    if [[ $TB_ENABLED -eq 1 && "$ctrl" == "on" && "$(readlink -f "$dev")" == *"/0000:05:00.0"* ]]; then
        intentional_on=$((intentional_on+1))
    fi
    [[ "$status" == "suspended" ]] && suspended=$((suspended+1))
    [[ "$status" == "active" ]] && active_count=$((active_count+1))
done < <(find /sys/bus/pci/devices -maxdepth 1 -mindepth 1)

info "Total PCIe devices: $total"
info "Runtime PM auto:    $auto / $total"
[[ $intentional_on -gt 0 ]] && info "Thunderbolt forced on: $intentional_on (temporary enable)"
info "Currently suspended: $suspended"
info "Currently active:    $active_count"

if [[ $((auto+intentional_on)) -eq $total ]]; then
    if [[ $intentional_on -gt 0 ]]; then
        pass "All non-Thunderbolt devices use runtime PM auto"
    else
        pass "All devices have runtime PM set to auto"
    fi
else
    warn "$((total-auto-intentional_on)) unexpected device(s) not set to auto runtime PM"
fi

# List any non-auto devices
for dev in /sys/bus/pci/devices/*; do
    addr=$(basename "$dev")
    ctrl=$(cat "$dev/power/control" 2>/dev/null)
    if [[ "$ctrl" != "auto" ]]; then
        name=$(lspci -s "$addr" 2>/dev/null | cut -d' ' -f3-)
        if [[ $TB_ENABLED -eq 1 && "$ctrl" == "on" && "$(readlink -f "$dev")" == *"/0000:05:00.0"* ]]; then
            info "  $addr — control=$ctrl — $name (temporary Thunderbolt enable)"
        else
            fail "  $addr — control=$ctrl — $name"
        fi
    fi
done

# ─── 8. PACKAGE C-STATES ───────────────────────────────────────────────────
header "CPU Package C-States (5s sample)"

if command -v turbostat &>/dev/null; then
    info "Sampling for 5 seconds..."
    turbostat --quiet --show Pkg%pc2,Pkg%pc3,Pkg%pc6,PkgWatt --interval 5 --num_iterations 1 2>/dev/null \
        | tail -n +2 | head -5
    pc6=$(turbostat --quiet --show Pkg%pc6 --interval 5 --num_iterations 1 2>/dev/null \
        | tail -1 | awk '{print $1}')
    if [[ -n "$pc6" ]]; then
        pc6_int=${pc6%.*}
        if (( pc6_int > 0 )); then
            pass "PC6 residency: ${pc6}%"
        else
            warn "PC6 residency: ${pc6}% — may improve after longer idle"
        fi
    fi
else
    warn "turbostat not available — install kernel-tools to check C-states"
fi

# ─── 9. POWER DRAW ─────────────────────────────────────────────────────────
header "Current Power Draw - waiting 10s for stable reading..."
sleep 10

if [[ -f /sys/class/power_supply/BAT0/power_now ]]; then
    power_uw=$(cat /sys/class/power_supply/BAT0/power_now)
    power_w=$(echo "scale=2; $power_uw / 1000000" | bc)
    status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
    info "Battery status: $status"
    if (( power_uw > 0 )); then
        if (( $(echo "$power_w < 5.0" | bc -l) )); then
            pass "Power draw: ${power_w}W (excellent)"
        elif (( $(echo "$power_w < 6.0" | bc -l) )); then
            warn "Power draw: ${power_w}W (acceptable, but room to improve)"
        else
            fail "Power draw: ${power_w}W (high — check what's keeping devices active)"
        fi
    else
        warn "power_now reads 0 — may be on AC with full battery"
    fi
else
    warn "BAT0 power_now not available"
fi

# ─── SUMMARY ───────────────────────────────────────────────────────────────
header "Summary"

if [[ $ISSUES -eq 0 ]]; then
    echo -e "  \033[01;32mAll checks passed — power tuning fully active.\033[00m"
else
    echo -e "  \033[01;31m$ISSUES issue(s) found — review FAIL entries above.\033[00m"
fi
echo ""
