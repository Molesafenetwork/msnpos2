#!/bin/bash
# init.sh - Installer for POS Startup Script (XFCE, Ubuntu 22)
POSUSER="posuser"
POS_HOME="/home/$POSUSER"
DESKTOP_PATH="$POS_HOME/Desktop"
SCRIPT_URL="https://raw.githubusercontent.com/Molesafenetwork/msnpos2/main/nodestart.sh"
DESKTOP_SCRIPT="$DESKTOP_PATH/nodestart.sh"
DESKTOP_SCRIPT_RAW="$DESKTOP_PATH/nodestart-raw.sh"

echo "=== Setting up POS server for user: $POSUSER ==="

# Make sure posuser exists
if ! id "$POSUSER" &>/dev/null; then
    echo "Error: user '$POSUSER' does not exist."
    exit 1
fi

# Create Desktop folder if missing
sudo -u "$POSUSER" mkdir -p "$DESKTOP_PATH"

# Download nodestart.sh to posuser's Desktop
echo "Downloading nodestart.sh to $DESKTOP_SCRIPT..."
sudo -u "$POSUSER" curl -sSL "$SCRIPT_URL" -o "$DESKTOP_SCRIPT_RAW"

# Create XFCE terminal wrapper script
echo "Creating XFCE terminal wrapper..."
sudo -u "$POSUSER" tee "$DESKTOP_SCRIPT" << 'EOF'
#!/bin/bash
# XFCE Terminal wrapper for nodestart.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW_SCRIPT="$SCRIPT_DIR/nodestart-raw.sh"

# Check if we're already running in a terminal
if [ -t 1 ]; then
    # We're in a terminal, run directly
    echo "Running nodestart.sh in current terminal..."
    bash "$RAW_SCRIPT"
else
    # Not in terminal, open XFCE terminal
    echo "Opening nodestart.sh in XFCE terminal..."
    if command -v xfce4-terminal >/dev/null 2>&1; then
        xfce4-terminal --hold --title "POS Node Startup Script" --execute bash "$RAW_SCRIPT"
    elif command -v gnome-terminal >/dev/null 2>&1; then
        # Fallback to gnome-terminal
        gnome-terminal --title "POS Node Startup Script" -- bash "$RAW_SCRIPT"
    else
        # Ultimate fallback - try to run in background
        echo "No suitable terminal emulator found. Running script directly..."
        bash "$RAW_SCRIPT"
    fi
fi
EOF

# Set permissions for both scripts
sudo chmod +x "$DESKTOP_SCRIPT"
sudo chmod +x "$DESKTOP_SCRIPT_RAW"
sudo chown "$POSUSER:$POSUSER" "$DESKTOP_SCRIPT"
sudo chown "$POSUSER:$POSUSER" "$DESKTOP_SCRIPT_RAW"

# Create desktop entry file for better desktop integration
DESKTOP_ENTRY="$DESKTOP_PATH/NodeStart.desktop"
sudo -u "$POSUSER" tee "$DESKTOP_ENTRY" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=POS Node Startup
Comment=Start POS Node.js application
Exec=$DESKTOP_SCRIPT
Icon=utilities-terminal
Terminal=false
Categories=Development;
StartupNotify=true
EOF

sudo chmod +x "$DESKTOP_ENTRY"
sudo chown "$POSUSER:$POSUSER" "$DESKTOP_ENTRY"

echo "✅ Created terminal wrapper script: $DESKTOP_SCRIPT"
echo "✅ Created desktop entry: $DESKTOP_ENTRY"

# Install NVM for posuser
echo "Installing NVM for $POSUSER..."
sudo -u "$POSUSER" bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'

# Add NVM to posuser's bashrc
sudo -u "$POSUSER" bash -c 'echo "export NVM_DIR=\$HOME/.nvm" >> ~/.bashrc'
sudo -u "$POSUSER" bash -c 'echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"" >> ~/.bashrc'

# Install Node 18 for posuser
echo "Installing Node.js 18..."
sudo -u "$POSUSER" bash -ic 'nvm install 18'

# Run npm install in pos-system as posuser
if [ -d "$POS_HOME/pos-system" ]; then
    echo "Running npm install in pos-system..."
    sudo -u "$POSUSER" bash -ic "cd ~/pos-system && npm install"
else
    echo "Warning: $POS_HOME/pos-system does not exist."
fi

# Check if we're in a desktop environment for auto-launch
if [ -n "$DISPLAY" ] && [ -n "$XDG_CURRENT_DESKTOP" ]; then
    echo "Desktop environment detected. You can now:"
    echo "  1. Double-click 'NodeStart.desktop' on the desktop"
    echo "  2. Double-click 'nodestart.sh' script"
    echo "  3. Run manually: $DESKTOP_SCRIPT"
    echo ""
    echo "The script will automatically open in XFCE terminal."
    
    # Ask if user wants to launch now
    read -p "Launch nodestart.sh now? [y/N]: " launch_now
    if [[ "$launch_now" =~ ^[Yy]$ ]]; then
        echo "Launching nodestart.sh as $POSUSER in XFCE terminal..."
        sudo -u "$POSUSER" DISPLAY="$DISPLAY" "$DESKTOP_SCRIPT" &
    fi
else
    # No desktop environment, launch in current terminal
    echo "No desktop environment detected. Launching nodestart.sh in current terminal..."
    sudo -u "$POSUSER" bash -i "$DESKTOP_SCRIPT_RAW"
fi

echo ""
echo "=== Setup Complete ==="
echo "Scripts created:"
echo "  • $DESKTOP_SCRIPT (terminal wrapper)"
echo "  • $DESKTOP_SCRIPT_RAW (original script)"
echo "  • $DESKTOP_ENTRY (desktop entry)"
echo ""
echo "Usage:"
echo "  • Desktop: Double-click NodeStart.desktop icon"
echo "  • Terminal: bash $DESKTOP_SCRIPT"
echo "  • Direct: bash $DESKTOP_SCRIPT_RAW"
