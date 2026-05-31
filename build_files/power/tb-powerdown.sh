#!/bin/sh
LOCKFILE=/run/tb-powerdown.lock
[ -e "$LOCKFILE" ] && exit 0
touch "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

logger -t tb-powerdown "script started"
sleep 2

TB_DEVS="07:00.0 06:06.0 06:05.0 06:04.0 06:03.0 06:00.0 05:00.0"

for dev in $TB_DEVS; do
    path="/sys/bus/pci/devices/0000:$dev"
    if [ -e "$path" ]; then
        echo 0    > "$path/power/autosuspend_delay_ms"
        echo auto > "$path/power/control"
        logger -t tb-powerdown "set auto on $dev"
    fi
done

sleep 1

for dev in $TB_DEVS; do
    path="/sys/bus/pci/devices/0000:$dev"
    if [ -e "$path/remove" ]; then
        echo 1 > "$path/remove"
        logger -t tb-powerdown "removed $dev"
    fi
done

logger -t tb-powerdown "done"