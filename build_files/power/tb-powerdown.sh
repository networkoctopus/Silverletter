#!/bin/sh
set -eu

STATEFILE=/run/silverletter/thunderbolt-enabled
REPLUGFILE=/run/silverletter/thunderbolt-replug-during-powerdown
LOCKFILE=/run/tb-powerdown.lock
LOG_TAG=silverletter-thunderbolt
DEBUG_CONFIG=/run/silverletter/thunderbolt-debug.conf
if [ -r "$DEBUG_CONFIG" ]; then
    # Created by the root-only guided debug tool.
    # shellcheck disable=SC1090
    . "$DEBUG_CONFIG"
fi
TB_DEBUG_RUN_ID=${TB_DEBUG_RUN_ID:-none}
TB_POWERDOWN_INITIAL_DELAY_SECONDS=${TB_POWERDOWN_INITIAL_DELAY_SECONDS:-2}
TB_RUNTIME_PM_SETTLE_SECONDS=${TB_RUNTIME_PM_SETTLE_SECONDS:-1}
if [ -e "$STATEFILE" ]; then
    logger -t "$LOG_TAG" "action=powerdown result=skipped reason=temporary-enable-active"
    exit 0
fi
exec 9> "$LOCKFILE"
if ! flock -n 9; then
    logger -t "$LOG_TAG" "action=powerdown result=skipped reason=already-running"
    exit 0
fi

logger -t "$LOG_TAG" \
    "action=powerdown stage=start debug_run=$TB_DEBUG_RUN_ID initial_delay=$TB_POWERDOWN_INITIAL_DELAY_SECONDS runtime_pm_settle=$TB_RUNTIME_PM_SETTLE_SECONDS"
sleep "$TB_POWERDOWN_INITIAL_DELAY_SECONDS"

# An enable request may have arrived while this udev job was waiting.
if [ -e "$STATEFILE" ] || [ -e "$REPLUGFILE" ]; then
    logger -t "$LOG_TAG" "action=powerdown result=cancelled reason=claim-or-replug-during-initial-delay"
    exit 0
fi

# Do not change or remove the Falcon Ridge bridge fabric. Full bridge teardown
# caused PCI stalls and kernel panics, and forcing bridge power states did not
# restore hotplug reliably. This helper exclusively targets the 07:00 NHI.
TB_NHI="07:00.0"

if [ -e "$STATEFILE" ] || [ -e "$REPLUGFILE" ]; then
    logger -t "$LOG_TAG" "action=powerdown result=cancelled reason=claim-or-replug-during-runtime-pm"
    exit 0
fi
nhi_path="/sys/bus/pci/devices/0000:$TB_NHI"
if [ -e "$nhi_path" ]; then
    runtime_pm_ok=1
    if ! echo 0 > "$nhi_path/power/autosuspend_delay_ms"; then
        runtime_pm_ok=0
        logger -p daemon.warning -t "$LOG_TAG" \
            "action=powerdown stage=runtime-pm-warning device=0000:$TB_NHI attribute=autosuspend_delay_ms"
    fi
    if ! echo auto > "$nhi_path/power/control"; then
        runtime_pm_ok=0
        logger -p daemon.warning -t "$LOG_TAG" \
            "action=powerdown stage=runtime-pm-warning device=0000:$TB_NHI attribute=control"
    fi
    if [ "$runtime_pm_ok" -eq 1 ]; then
        logger -t "$LOG_TAG" \
            "action=powerdown stage=runtime-pm device=0000:$TB_NHI control=auto"
    fi
fi

sleep "$TB_RUNTIME_PM_SETTLE_SECONDS"

# Do not remove the NHI if it was enabled while runtime PM settled.
if [ -e "$STATEFILE" ] || [ -e "$REPLUGFILE" ]; then
    logger -t "$LOG_TAG" "action=powerdown result=cancelled reason=claim-or-replug-during-runtime-pm-delay"
    exit 0
fi

if [ -e "$nhi_path/remove" ]; then
    logger -t "$LOG_TAG" "action=powerdown stage=pci-remove-start device=0000:$TB_NHI"
    echo 1 > "$nhi_path/remove"
    logger -t "$LOG_TAG" "action=powerdown stage=pci-remove device=0000:$TB_NHI"
fi

if [ -e "$nhi_path" ]; then
    logger -p daemon.err -t "$LOG_TAG" \
        "action=powerdown result=failed remaining_devices=0000:$TB_NHI"
    exit 1
fi

logger -t "$LOG_TAG" "action=powerdown result=success nhi=absent bridge_fabric=retained"
