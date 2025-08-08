#!/bin/bash
# POS System Starter Script for Ubuntu 20.04+
# Downloads to Desktop, runs POS server, and optionally sets up auto-start
#run with: curl -sSL https://raw.githubusercontent.com/Molesafenetwork/msnpos2/main/nodestart.sh | bash

echo "--------------------------------------"
echo " POS System Startup Script"
echo "--------------------------------------"
echo "This script will:"
echo " - Navigate to the POS system folder"
echo " - Run 'node server.js'"
echo " - Optionally set up auto-start at login"
echo

# Step 1: Navigate to POS directory
if [ ! -d "$HOME/pos-system" ]; then
    echo "Error: pos-system folder not found in $HOME."
    echo "Please clone or create it first."
    exit 1
fi
cd "$HOME/pos-system" || exit 1
echo "Moved into $(pwd)"

# Step 2: Start server
echo
echo "Starting POS server in background..."
node server.js &
SERVER_PID=$!
echo "POS server running (PID: $SERVER_PID)"
echo "Press CTRL+C to stop it."

# Step 3: Ask for auto-start
echo
read -p "Do you want the POS server to auto-start every login? (y/n): " choice

if [[ "$choice" =~ ^[Yy]$ ]]; then
    echo "Setting up auto-start..."
    AUTOSTART_PATH="$HOME/.config/autostart"
    mkdir -p "$AUTOSTART_PATH"

    DESKTOP_FILE="$AUTOSTART_PATH/pos-server.desktop"
    cat > "$DESKTOP_FILE" <<EOL
[Desktop Entry]
Type=Application
Name=POS Server
Exec=gnome-terminal -- bash -c "cd $HOME/pos-system && node server.js"
X-GNOME-Autostart-enabled=true
EOL

    echo "Auto-start enabled."
else
    echo "Auto-start skipped."
fi

# Step 4: Ensure a copy exists on Desktop
DESKTOP_SCRIPT="$HOME/Desktop/nodestart.sh"
cp "$0" "$DESKTOP_SCRIPT"
chmod +x "$DESKTOP_SCRIPT"
echo "A copy of this script is now on your Desktop."

echo
echo "Setup complete."
