#!/usr/bin/env bash
# Luani Client 1-Command Automated Installer & Updater for Linux
# Usage: curl -fsSL https://www.luani.fyi/install.sh | bash

set -e

LUANI_DIR="$HOME/.local/share/luani/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
LOCAL_BIN_DIR="$HOME/.local/bin"
BINARY_PATH="$LUANI_DIR/LuaniClient.x86_64"
DESKTOP_FILE="$DESKTOP_DIR/luani-protocol.desktop"
DOWNLOAD_URL="${LUANI_DOWNLOAD_URL:-https://www.luani.fyi/downloads/LuaniClient.x86_64}"

echo "======================================================"
if [ -f "$BINARY_PATH" ]; then
    echo "          🔄 Updating Luani Client to Latest Version..."
else
    echo "          🚀 Installing Luani Client..."
fi
echo "======================================================"

# 1. Create installation directories
mkdir -p "$LUANI_DIR"
mkdir -p "$DESKTOP_DIR"
mkdir -p "$LOCAL_BIN_DIR"

# 2. Download latest LuaniClient binary
echo "[Luani Installer] Downloading latest LuaniClient binary from $DOWNLOAD_URL..."
if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$DOWNLOAD_URL" -o "$BINARY_PATH"
elif command -v wget >/dev/null 2>&1; then
    wget -qO "$BINARY_PATH" "$DOWNLOAD_URL"
else
    echo "❌ Error: Neither curl nor wget is installed. Please install curl or wget."
    exit 1
fi

# 3. Make binary executable and link to ~/.local/bin
chmod +x "$BINARY_PATH"
ln -sf "$BINARY_PATH" "$LOCAL_BIN_DIR/luaniclient"
echo "[Luani Installer] Binary updated/installed successfully at $BINARY_PATH"

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
MimeType=x-scheme-handler/luani;x-scheme-handler/luani-studio;
StartupNotify=true
EOF

chmod +x "$DESKTOP_FILE"

# 5. Register MIME protocol handlers for luani:// and luani-studio://
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default luani-protocol.desktop x-scheme-handler/luani
    xdg-mime default luani-protocol.desktop x-scheme-handler/luani-studio
    echo "[Luani Installer] Protocol handlers 'luani://' and 'luani-studio://' registered."
fi

echo ""
echo "======================================================"
echo " ✅ Luani Client Ready & Up-To-Date!"
echo "    Binary: $BINARY_PATH"
echo "    Command: luaniclient"
echo "    Protocol: luani:// & luani-studio:// registered."
echo "    You can now join games directly from https://www.luani.fyi!"
echo "======================================================"
