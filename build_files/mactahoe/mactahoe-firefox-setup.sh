#!/bin/bash
SENTINEL="$HOME/.config/mactahoe/.firefox-done"
[[ -f "$SENTINEL" ]] && exit 0

REPO_DIR="/usr/share/MacTahoe-gtk-theme"

# Require at least one Firefox profile to exist before applying.
# If Firefox hasn't been opened yet this session, exit and retry on next login.
if ! compgen -G "${HOME}/.mozilla/firefox/*.default*" > /dev/null 2>&1; then
    exit 0
fi

cd "$REPO_DIR"
./tweaks.sh -f

mkdir -p "$(dirname "$SENTINEL")"
touch "$SENTINEL"
