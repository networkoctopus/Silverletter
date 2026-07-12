#!/bin/bash
# Install the per-user components selected by the image setup launcher.
# Toshy's interactive output is shown directly in a terminal. Other setup
# details are written to LOG_FILE.

set -uo pipefail

INSTALL_TOSHY=false
INSTALL_DESKTOP_THEME=false
INSTALL_FIREFOX=false
INSTALL_APPS=false
TOSHY_INSTALLED_NOW=false

# Running without arguments retains the original install-everything behavior.
if (( $# == 0 )); then
    INSTALL_TOSHY=true
    INSTALL_DESKTOP_THEME=true
    INSTALL_FIREFOX=true
    INSTALL_APPS=true
else
    while (( $# )); do
        case "$1" in
            --toshy) INSTALL_TOSHY=true ;;
            --desktop-theme) INSTALL_DESKTOP_THEME=true ;;
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

firefox_is_running() {
    pgrep -u "$UID" -x firefox >/dev/null 2>&1 || \
        pgrep -u "$UID" -x firefox-bin >/dev/null 2>&1
}

firefox_profile_initialized() {
    [[ -s "$HOME/.mozilla/firefox/profiles.ini" ]] || \
        [[ -s "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox/profiles.ini" ]]
}

confirm_firefox_closed() {
    printf '\nClose every Firefox window, then press Enter to continue.\n'
    read -r -p "Firefox is closed: press Enter… " || true

    if firefox_is_running; then
        progress 58 "Stopping lingering Firefox processes…"
        pkill -TERM -u "$UID" -x firefox 2>/dev/null || true
        pkill -TERM -u "$UID" -x firefox-bin 2>/dev/null || true

        for _ in {1..10}; do
            firefox_is_running || break
            sleep 1
        done

        if firefox_is_running; then
            pkill -KILL -u "$UID" -x firefox 2>/dev/null || true
            pkill -KILL -u "$UID" -x firefox-bin 2>/dev/null || true
        fi
    fi

    firefox_is_running && fail "Firefox could not be stopped."
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

if [[ "$INSTALL_DESKTOP_THEME" == true ]]; then
    progress 53 "Applying the WhiteSur and MacTahoe desktop theme…"

    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || \
        fail "GNOME dark style could not be enabled."
    gsettings set org.gnome.desktop.interface gtk-theme 'WhiteSur-Dark' || \
        fail "The WhiteSur GTK theme could not be applied."
    gsettings set org.gnome.desktop.interface icon-theme 'MacTahoe' || \
        fail "The MacTahoe icon theme could not be applied."
    gsettings set org.gnome.desktop.interface cursor-theme 'MacTahoe' || \
        fail "The MacTahoe cursor theme could not be applied."
    gsettings set org.gnome.desktop.wm.preferences button-layout \
        'appmenu:minimize,maximize,close' || \
        fail "The minimise and maximise window buttons could not be enabled."
    gsettings set org.gnome.shell.extensions.user-theme name 'WhiteSur-Dark' || \
        fail "The WhiteSur Shell theme could not be applied."
fi

if [[ "$INSTALL_FIREFOX" == true && ! -f "$FIREFOX_SENTINEL" ]]; then
    progress 55 "Preparing Firefox for MacTahoe styling…"

    if firefox_is_running; then
        confirm_firefox_closed
    fi

    if ! firefox_profile_initialized; then
        printf '\nFirefox needs to open once to create its profile.\n'
        printf 'When the Firefox window appears, wait for it to load and then close it.\n\n'
        MOZ_ENABLE_WAYLAND=1 firefox >> "$LOG_FILE" 2>&1 &
        FIREFOX_LAUNCH_PID=$!

        # Firefox creates the profile during startup. Wait for that to happen
        # before asking the user to close it and continuing with tweaks.sh.
        for _ in {1..30}; do
            firefox_profile_initialized && break
            sleep 1
        done

        if ! firefox_profile_initialized; then
            wait "$FIREFOX_LAUNCH_PID" 2>/dev/null || true
            fail "Firefox could not initialise its default profile. See $LOG_FILE"
        fi

        printf 'Firefox is ready.\n'
        confirm_firefox_closed
        wait "$FIREFOX_LAUNCH_PID" 2>/dev/null || true
    fi

    if ! firefox_profile_initialized; then
        fail "Firefox did not create a usable default profile."
    fi

    FIREFOX_THEME_TMP=$(mktemp -d)
    if ! cp -a "$FIREFOX_REPO/." "$FIREFOX_THEME_TMP/" >> "$LOG_FILE" 2>&1; then
        rm -rf "$FIREFOX_THEME_TMP"
        fail "The MacTahoe Firefox files could not be prepared."
    fi
    chmod -R u+rwX "$FIREFOX_THEME_TMP"

    cd "$FIREFOX_THEME_TMP" || fail "Could not open the MacTahoe Firefox files."
    ./tweaks.sh -f
    FIREFOX_STATUS=$?
    cd "$HOME" || true
    rm -rf "$FIREFOX_THEME_TMP"
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
printf '\nMacTahoe and WhiteSur themes are available in GNOME Tweaks under Appearance.\n'
wait_to_close
