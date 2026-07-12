#!/bin/bash
# Install the per-user components selected by the image setup launcher.
# Toshy's interactive output is shown directly in a terminal. Other setup
# details are written to LOG_FILE.

set -uo pipefail

INSTALL_TOSHY=false
INSTALL_FIREFOX=false
INSTALL_APPS=false
TOSHY_INSTALLED_NOW=false

# Running without arguments retains the original install-everything behavior.
if (( $# == 0 )); then
    INSTALL_TOSHY=true
    INSTALL_FIREFOX=true
    INSTALL_APPS=true
else
    while (( $# )); do
        case "$1" in
            --toshy) INSTALL_TOSHY=true ;;
            --firefox) INSTALL_FIREFOX=true ;;
            --apps) INSTALL_APPS=true ;;
            *) printf 'Unknown setup option: %s\n' "$1" >&2; exit 2 ;;
        esac
        shift
    done
fi

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/linuxbook-air"
DONE_FILE="$STATE_DIR/initial-setup-done"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/linuxbook-air"
LOG_FILE="$LOG_DIR/initial-setup.log"
FIREFOX_SENTINEL="${XDG_CONFIG_HOME:-$HOME/.config}/mactahoe/.firefox-done"
FIREFOX_REPO="/usr/share/MacTahoe-gtk-theme"
TOSHY_CONFIG="$HOME/.config/toshy/toshy_config.py"

FLATPAKS=(
    org.gnome.Calculator
    org.gnome.Calendar
    org.gnome.Characters
    org.gnome.Connections
    org.gnome.Contacts
    org.gnome.Evolution
    org.gnome.Extensions
    org.gnome.Logs
    org.gnome.Loupe
    org.gnome.Maps
    org.gnome.NautilusPreviewer
    org.gnome.Papers
    org.gnome.Snapshot
    org.gnome.TextEditor
    org.gnome.Weather
    org.gnome.baobab
    org.gnome.clocks
    org.gnome.font-viewer
)

mkdir -p "$STATE_DIR" "$LOG_DIR"
: > "$LOG_FILE"

progress() {
    printf '\n[%s%%] %s\n' "$1" "$2"
}

wait_to_close() {
    printf '\n'
    read -r -p "Press Enter to close this window… " || true
}

fail() {
    printf 'ERROR: %s\n' "$1" >> "$LOG_FILE"
    progress 100 "$1"
    wait_to_close
    exit 1
}

if [[ "$INSTALL_TOSHY" == true && ! -f "$TOSHY_CONFIG" ]]; then
    progress 5 "Checking internet access for Toshy…"
    if ! curl --connect-timeout 8 --max-time 15 --silent --show-error --fail \
        --head https://github.com/ >> "$LOG_FILE" 2>&1; then
        fail "No internet connection. Setup will be offered again next login."
    fi
fi

if [[ "$INSTALL_TOSHY" == true && ! -f "$TOSHY_CONFIG" ]]; then
    progress 15 "Downloading Toshy…"
    TOSHY_TMP=$(mktemp -d)
    trap 'rm -rf "$TOSHY_TMP"' EXIT

    if ! git clone --quiet --depth=1 https://github.com/RedBearAK/Toshy.git \
        "$TOSHY_TMP/toshy" >> "$LOG_FILE" 2>&1; then
        fail "Toshy could not be downloaded. Setup will retry next login."
    fi

    progress 35 "Installing Toshy keyboard shortcuts…"
    cd "$TOSHY_TMP/toshy" || fail "Could not open the Toshy installer directory."

    # Keep stdin and stdout attached directly to the terminal for sudo and
    # Toshy's interactive questions.
    SESSION_TYPE=wayland python3 ./setup_toshy.py install \
        --override-distro silverblue \
        --skip-native
    TOSHY_STATUS=$?
    [[ $TOSHY_STATUS -eq 0 ]] || \
        fail "Toshy installation failed. Review the output above."
    TOSHY_INSTALLED_NOW=true
elif [[ "$INSTALL_TOSHY" == true ]]; then
    progress 45 "Toshy is already installed."
fi

