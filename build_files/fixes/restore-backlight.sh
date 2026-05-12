#!/bin/bash
BACKLIGHT=/sys/class/backlight/intel_backlight
case "$1" in
    pre)
        cat "$BACKLIGHT/brightness" > /tmp/backlight-save 2>/dev/null || true
        ;;
    post)
        sleep 1
        [ -f /tmp/backlight-save ] && \
            cat /tmp/backlight-save > "$BACKLIGHT/brightness" 2>/dev/null || true
        ;;
esac