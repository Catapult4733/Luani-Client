#!/bin/bash
set -e

echo "=================================================="
echo "      LUANI SANDBOX CLIENT - LINUX INSTALLER      "
echo "=================================================="

INSTALL_DIR="$HOME/.local/share/luani"
BIN_NAME="LuaniClient.x86_64"
DOWNLOAD_URL="https://www.luani.fyi/downloads/LuaniClient.x86_64"
DESKTOP_FILE="$HOME/.local/share/applications/luani.desktop"

mkdir -p "$INSTALL_DIR"
mkdir -p "$HOME/.local/share/applications"

echo "[1/4] Downloading Luani Client binary..."
curl -fsSL "$DOWNLOAD_URL" -o "$INSTALL_DIR/$BIN_NAME"

echo "[2/4] Setting executable permissions..."
chmod +x "$INSTALL_DIR/$BIN_NAME"

echo "[3/4] Registering luani:// protocol handler & desktop shortcut..."
cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Name=Luani
Comment=Luani Sandbox Gaming Platform & Studio
Exec=$INSTALL_DIR/$BIN_NAME %u
Icon=luani
Terminal=false
Type=Application
Categories=Game;
MimeType=x-scheme-handler/luani;
EOF

chmod +x "$DESKTOP_FILE"

if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default luani.desktop x-scheme-handler/luani || true
fi

echo "[4/4] Installation Complete!"
echo "Luani Client installed to: $INSTALL_DIR/$BIN_NAME"
echo "You can now launch Luani from your app menu or join games directly from luani.fyi!"
