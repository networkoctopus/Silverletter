#!/bin/bash
SENTINEL="$HOME/.config/toshy/.image-setup-done"
[[ -f "$SENTINEL" ]] && exit 0

echo "============================================"
echo "  Toshy First-Time Setup"
echo "  Mac-like keyboard shortcuts for Linux"
echo "============================================"
echo ""
echo "This will run once. Please wait..."
echo ""

TOSHY_TMP=$(mktemp -d)
git clone --depth=1 https://github.com/RedBearAK/Toshy.git "$TOSHY_TMP/toshy"
cd "$TOSHY_TMP/toshy"
SESSION_TYPE=wayland yes | python3 ./setup_toshy.py install \
    --override-distro silverblue \
    --skip-native
cd /
rm -rf "$TOSHY_TMP"

mkdir -p "$(dirname "$SENTINEL")"
touch "$SENTINEL"

echo ""
echo "============================================"
echo "  Setup complete. You can close this window."
echo "============================================"
read -p "Press Enter to close..."