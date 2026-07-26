#!/usr/bin/env bash
# Luani Client 1-Command Automated Installer for Linux
# Usage: curl -fsSL https://www.luani.fyi/install.sh | bash

set -e

LUANI_DIR="$HOME/.local/share/luani/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
BINARY_PATH="$LUANI_DIR/LuaniClient.x86_64"
DESKTOP_FILE="$DESKTOP_DIR/luani-protocol.desktop"
DOWNLOAD_URL="${LUANI_DOWNLOAD_URL:-https://www.luani.fyi/downloads/LuaniClient.x86_64}"

echo "======================================================"
echo "          🚀 Installing Luani Client...              "
echo "======================================================"

# 1. Create installation directories
mkdir -p "$LUANI_DIR"
mkdir -p "$DESKTOP_DIR"

# 2. Download latest LuaniClient binary
echo "[Luani Installer] Downloading LuaniClient binary from $DOWNLOAD_URL..."
if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$DOWNLOAD_URL" -o "$BINARY_PATH"
elif command -v wget >/dev/null 2>&1; then
    wget -qO "$BINARY_PATH" "$DOWNLOAD_URL"
else
    echo "❌ Error: Neither curl nor wget is installed. Please install curl or wget."
    exit 1
fi

# 3. Make binary executable
chmod +x "$BINARY_PATH"
echo "[Luani Installer] Binary installed successfully to $BINARY_PATH"

# 4. Create desktop protocol handler file
cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Name=Luani Client
Comment=Luani Sandbox Game Client & Protocol Handler
Exec=$BINARY_PATH "%u"
Icon=gamepad
Terminal=false
Type=Application
Categories=Game;
MimeType=x-scheme-handler/luani;
StartupNotify=true
EOF

chmod +x "$DESKTOP_FILE"

# 5. Register MIME protocol handler
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default luani-protocol.desktop x-scheme-handler/luani
    echo "[Luani Installer] Protocol handler 'luani://' registered with xdg-mime."
fi

echo ""
echo "======================================================"
echo " ✅ Luani Client Installation Complete!"
echo "    Binary: $BINARY_PATH"
echo "    Protocol: luani:// is now registered and active."
echo "    You can now join games directly from https://www.luani.fyi!"
echo "======================================================"
