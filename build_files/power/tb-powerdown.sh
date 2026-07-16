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

TB_DEVS="07:00.0 06:06.0 06:05.0 06:04.0 06:03.0 06:00.0 05:00.0"

for dev in $TB_DEVS; do
    if [ -e "$STATEFILE" ] || [ -e "$REPLUGFILE" ]; then
        logger -t "$LOG_TAG" "action=powerdown result=cancelled reason=claim-or-replug-during-runtime-pm"
        exit 0
    fi
    path="/sys/bus/pci/devices/0000:$dev"
    if [ -e "$path" ]; then
        echo 0    > "$path/power/autosuspend_delay_ms"
        echo auto > "$path/power/control"
        logger -t "$LOG_TAG" "action=powerdown stage=runtime-pm device=0000:$dev control=auto"
    fi
done

sleep "$TB_RUNTIME_PM_SETTLE_SECONDS"

# Do not tear the hierarchy down if it was enabled while runtime PM settled.
if [ -e "$STATEFILE" ] || [ -e "$REPLUGFILE" ]; then
    logger -t "$LOG_TAG" "action=powerdown result=cancelled reason=claim-or-replug-during-runtime-pm-delay"
    exit 0
fi

for dev in $TB_DEVS; do
    if [ -e "$STATEFILE" ] || [ -e "$REPLUGFILE" ]; then
        logger -t "$LOG_TAG" "action=powerdown result=cancelled reason=claim-or-replug-before-pci-remove"
        exit 0
    fi
    path="/sys/bus/pci/devices/0000:$dev"
    if [ -e "$path/remove" ]; then
        logger -t "$LOG_TAG" "action=powerdown stage=pci-remove-start device=0000:$dev"
        echo 1 > "$path/remove"
        logger -t "$LOG_TAG" "action=powerdown stage=pci-remove device=0000:$dev"
    fi
done

remaining=""
for dev in $TB_DEVS; do
    if [ -e "/sys/bus/pci/devices/0000:$dev" ]; then
        remaining="${remaining}${remaining:+,}0000:$dev"
    fi
done

if [ -n "$remaining" ]; then
    logger -p daemon.err -t "$LOG_TAG" \
        "action=powerdown result=failed remaining_devices=$remaining"
    exit 1
fi

logger -t "$LOG_TAG" "action=powerdown result=success remaining_devices=none"