if [[ "$TOSHY_INSTALLED_NOW" == true ]]; then
    progress 50 "Setting Toshy's touchpad suspend timeout…"
    if ! grep -Eq '^[[:space:]]*suspend[[:space:]]*=' "$TOSHY_CONFIG"; then
        fail "Toshy's suspend timeout setting could not be found."
    fi
    TOSHY_CONFIG_TMP=$(mktemp "${TOSHY_CONFIG}.XXXXXX")
    if ! sed -E \
        '/^[[:space:]]*suspend[[:space:]]*=/ s/=[[:space:]]*[^,]+,/= 0.1,/' \
        "$TOSHY_CONFIG" > "$TOSHY_CONFIG_TMP"; then
        rm -f "$TOSHY_CONFIG_TMP"
        fail "Toshy's suspend timeout could not be updated."
    fi
    mv "$TOSHY_CONFIG_TMP" "$TOSHY_CONFIG"
    grep -Eq '^[[:space:]]*suspend[[:space:]]*=[[:space:]]*0\.1[[:space:]]*,' \
        "$TOSHY_CONFIG" || fail "Toshy's suspend timeout could not be set to 0.1 seconds."

    if command -v toshy-services-restart >/dev/null 2>&1; then
        toshy-services-restart >> "$LOG_FILE" 2>&1 || \
            fail "Toshy was configured, but its services could not be restarted."
    elif [[ -x "$HOME/.local/bin/toshy-services-restart" ]]; then
        "$HOME/.local/bin/toshy-services-restart" >> "$LOG_FILE" 2>&1 || \
            fail "Toshy was configured, but its services could not be restarted."
    fi
fi

if [[ "$INSTALL_FIREFOX" == true && ! -f "$FIREFOX_SENTINEL" ]]; then
    progress 55 "Preparing Firefox for MacTahoe styling…"

    if pidof firefox firefox-bin >/dev/null 2>&1; then
        printf '\nFirefox is running. Close it to continue setup.\n'
        while pidof firefox firefox-bin >/dev/null 2>&1; do
            sleep 2
        done
    fi

    if ! compgen -G "${HOME}/.mozilla/firefox/*.default*" > /dev/null 2>&1; then
        firefox -CreateProfile default-release >> "$LOG_FILE" 2>&1 || \
            fail "Firefox could not create its default profile."
    fi

    if ! compgen -G "${HOME}/.mozilla/firefox/*.default*" > /dev/null 2>&1; then
        fail "Firefox did not create a usable default profile."
    fi

    cd "$FIREFOX_REPO" || fail "Could not open the MacTahoe Firefox files."
    ./tweaks.sh -f
    FIREFOX_STATUS=$?
    [[ $FIREFOX_STATUS -eq 0 ]] || \
        fail "MacTahoe Firefox styling failed. Review the output above."

    mkdir -p "$(dirname "$FIREFOX_SENTINEL")"
    touch "$FIREFOX_SENTINEL"
elif [[ "$INSTALL_FIREFOX" == true ]]; then
    progress 55 "MacTahoe Firefox styling is already installed."
fi

if [[ "$INSTALL_APPS" == true ]]; then
    progress 65 "Checking the default applications…"
    INSTALLED_APPS_OUTPUT=$(flatpak list --app --columns=application 2>> "$LOG_FILE") || \
        fail "The installed Flatpak applications could not be checked. See $LOG_FILE"
    mapfile -t INSTALLED_APPS <<< "$INSTALLED_APPS_OUTPUT"
    MISSING_APPS=()
    for app in "${FLATPAKS[@]}"; do
        if ! printf '%s\n' "${INSTALLED_APPS[@]}" | grep -Fxq "$app"; then
            MISSING_APPS+=("$app")
        fi
    done

    if (( ${#MISSING_APPS[@]} )); then
        progress 75 "Restoring ${#MISSING_APPS[@]} default GNOME applications from Flathub…"
        if ! flatpak install --noninteractive --assumeyes flathub \
            "${MISSING_APPS[@]}" >> "$LOG_FILE" 2>&1; then
            fail "Some default applications could not be installed. See $LOG_FILE"
        fi
    else
        progress 90 "All default applications are already installed."
    fi
fi

touch "$DONE_FILE"
progress 100 "Setup complete. The selected components are ready."
wait_to_close
