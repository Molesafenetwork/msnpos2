#!/bin/bash
# nodestart.sh - POS System Starter

echo "--------------------------------------"
echo " POS System Startup Script"
echo "--------------------------------------"

# Go to POS folder
if [ ! -d "$HOME/pos-system" ]; then
    echo "Error: pos-system folder not found in $HOME."
    exit 1
fi
cd "$HOME/pos-system" || exit 1
echo "Moved into $(pwd)"

# Start POS server in background
echo "Starting POS server..."
node server.js &
SERVER_PID=$!
echo "POS server running in background (PID: $SERVER_PID)"
echo "Press CTRL+C to stop."

# Auto-start setup
read -p "Do you want to run this POS server every time you log in? (y/n): " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    AUTOSTART_PATH="$HOME/.config/autostart"
    mkdir -p "$AUTOSTART_PATH"
    cat > "$AUTOSTART_PATH/pos-server.desktop" <<EOL
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

echo "Done."
