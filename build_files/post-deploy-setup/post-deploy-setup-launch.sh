#!/bin/bash

set -uo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/linuxbook-air"
DONE_FILE="$STATE_DIR/initial-setup-done"
SKIP_FILE="$STATE_DIR/initial-setup-skipped"
GNOME_SETUP_DONE="${XDG_CONFIG_HOME:-$HOME/.config}/gnome-initial-setup-done"
SETUP_SCRIPT="/usr/libexec/linuxbook-air-post-deploy-setup.sh"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/linuxbook-air/initial-setup.log"

mkdir -p "$STATE_DIR"

[[ -f "$DONE_FILE" || -f "$SKIP_FILE" ]] && exit 0

# Start in the first graphical session, but stay out of GNOME Initial Setup's
# way. Its completion marker is created as soon as the tour/setup finishes, so
# LinuxBook-Air setup can continue without requiring a second login.
while [[ ! -f "$GNOME_SETUP_DONE" ]]; do
    sleep 2
done

CHOICES=$(zenity --list \
    --title="LinuxBook-Air Setup" \
    --window-icon="preferences-system" \
    --text="<big><b>Welcome to LinuxBook-Air</b></big>\n\nChoose the optional components to set up.\n\nKeyboard remapping is powered by <b>Toshy</b>, created by RedBearAK:\nhttps://github.com/RedBearAK/Toshy" \
    --checklist \
    --column="Install" --column="Component" \
    TRUE "Toshy keyboard shortcuts" \
    TRUE "MacTahoe Firefox styling" \
    TRUE "GNOME Flatpak applications" \
    --separator="|" \
    --ok-label="Install selected" \
    --cancel-label="Not now" \
    --width=620 --height=360 2>/dev/null) || exit 0

if [[ -z "$CHOICES" ]]; then
    if zenity --question \
        --title="Skip LinuxBook-Air Setup?" \
        --window-icon="preferences-system" \
        --text="No components were selected. Stop offering this setup on future logins?" \
        --ok-label="Skip permanently" --cancel-label="Remind me later" 2>/dev/null; then
        touch "$SKIP_FILE"
    fi
    exit 0
fi

SETUP_ARGS=()
WARNING_TEXT="<big><b>A terminal window will open for setup.</b></big>"

if [[ "$CHOICES" == *"Toshy keyboard shortcuts"* ]]; then
    SETUP_ARGS+=(--toshy)
    WARNING_TEXT+="\n\nToshy may ask for your sudo password and a few confirmations. When asked whether <b>this machine has been updated recently</b>, answer <b>yes</b>."
fi

if [[ "$CHOICES" == *"MacTahoe Firefox styling"* ]]; then
    SETUP_ARGS+=(--firefox)
    WARNING_TEXT+="\n\nA Firefox profile will be prepared and styled. Please close Firefox before continuing."
fi

if [[ "$CHOICES" == *"GNOME Flatpak applications"* ]]; then
    SETUP_ARGS+=(--apps)
fi

if ! command -v ptyxis >/dev/null 2>&1; then
    zenity --error \
        --title="LinuxBook-Air Setup Incomplete" \
        --window-icon="preferences-system" \
        --text="The Ptyxis terminal is required to run the interactive setup. Setup will be offered again next login." 2>/dev/null
    exit 1
fi

zenity --warning \
    --title="LinuxBook-Air Setup" \
    --window-icon="preferences-system" \
    --text="$WARNING_TEXT" \
    --ok-label="Open setup" \
    --width=560 2>/dev/null || exit 0

ptyxis --standalone \
    --title="LinuxBook-Air Setup" \
    -- bash "$SETUP_SCRIPT" "${SETUP_ARGS[@]}"

if [[ -f "$DONE_FILE" ]]; then
    zenity --info \
        --title="LinuxBook-Air Setup Complete" \
        --window-icon="preferences-system" \
        --text="The selected LinuxBook-Air components are installed." 2>/dev/null
else
    zenity --error \
        --title="LinuxBook-Air Setup Incomplete" \
        --window-icon="preferences-system" \
        --text="Setup could not finish. It will be offered again next login.\n\nDetails: $LOG_FILE" 2>/dev/null
fi
