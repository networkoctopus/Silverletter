#!/bin/bash
# Launched by the systemd user service.
# Finds a working terminal emulator and opens the setup script in it.

SENTINEL="$HOME/.config/toshy/.image-setup-done"
[[ -f "$SENTINEL" ]] && exit 0

SETUP_SCRIPT="/usr/libexec/toshy-first-login-setup.sh"

# Try terminal emulators in preference order
# ptyxis = default on Silverblue 40+
# gnome-terminal needs the server workaround
# xterm always works as a fallback

if command -v ptyxis &>/dev/null; then
    exec ptyxis -- bash "$SETUP_SCRIPT"
elif command -v kgx &>/dev/null; then
    # GNOME Console (kgx) — spawns as a real process, no D-Bus server issue
    exec kgx -- bash "$SETUP_SCRIPT"
elif command -v xterm &>/dev/null; then
    exec xterm -title "Toshy Setup" -e bash "$SETUP_SCRIPT"
else
    # Last resort: gnome-terminal with the --app-id workaround to force new instance
    exec gnome-terminal \
        --app-id org.gnome.Terminal.ToshySetup \
        --title "Toshy First-Time Setup" \
        -- bash "$SETUP_SCRIPT"
fi