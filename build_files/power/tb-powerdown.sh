#!/bin/sh
STATEFILE=/run/linuxbook-air/thunderbolt-enabled
LOCKFILE=/run/tb-powerdown.lock
LOG_TAG=linuxbook-air-thunderbolt
if [ -e "$STATEFILE" ]; then
    logger -t "$LOG_TAG" "action=powerdown result=skipped reason=temporary-enable-active"
    exit 0
fi
exec 9> "$LOCKFILE"
if ! flock -n 9; then
    logger -t "$LOG_TAG" "action=powerdown result=skipped reason=already-running"
    exit 0
fi

logger -t "$LOG_TAG" "action=powerdown stage=start"
sleep 2

# An enable request may have arrived while this udev job was waiting.
if [ -e "$STATEFILE" ]; then
    logger -t "$LOG_TAG" "action=powerdown result=cancelled reason=enable-request-during-initial-delay"
    exit 0
fi

TB_DEVS="07:00.0 06:06.0 06:05.0 06:04.0 06:03.0 06:00.0 05:00.0"

for dev in $TB_DEVS; do
    path="/sys/bus/pci/devices/0000:$dev"
    if [ -e "$path" ]; then
        echo 0    > "$path/power/autosuspend_delay_ms"
        echo auto > "$path/power/control"
        logger -t "$LOG_TAG" "action=powerdown stage=runtime-pm device=0000:$dev control=auto"
    fi
done

sleep 1

# Do not tear the hierarchy down if it was enabled while runtime PM settled.
if [ -e "$STATEFILE" ]; then
    logger -t "$LOG_TAG" "action=powerdown result=cancelled reason=enable-request-during-runtime-pm-delay"
    exit 0
fi

for dev in $TB_DEVS; do
    path="/sys/bus/pci/devices/0000:$dev"
    if [ -e "$path/remove" ]; then
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
