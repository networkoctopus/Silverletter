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

info "Full cmdline: $(cat /proc/cmdline)"

if [[ -f /usr/lib/bootc/kargs.d/macbook-power.toml ]]; then
    pass "kargs.d toml exists: $(cat /usr/lib/bootc/kargs.d/macbook-power.toml)"
else
    fail "kargs.d toml missing at /usr/lib/bootc/kargs.d/macbook-power.toml"
fi

# ─── 2. CONFIG FILES ───────────────────────────────────────────────────────
header "Config Files"

FILES=(
    "/etc/modprobe.d/thunderbolt-blacklist.conf"
    "/etc/udev/rules.d/99-thunderbolt-pm.rules"
    "/etc/NetworkManager/conf.d/default-wifi-powersave-on.conf"
    "/etc/systemd/system/powertop-autotune.service"
    "/etc/systemd/system/aspm-tune.service"
    "/etc/systemd/system/aspm-tune-resume.service"
    "/usr/local/bin/aspm-tune.sh"
)

for f in "${FILES[@]}"; do
    if [[ -f "$f" ]]; then
        pass "$f"
    else
        fail "$f — MISSING"
    fi
done

# ─── 3. THUNDERBOLT ────────────────────────────────────────────────────────
header "Thunderbolt"

if lsmod | grep -q thunderbolt; then
    fail "thunderbolt module is LOADED (blacklist not effective)"
else
    pass "thunderbolt module not loaded"
fi

if grep -q 'install thunderbolt /bin/false' /etc/modprobe.d/thunderbolt-blacklist.conf 2>/dev/null; then
    pass "Hard block (install /bin/false) present"
elif grep -q 'blacklist thunderbolt' /etc/modprobe.d/thunderbolt-blacklist.conf 2>/dev/null; then
    warn "Only soft blacklist present — consider adding: install thunderbolt /bin/false"
else
    fail "thunderbolt-blacklist.conf missing or empty"
fi

# Thunderbolt PCIe devices runtime PM
header "Thunderbolt PCIe Runtime PM"
TB_DEVS=("0000:05:00.0" "0000:06:00.0" "0000:06:03.0" "0000:06:04.0" "0000:06:05.0")
for dev in "${TB_DEVS[@]}"; do
    if [[ -e "/sys/bus/pci/devices/$dev" ]]; then
        ctrl=$(cat /sys/bus/pci/devices/$dev/power/control 2>/dev/null)
        status=$(cat /sys/bus/pci/devices/$dev/power/runtime_status 2>/dev/null)
        if [[ "$ctrl" == "auto" ]]; then
            pass "$dev — control=$ctrl status=$status"
        else
            fail "$dev — control=$ctrl (expected auto) status=$status"
        fi
    else
        info "$dev — not present on PCIe bus (expected if TB fully off)"
    fi
done

# ─── 4. WIFI POWERSAVE ─────────────────────────────────────────────────────
header "WiFi Powersave"

if [[ -f /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf ]]; then
    content=$(cat /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf)
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

SERVICES=("powertop-autotune.service" "aspm-tune.service" "aspm-tune-resume.service")
for svc in "${SERVICES[@]}"; do
    enabled=$(systemctl is-enabled "$svc" 2>/dev/null)
    active=$(systemctl is-active "$svc" 2>/dev/null)

    if [[ "$enabled" == "enabled" ]]; then
        if [[ "$svc" == "aspm-tune-resume.service" ]]; then
            # oneshot resume service — inactive is normal
            if [[ "$active" == "inactive" || "$active" == "active" ]]; then
                pass "$svc — enabled (oneshot resume, currently $active)"
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

while IFS= read -r block; do
    addr=$(echo "$block" | grep -oP '^[0-9a-f:.]+')
    lnkctl=$(echo "$block" | grep 'LnkCtl:' | grep -oP 'ASPM \S+')
    lnkcap=$(echo "$block" | grep 'LnkCap:' | grep -oP 'ASPM \S+')

    if echo "$lnkctl" | grep -q 'Disabled'; then
        warn "$addr — $lnkctl (cap: $lnkcap)"
    elif echo "$lnkctl" | grep -q 'Enabled'; then
        pass "$addr — $lnkctl"
    fi
done < <(lspci -vv 2>/dev/null | awk '/ASPM/{print $0}' RS=)

# ─── 7. PCIe RUNTIME PM ────────────────────────────────────────────────────
header "PCIe Runtime PM Summary"

total=0; auto=0; suspended=0; active_count=0
while IFS= read -r dev; do
    addr=$(basename "$dev")
    ctrl=$(cat "$dev/power/control" 2>/dev/null)
    status=$(cat "$dev/power/runtime_status" 2>/dev/null)
    total=$((total+1))
    [[ "$ctrl" == "auto" ]] && auto=$((auto+1))
    [[ "$status" == "suspended" ]] && suspended=$((suspended+1))
    [[ "$status" == "active" ]] && active_count=$((active_count+1))
done < <(find /sys/bus/pci/devices -maxdepth 1 -mindepth 1)

info "Total PCIe devices: $total"
info "Runtime PM auto:    $auto / $total"
info "Currently suspended: $suspended"
info "Currently active:    $active_count"

if [[ "$auto" == "$total" ]]; then
    pass "All devices have runtime PM set to auto"
else
    warn "$((total-auto)) device(s) not set to auto runtime PM"
fi

# List any non-auto devices
for dev in /sys/bus/pci/devices/*; do
    addr=$(basename "$dev")
    ctrl=$(cat "$dev/power/control" 2>/dev/null)
    if [[ "$ctrl" != "auto" ]]; then
        name=$(lspci -s "$addr" 2>/dev/null | cut -d' ' -f3-)
        fail "  $addr — control=$ctrl — $name"
    fi
done

# ─── 8. PACKAGE C-STATES ───────────────────────────────────────────────────
header "CPU Package C-States (5s sample)"

if command -v turbostat &>/dev/null; then
    info "Sampling for 5 seconds..."
    turbostat --quiet --show Pkg%pc2,Pkg%pc3,Pkg%pc6,Pkg%pc7,PkgWatt --interval 5 --num_iterations 1 2>/dev/null \
        | tail -n +2 | head -5
    pc7=$(turbostat --quiet --show Pkg%pc7 --interval 5 --num_iterations 1 2>/dev/null \
        | tail -1 | awk '{print $1}')
    if [[ -n "$pc7" ]]; then
        pc7_int=${pc7%.*}
        if (( pc7_int > 0 )); then
            pass "PC7 residency: ${pc7}%"
        else
            warn "PC7 residency: ${pc7}% — may improve after longer idle"
        fi
    fi
else
    warn "turbostat not available — install kernel-tools to check C-states"
fi

# ─── 9. POWER DRAW ─────────────────────────────────────────────────────────
header "Current Power Draw"

if [[ -f /sys/class/power_supply/BAT0/power_now ]]; then
    power_uw=$(cat /sys/class/power_supply/BAT0/power_now)
    power_w=$(echo "scale=2; $power_uw / 1000000" | bc)
    status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)
    info "Battery status: $status"
    if (( power_uw > 0 )); then
        if (( $(echo "$power_w < 5.0" | bc -l) )); then
            pass "Power draw: ${power_w}W (excellent)"
        elif (( $(echo "$power_w < 7.0" | bc -l) )); then
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
