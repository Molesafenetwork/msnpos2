#!/bin/bash
# init.sh - Installer for POS Startup Script (XFCE, Ubuntu 22)

POSUSER="posuser"
POS_HOME="/home/$POSUSER"
DESKTOP_PATH="$POS_HOME/Desktop"
SCRIPT_URL="https://raw.githubusercontent.com/Molesafenetwork/msnpos2/main/nodestart.sh"
DESKTOP_SCRIPT="$DESKTOP_PATH/nodestart.sh"

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
sudo -u "$POSUSER" curl -sSL "$SCRIPT_URL" -o "$DESKTOP_SCRIPT"
sudo chmod +x "$DESKTOP_SCRIPT"
sudo chown "$POSUSER:$POSUSER" "$DESKTOP_SCRIPT"

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

# Launch script interactively as posuser
echo "Launching nodestart.sh as $POSUSER..."
sudo -u "$POSUSER" bash -i "$DESKTOP_SCRIPT"
