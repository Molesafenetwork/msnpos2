#!/bin/bash
# nodestart.sh - POS System Starter (XFCE Compatible)

echo "--------------------------------------"
echo " POS System Startup Script"
echo "--------------------------------------"
echo "This script will start your POS server"
echo "and optionally set it to start at login."
echo

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

echo
# Ask about auto-start
while true; do
    read -rp "Do you want to run this POS server every time you log in? (y/n): " choice
    case "$choice" in
        [Yy]* )
            AUTOSTART_PATH="$HOME/.config/autostart"
            mkdir -p "$AUTOSTART_PATH"
            cat > "$AUTOSTART_PATH/pos-server.desktop" <<EOL
[Desktop Entry]
Type=Application
Name=POS Server
Exec=xfce4-terminal --command="bash -ic 'cd \$HOME/pos-system && node server.js'"
X-GNOME-Autostart-enabled=true
EOL
            chmod +x "$AUTOSTART_PATH/pos-server.desktop"
            echo "Auto-start enabled."
            break;;
        [Nn]* )
            echo "Auto-start skipped."
            break;;
        * )
            echo "Please answer y or n.";;
    esac
done

echo "Done."
