#!/usr/bin/env bash
set -e

# Script to register the luani:// URI protocol handler on Linux systems

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

CLIENT_EXEC="$ROOT_DIR/client_and_studio/bin/luani.x86_64"

# Fallback to godot binary if compiled binary does not yet exist
if [ ! -f "$CLIENT_EXEC" ]; then
    GODOT_BIN=$(which godot 2>/dev/null || echo "")
    if [ -n "$GODOT_BIN" ]; then
        CLIENT_EXEC="$GODOT_BIN --path $ROOT_DIR/client_and_studio"
    else
        CLIENT_EXEC="$ROOT_DIR/client_and_studio/luani.x86_64"
    fi
fi

APP_DIR="$HOME/.local/share/applications"
mkdir -p "$APP_DIR"

DESKTOP_FILE="$APP_DIR/luani.desktop"

echo "[Luani Protocol Register] Target executable: $CLIENT_EXEC"
echo "[Luani Protocol Register] Writing desktop entry to: $DESKTOP_FILE"

cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Name=Luani Client
Comment=Luani Sandbox Gaming Client & Studio
Exec=$CLIENT_EXEC "%u"
Terminal=false
Type=Application
Categories=Game;Network;
MimeType=x-scheme-handler/luani;
NoDisplay=true
StartupNotify=true
EOF

chmod +x "$DESKTOP_FILE"

echo "[Luani Protocol Register] Registering x-scheme-handler/luani with xdg-mime..."
xdg-mime default luani.desktop x-scheme-handler/luani

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APP_DIR"
fi

echo "[Luani Protocol Register] Protocol registration complete!"
echo "Test invocation with: xdg-open \"luani://join?server=127.0.0.1:7777&auth=test_token\""
