#!/bin/bash
# This runs INSIDE the terminal window

SENTINEL="$HOME/.config/toshy/.image-setup-done"
[[ -f "$SENTINEL" ]] && exit 0

clear
echo "╔══════════════════════════════════════════════╗"
echo "║          Toshy First-Time Setup              ║"
echo "║   Mac-like keyboard shortcuts for Linux      ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "This will run once and takes a few minutes."
echo "Answer 'y' to any prompts about updating your system."
echo ""

TOSHY_TMP=$(mktemp -d)
trap 'rm -rf "$TOSHY_TMP"' EXIT

git clone --depth=1 https://github.com/RedBearAK/Toshy.git "$TOSHY_TMP/toshy"
cd "$TOSHY_TMP/toshy"

SESSION_TYPE=wayland yes | python3 ./setup_toshy.py install \
    --override-distro silverblue \
    --skip-native

EXIT_CODE=$?

mkdir -p "$(dirname "$SENTINEL")"

if [[ $EXIT_CODE -eq 0 ]]; then
    touch "$SENTINEL"
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║   Setup complete! Restart for                ║"
    echo "║   keyboard shortcuts to take effect.         ║"
    echo "╚══════════════════════════════════════════════╝"
else
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║   Setup encountered errors (exit: $EXIT_CODE)     ║"
    echo "║   Check output above. You can re-run via:    ║"
    echo "║   /usr/libexec/toshy-first-login-setup.sh   ║"
    echo "╚══════════════════════════════════════════════╝"
    # Don't write sentinel — allow retry
fi

echo ""
read -rp "Press Enter to close this window..."