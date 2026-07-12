#!/bin/bash

set -uo pipefail

FORCE_RUN=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE_RUN=true
elif (( $# )); then
    printf 'Unknown launcher option: %s\n' "$1" >&2
    exit 2
fi

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/linuxbook-air"
DONE_FILE="$STATE_DIR/initial-setup-done"
SUCCESS_FILE="$STATE_DIR/last-run-success"
SKIP_FILE="$STATE_DIR/initial-setup-skipped"
GNOME_SETUP_DONE="${XDG_CONFIG_HOME:-$HOME/.config}/gnome-initial-setup-done"
SETUP_SCRIPT="/usr/libexec/linuxbook-air-post-deploy-setup.sh"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/linuxbook-air/initial-setup.log"

mkdir -p "$STATE_DIR"

if [[ "$FORCE_RUN" == false && ( -f "$DONE_FILE" || -f "$SKIP_FILE" ) ]]; then
    exit 0
fi

# Start in the first graphical session, but stay out of GNOME Initial Setup's
# way. Its completion marker is created as soon as the tour/setup finishes, so
# LinuxBook-Air setup can continue without requiring a second login.
if [[ "$FORCE_RUN" == false ]]; then
    while [[ ! -f "$GNOME_SETUP_DONE" ]]; do
        sleep 2
    done
fi

if [[ "$FORCE_RUN" == true ]]; then
    MANAGE_ACTION=$(zenity --list \
        --title="LinuxBook-Air Setup" \
        --window-icon="linuxbook-air-setup" \
        --text="Choose what you would like to do." \
        --radiolist \
        --column="" --column="Action" \
        TRUE "Install or apply components" \
        FALSE "Remove optional components" \
        --ok-label="Continue" --cancel-label="Close" \
        --width=520 --height=280 2>/dev/null) || exit 0

    if [[ "$MANAGE_ACTION" == "Remove optional components" ]]; then
        REMOVE_CHOICES=$(zenity --list \
            --title="Remove LinuxBook-Air Components" \
            --window-icon="linuxbook-air-setup" \
            --text="Choose what to remove or reset. Desktop themes remain installed and can be selected again in Tweaks. GNOME Flatpak applications can be uninstalled in GNOME Software." \
            --checklist \
            --column="Remove" --column="Component" \
            FALSE "Toshy keyboard remapping" \
            FALSE "Revert MacOS desktop theme and icons" \
            FALSE "MacOS Firefox styling" \
            --separator="|" \
            --ok-label="Remove selected" --cancel-label="Cancel" \
            --width=700 --height=420 2>/dev/null) || exit 0

        [[ -z "$REMOVE_CHOICES" ]] && exit 0
        REMOVE_ARGS=()
        REMOVE_WARNING="<big><b>A terminal window will open for removal.</b></big>"

        if [[ "$REMOVE_CHOICES" == *"Toshy keyboard remapping"* ]]; then
            REMOVE_ARGS+=(--remove-toshy)
            REMOVE_WARNING+="\n\nToshy may ask for your sudo password and confirmation."
        fi
        if [[ "$REMOVE_CHOICES" == *"MacOS Firefox styling"* ]]; then
            REMOVE_ARGS+=(--remove-firefox)
            REMOVE_WARNING+="\n\nPlease close Firefox before continuing."
        fi
        if [[ "$REMOVE_CHOICES" == *"Revert MacOS desktop theme and icons"* ]]; then
            REMOVE_ARGS+=(--revert-desktop-theme)
        fi

        if ! command -v ptyxis >/dev/null 2>&1; then
            zenity --error --title="Removal Incomplete" \
                --window-icon="linuxbook-air-setup" \
                --text="The Ptyxis terminal is required to remove interactive components." 2>/dev/null
            exit 1
        fi
        zenity --warning --title="LinuxBook-Air Setup" \
            --window-icon="linuxbook-air-setup" --text="$REMOVE_WARNING" \
            --ok-label="Open removal" --width=560 2>/dev/null || exit 0

        rm -f "$SUCCESS_FILE"
        ptyxis --standalone --title="LinuxBook-Air Component Removal" \
            -- bash "$SETUP_SCRIPT" "${REMOVE_ARGS[@]}"

        if [[ -f "$SUCCESS_FILE" ]]; then
            zenity --info --title="Removal Complete" \
                --window-icon="linuxbook-air-setup" \
                --text="The selected optional components were removed or reset." 2>/dev/null
        else
            zenity --error --title="Removal Incomplete" \
                --window-icon="linuxbook-air-setup" \
                --text="Removal could not finish.\n\nDetails: $LOG_FILE" 2>/dev/null
        fi
        exit 0
    fi
fi

CHOICES=$(zenity --list \
    --title="LinuxBook-Air Setup" \
    --window-icon="linuxbook-air-setup" \
    --text="<big><b>Welcome to LinuxBook-Air</b></big>\n\nChoose the optional components to set up. You can install, remove, or reset them later by opening <b>LinuxBook-Air Setup</b> from the application launcher. GNOME Flatpak applications can be uninstalled in GNOME Software.\n\nKeyboard remapping is powered by <b>Toshy</b>, created by RedBearAK:\nhttps://github.com/RedBearAK/Toshy\n\nMacOS themes are created by <b>vinceliuice</b>:\nhttps://github.com/vinceliuice" \
    --checklist \
    --column="Install" --column="Component" \
    TRUE "Toshy keyboard remapping" \
    TRUE "MacOS desktop theme and icons" \
    TRUE "MacOS Firefox styling" \
    TRUE "GNOME Flatpak applications" \
    --separator="|" \
    --ok-label="Install selected" \
    --cancel-label="Not now" \
    --width=760 --height=620 2>/dev/null) || exit 0

if [[ -z "$CHOICES" ]]; then
    if zenity --question \
        --title="Skip LinuxBook-Air Setup?" \
        --window-icon="linuxbook-air-setup" \
        --text="No components were selected. Stop offering this setup on future logins?" \
        --ok-label="Skip permanently" --cancel-label="Remind me later" 2>/dev/null; then
        touch "$SKIP_FILE"
    fi
    exit 0
fi

SETUP_ARGS=()
WARNING_TEXT="<big><b>A terminal window will open for setup.</b></big>"

if [[ "$CHOICES" == *"Toshy keyboard remapping"* ]]; then
    SETUP_ARGS+=(--toshy)
    WARNING_TEXT+="\n\nToshy may ask for your sudo password and a few confirmations. When asked whether <b>this machine has been updated recently</b>, answer <b>yes</b>."
fi

if [[ "$CHOICES" == *"MacOS desktop theme and icons"* ]]; then
    SETUP_ARGS+=(--desktop-theme)
fi

if [[ "$CHOICES" == *"MacOS Firefox styling"* ]]; then
    SETUP_ARGS+=(--firefox)
    WARNING_TEXT+="\n\nPlease close Firefox before continuing. If Firefox has not been opened before, setup will open it once to initialise its profile; close it again after it loads."
fi

if [[ "$CHOICES" == *"GNOME Flatpak applications"* ]]; then
    SETUP_ARGS+=(--apps)
fi

if ! command -v ptyxis >/dev/null 2>&1; then
    zenity --error \
        --title="LinuxBook-Air Setup Incomplete" \
        --window-icon="linuxbook-air-setup" \
        --text="The Ptyxis terminal is required to run the interactive setup. Setup will be offered again next login." 2>/dev/null
    exit 1
fi

zenity --warning \
    --title="LinuxBook-Air Setup" \
    --window-icon="linuxbook-air-setup" \
    --text="$WARNING_TEXT" \
    --ok-label="Open setup" \
    --width=560 2>/dev/null || exit 0

rm -f "$SUCCESS_FILE"
ptyxis --standalone \
    --title="LinuxBook-Air Setup" \
    -- bash "$SETUP_SCRIPT" "${SETUP_ARGS[@]}"

if [[ -f "$SUCCESS_FILE" ]]; then
    zenity --info \
        --title="LinuxBook-Air Setup Complete" \
        --window-icon="linuxbook-air-setup" \
        --text="The selected LinuxBook-Air components are installed.\n\nMacTahoe and WhiteSur themes are available in GNOME Tweaks app, under the Appearance menu." \
        --width=560 2>/dev/null
else
    zenity --error \
        --title="LinuxBook-Air Setup Incomplete" \
        --window-icon="linuxbook-air-setup" \
        --text="Setup could not finish. It will be offered again next login.\n\nDetails: $LOG_FILE" 2>/dev/null
fi
