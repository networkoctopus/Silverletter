#!/bin/sh

LOCKFILE=/run/tb-powerdown.lock
LOG_TAG=silverletter-thunderbolt
STATE_DIR=/run/silverletter
STATE_FILE="$STATE_DIR/thunderbolt.state"

exec 9> "$LOCKFILE"
if ! flock -n 9; then
    logger -t "$LOG_TAG" "action=powerdown result=skipped reason=already-running"
    exit 0
fi

logger -t "$LOG_TAG" "action=powerdown stage=start"
sleep 2

TB_DEVS="07:00.0 06:06.0 06:05.0 06:04.0 06:03.0 06:00.0 05:00.0"

for dev in $TB_DEVS; do
    path="/sys/bus/pci/devices/0000:$dev"
    if [ -e "$path" ]; then
        echo 0 > "$path/power/autosuspend_delay_ms"
        echo auto > "$path/power/control"
        logger -t "$LOG_TAG" \
            "action=powerdown stage=runtime-pm device=0000:$dev control=auto"
    fi
done

sleep 1

for dev in $TB_DEVS; do
    path="/sys/bus/pci/devices/0000:$dev"
    if [ -e "$path/remove" ]; then
        echo 1 > "$path/remove"
        logger -t "$LOG_TAG" "action=powerdown stage=pci-remove device=0000:$dev"
    fi
done

if ! {
    install -d -m 0755 "$STATE_DIR" &&
    printf 'disabled\n' > "$STATE_FILE" &&
    chmod 0644 "$STATE_FILE"
}; then
    logger -t "$LOG_TAG" \
        "action=state-notify result=failed requested_state=disabled"
fi

logger -t "$LOG_TAG" "action=powerdown result=success"
