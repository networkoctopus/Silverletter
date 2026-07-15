#!/bin/bash

set -uo pipefail

FORCE_RUN=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE_RUN=true
elif (( $# )); then
    printf 'Unknown launcher option: %s\n' "$1" >&2
    exit 2
fi

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/silverletter"
DONE_FILE="$STATE_DIR/initial-setup-done"
SKIP_FILE="$STATE_DIR/initial-setup-skipped"
GNOME_SETUP_DONE="${XDG_CONFIG_HOME:-$HOME/.config}/gnome-initial-setup-done"
SETUP_APP="/usr/libexec/silverletter-setup-app.py"

mkdir -p "$STATE_DIR"

if [[ "$FORCE_RUN" == false && ( -f "$DONE_FILE" || -f "$SKIP_FILE" ) ]]; then
    exit 0
fi

# Start in the first graphical session, but stay out of GNOME Initial Setup's
# way. Its completion marker is created as soon as the tour/setup finishes.
if [[ "$FORCE_RUN" == false ]]; then
    while [[ ! -f "$GNOME_SETUP_DONE" ]]; do
        sleep 2
    done
fi

if [[ "$FORCE_RUN" == true ]]; then
    exec "$SETUP_APP" --force
else
    exec "$SETUP_APP"
fi
