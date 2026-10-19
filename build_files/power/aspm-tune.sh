#!/bin/bash
set -u

# ===== USER CONFIG =====
ROOT_COMPLEXES=("00:1c.0" "00:1c.2" "00:1c.4")
ENDPOINTS=("02:00.0" "03:00.0")
ASPM_SETTING=3
VERIFY_DELAY=3   # seconds to wait after first pass before verification re-check (0 to disable)
# ======================

GREEN="\033[01;32m"
YELLOW="\033[01;33m"
NORMAL="\033[00m"
BLUE="\033[34m"
RED="\033[31m"
CYAN="\033[36m"

# Ensure root
if [[ $(id -u) != 0 ]]; then
echo "This needs to be run as root"
exit 1
fi

device_present() {
    [[ -e "/sys/bus/pci/devices/0000:$1" ]]
}

enable_aspm_byte() {
local DEV=$1

if ! device_present "$DEV"; then
echo -e "Device ${BLUE}${DEV}${NORMAL} ${RED}not present${NORMAL}"
return
fi

if ! ASPM_WORD_HEX=$(/usr/bin/setpci -s "$DEV" CAP_EXP+10.w 2>/dev/null); then
echo -e "$(lspci -s "$DEV")"
echo -e "	PCIe capability not found ${RED}[SKIP]${NORMAL}"
return 1
fi

ASPM_WORD_HEX=$(printf "%04X" 0x${ASPM_WORD_HEX})
DESIRED_ASPM_WORD_HEX=$(printf "%04X" $(( (0x${ASPM_WORD_HEX} & ~0x3) | ASPM_SETTING )))

echo -e "$(lspci -s "$DEV")"
echo -en "	CAP_EXP+10.w: 0x${ASPM_WORD_HEX} -> 0x${DESIRED_ASPM_WORD_HEX} ... "

if [[ $ASPM_WORD_HEX = $DESIRED_ASPM_WORD_HEX ]]; then
echo -e "[${GREEN}ALREADY SET${NORMAL}]"
return
fi

# Retry logic (3 attempts, 0.2s apart)
for i in {1..3}; do
/usr/bin/setpci -s "$DEV" CAP_EXP+10.w=$(printf "%04X" "$ASPM_SETTING"):0003
sleep 0.2

ACTUAL=$(/usr/bin/setpci -s "$DEV" CAP_EXP+10.w)
ACTUAL=$(printf "%04X" 0x${ACTUAL})

if [[ $ACTUAL == $DESIRED_ASPM_WORD_HEX ]]; then
echo -e "[${GREEN}SUCCESS${NORMAL}] (attempt $i)"
return 0
fi

echo -en "[retry $i: got 0x${ACTUAL}] "
done

echo -e "[${RED}FAIL${NORMAL}] (final 0x${ACTUAL})"
return 1
}

# ===== RUN =====

run_pass() {
local PASS_LABEL=$1
echo -e "${CYAN}Root complexes: ${PASS_LABEL}${NORMAL}"
for ROOT in "${ROOT_COMPLEXES[@]}"; do
echo -e "${YELLOW}Processing $ROOT${NORMAL}"
enable_aspm_byte "$ROOT"
echo
done

echo -e "${CYAN}Endpoints: ${PASS_LABEL}${NORMAL}"
for EP in "${ENDPOINTS[@]}"; do
echo -e "${YELLOW}Processing $EP${NORMAL}"
enable_aspm_byte "$EP"
echo
done
}

run_pass "(pass 1)"

if [[ $VERIFY_DELAY -gt 0 ]]; then
echo -e "${YELLOW}Waiting ${VERIFY_DELAY}s before verification pass...${NORMAL}"
sleep $VERIFY_DELAY
run_pass "(verification pass)"
fi
