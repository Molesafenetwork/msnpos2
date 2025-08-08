#!/bin/bash
# pos-hotkeys.sh - POS Hotkeys Setup & Autostart for XFCE

# Required dependencies:
# sudo apt install xdotool wmctrl xbindkeys evince -y

DOWNLOADS_DIR="$HOME/Downloads"
VIEWER="evince"
KIOSK_WINDOW="Chromium"

# Kill any running xbindkeys first (to avoid duplicates)
pkill xbindkeys 2>/dev/null

# Create or overwrite xbindkeys config file
cat > "$HOME/.xbindkeysrc" <<'EOL'
# Send Alt+Left (Back) to Chromium window
"xdotool search --name Chromium windowactivate --sync key Alt+Left"
    Left

"xdotool search --name Chromium windowactivate --sync key Alt+Left"
    z

# Send Alt+Right (Forward) to Chromium window
"xdotool search --name Chromium windowactivate --sync key Alt+Right"
    Right

"xdotool search --name Chromium windowactivate --sync key Alt+Right"
    x

# Show/hide invoice preview with I key
# This script launches or kills the viewer

bash -c '
    # Find if viewer is running
    PID=$(pgrep -f evince)
    if [ -z "$PID" ]; then
        # No viewer, open latest invoice
        FILE=$(ls -t ~/Downloads | head -n1)
        if [ -n "$FILE" ]; then
            evince ~/Downloads/"$FILE" &
        fi
    else
        # Viewer running, kill it
        kill $PID
    fi
'
    i

# Close invoice viewer with Escape
bash -c '
    PID=$(pgrep -f evince)
    if [ -n "$PID" ]; then
        kill $PID
    fi
'
    Escape
EOL

echo "xbindkeys config file created at ~/.xbindkeysrc"

# Start xbindkeys in background
xbindkeys

echo "xbindkeys started."

# Setup autostart for xbindkeys on login (XFCE)
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

cat > "$AUTOSTART_DIR/xbindkeys.desktop" <<EOL
[Desktop Entry]
Type=Application
Name=xbindkeys
Exec=xbindkeys
Comment=Start xbindkeys for POS hotkeys
X-GNOME-Autostart-enabled=true
EOL

echo "Autostart entry created for xbindkeys."

echo "POS hotkeys setup complete and will persist on reboot."
