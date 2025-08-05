#!/bin/bash
# Orange Pi 3B POS System Setup Script for Ubuntu Desktop 22+
# Compatible with RK3566 chipset and Ubuntu Desktop
# Run with: curl -sSL https://raw.githubusercontent.com/Molesafenetwork/msnpos2/refs/heads/main/oemubfdesk.sh | bash

set -e


echo "                MOLE - POS - ORANGEPI 3b MSN POS                 "


# Check if running on desktop environment
if [ -z "$XDG_CURRENT_DESKTOP" ]; then
    echo "Warning: No desktop environment detected. This script is designed for Ubuntu Desktop."
fi

# Update system
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# Install essential packages for Ubuntu Desktop
echo "Installing essential packages..."
sudo apt install -y curl git chromium-browser unclutter sed nano \
    wmctrl xdotool gnome-session-bin dbus-x11 x11-utils \
    systemd-timesyncd openssh-server build-essential ufw snapd

# Install Node.js 14.x-18.x LTS from NodeSource repository (14 is matching package.json requirements 18 is safer)
echo "Installing Node.js 18.x LTS..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Verify Node.js installation
echo "Node.js version: $(node --version)"
echo "NPM version: $(npm --version)"

# Install PM2 globally
echo "Installing PM2..."
sudo npm install -g pm2

# Create POS user
echo "Creating POS user..."
sudo useradd -m -s /bin/bash posuser
echo "posuser:posuser123" | sudo chpasswd
# Add posuser to necessary groups
sudo usermod -a -G sudo,audio,video posuser

# Clone your POS repository
echo "Cloning POS application..."
cd /home/posuser
sudo -u posuser git clone https://github.com/Molesafenetwork/msnpos2.git pos-system
cd pos-system

# Install Node.js dependencies and setup crypto key
echo "Installing Node.js dependencies and generating crypto key..."
# Clear npm cache first
sudo -u posuser npm cache clean --force

# Create package.json if it doesn't exist to avoid issues
cd /home/posuser/pos-system
if [ ! -f package.json ]; then
    echo "Creating basic package.json..."
    sudo -u posuser tee package.json << 'PKGJSON'
{
  "name": "advanced-invoice-generator",
  "version": "1.0.0",
  "description": "Advanced invoice generation system with encryption and web interface",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "axios": "^1.8.2",
    "bcrypt": "^5.0.1",
    "body-parser": "^1.19.0",
    "chart.js": "^3.7.1",
    "compression": "^1.8.1",
    "cookie-parser": "^1.4.7",
    "cors": "^2.8.5",
    "crypto-js": "^4.1.1",
    "dotenv": "^16.4.5",
    "ejs": "^3.1.6",
    "express": "^4.21.2",
    "express-ejs-layouts": "^2.5.1",
    "express-rate-limit": "^5.3.0",
    "express-session": "^1.18.2",
    "fs-extra": "^10.0.0",
    "helmet": "^4.6.0",
    "moment": "^2.29.1",
    "morgan": "^1.10.1",
    "multer": "^2.0.2",
    "pdfkit": "^0.13.0",
    "sharp": "^0.32.1",
    "uuid": "^8.3.2"
  },
  "engines": {
    "node": "18.x"
  },
  "license": "MIT"
}
PKGJSON
fi

# Install dependencies with force to resolve conflicts
echo "Installing crypto-js..."
sudo -u posuser npm install crypto-js --save --force

# Install other common POS dependencies
echo "Installing common POS dependencies..."
sudo -u posuser npm install express body-parser cors --save --force || echo "Some packages may have warnings, continuing..."

# Run npm audit fix to resolve security issues
sudo -u posuser npm audit fix --force || echo "Audit fix completed with warnings"

ENV_PATH=".env"
cd /home/posuser/pos-system

# Generate crypto key using system Node.js
CRYPTO_KEY=$(sudo -u posuser bash -c 'cd /home/posuser/pos-system && node -e "const CryptoJS = require(\"crypto-js\"); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());"')

if [ ! -f "$ENV_PATH" ]; then
    echo "Creating new .env with generated encryption key..."
    sudo -u posuser tee "$ENV_PATH" <<EOF
# POS System Configuration
MOLE_SAFE_USERS=Admin1234#:Admin1234#,worker1:worker1!
SESSION_SECRET=123485358953
ENCRYPTION_KEY=$CRYPTO_KEY
COMPANY_NAME=Mole Safe Network
COMPANY_ADDRESS=123 random road
COMPANY_PHONE=61756666665
COMPANY_EMAIL=support@mole-safe.net
COMPANY_ABN=333333333
EOF
else
    echo ".env exists, checking for placeholder..."
    if grep -q 'ENCRYPTION_KEY=\$CRYPTO_KEY' "$ENV_PATH"; then
        echo "Found placeholder. Replacing with generated key..."
        sudo -u posuser sed -i "s|ENCRYPTION_KEY=\$CRYPTO_KEY|ENCRYPTION_KEY=$CRYPTO_KEY|" "$ENV_PATH"
    else
        echo "ENCRYPTION_KEY already set. Skipping key replacement."
    fi
fi

# Log keygen command to history
sudo -u posuser bash -c 'echo '\''cd /home/posuser/pos-system && node -e "const CryptoJS = require(\"crypto-js\"); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());"'\'' >> /home/posuser/.bash_history'

echo "✅ Encryption key process completed."

# Ensure .data directory exists
echo "Making sure .data directory exists"
sudo -u posuser mkdir -p public/.data
sudo chmod 755 public/.data
echo "PDF storage configured at: ./public/.data"

# Create custom commands directory
echo "Setting up custom commands..."
sudo mkdir -p /usr/local/bin

# Create edit-env command
sudo tee /usr/local/bin/edit-env << 'EOF'
#!/bin/bash
gnome-terminal -- nano /home/posuser/pos-system/.env
EOF

# Create setup-tailnet command
sudo tee /usr/local/bin/setup-tailnet << 'EOF'
#!/bin/bash
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh
echo "Run 'sudo tailscale up' to authenticate"
EOF

# Create generate-key command
sudo tee /usr/local/bin/generate-key << 'EOF'
#!/bin/bash
cd /home/posuser/pos-system
echo "Generating new encryption key..."
NEW_KEY=$(node -e "const CryptoJS = require('crypto-js'); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());")
echo "New encryption key: $NEW_KEY"
echo "To use this key, run: edit-env"
echo "Then update ENCRYPTION_KEY=$NEW_KEY"
EOF

# Create check-env command
sudo tee /usr/local/bin/check-env << 'EOF'
#!/bin/bash
echo "Current .env configuration:"
cat /home/posuser/pos-system/.env
EOF

# Create pdf-storage command
sudo tee /usr/local/bin/pdf-storage << 'EOF'
#!/bin/bash
echo "PDF storage directory contents:"
ls -la /home/posuser/pos-system/public/.data/
echo ""
echo "Storage usage:"
du -sh /home/posuser/pos-system/public/.data/
EOF

# Create pos-logs command
sudo tee /usr/local/bin/pos-logs << 'EOF'
#!/bin/bash
echo "POS System logs (press Ctrl+C to exit):"
journalctl -u pos-system -f
EOF

# Create restart-pos command
sudo tee /usr/local/bin/restart-pos << 'EOF'
#!/bin/bash
echo "Restarting POS system and kiosk..."
sudo systemctl restart pos-system pos-kiosk
echo "POS system restarted"
EOF

# Create admin-mode command
sudo tee /usr/local/bin/admin-mode << 'EOF'
#!/bin/bash
# Toggle between POS kiosk and admin mode
PID=$(pgrep -f "chromium.*kiosk.*localhost:3000")
if [ ! -z "$PID" ]; then
    echo "Switching to admin mode..."
    kill $PID
    gnome-terminal --full-screen
else
    echo "Starting POS kiosk mode..."
    /usr/local/bin/start-pos-kiosk &
fi
EOF

# Create start-pos-kiosk command
sudo tee /usr/local/bin/start-pos-kiosk << 'EOF'
#!/bin/bash
# Wait for POS server to be ready
while ! curl -s http://localhost:3000 > /dev/null; do
  sleep 1
done

# Hide cursor
unclutter -idle 1 &

# Start Chromium in kiosk mode
chromium-browser \
  --kiosk \
  --no-first-run \
  --disable-restore-session-state \
  --disable-infobars \
  --disable-translate \
  --disable-features=TranslateUI \
  --disable-dev-shm-usage \
  --no-sandbox \
  --disk-cache-dir=/tmp \
  --aggressive-cache-discard \
  --start-maximized \
  --window-position=0,0 \
  --display=:0 \
  http://localhost:3000 &

# Disable screen blanking
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.session idle-delay 0
EOF

# Make commands executable
sudo chmod +x /usr/local/bin/edit-env
sudo chmod +x /usr/local/bin/setup-tailnet
sudo chmod +x /usr/local/bin/generate-key
sudo chmod +x /usr/local/bin/check-env
sudo chmod +x /usr/local/bin/pdf-storage
sudo chmod +x /usr/local/bin/pos-logs
sudo chmod +x /usr/local/bin/restart-pos
sudo chmod +x /usr/local/bin/admin-mode
sudo chmod +x /usr/local/bin/start-pos-kiosk

# Create POS startup service
sudo tee /etc/systemd/system/pos-system.service << 'EOF'
[Unit]
Description=POS System Node.js Application
After=network.target

[Service]
Type=simple
User=posuser
WorkingDirectory=/home/posuser/pos-system
Environment=NODE_ENV=production
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Create POS kiosk service for desktop environment
sudo tee /etc/systemd/system/pos-kiosk.service << 'EOF'
[Unit]
Description=POS Kiosk Display
After=pos-system.service graphical-session.target
Wants=pos-system.service
Requires=graphical.target

[Service]
Type=forking
User=posuser
Group=posuser
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/1001
WorkingDirectory=/home/posuser
ExecStartPre=/bin/sleep 10
ExecStart=/usr/local/bin/start-pos-kiosk
Restart=always
RestartSec=5

[Install]
WantedBy=graphical.target
EOF

# Create desktop autostart entry for POS kiosk
sudo mkdir -p /home/posuser/.config/autostart
sudo tee /home/posuser/.config/autostart/pos-kiosk.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=POS Kiosk
Comment=Start POS system in kiosk mode
Exec=/usr/local/bin/start-pos-kiosk
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
EOF

# Create keyboard shortcut script
sudo tee /home/posuser/setup-hotkeys.sh << 'EOF'
#!/bin/bash
# Setup custom keyboard shortcuts for Ubuntu Desktop
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Admin Mode Toggle'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command '/usr/local/bin/admin-mode'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Ctrl><Alt>t'
EOF

sudo chmod +x /home/posuser/setup-hotkeys.sh

# Create custom bashrc for posuser with POS commands
sudo tee /home/posuser/.bashrc << 'EOF'
# Custom POS Terminal Commands
alias edit-env='nano /home/posuser/pos-system/.env && sudo systemctl restart pos-system'
alias setup-tailnet='curl -fsSL https://tailscale.com/install.sh | sh && echo "Run: sudo tailscale up"'
alias restart-pos='sudo systemctl restart pos-system pos-kiosk'
alias pos-logs='journalctl -u pos-system -f'
alias generate-key='cd /home/posuser/pos-system && node -e "const CryptoJS = require(\"crypto-js\"); const key = CryptoJS.lib.WordArray.random(32); console.log(\"New key:\", key.toString());"'
alias check-env='cat /home/posuser/pos-system/.env'
alias pdf-storage='ls -la /home/posuser/pos-system/public/.data/'
alias admin-mode='/usr/local/bin/admin-mode'
alias kiosk-mode='/usr/local/bin/start-pos-kiosk'

# Terminal customization
PS1='\[\033[01;32m\]POS-ADMIN\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

echo "=== POS Admin Terminal ==="
echo "Available commands:"
echo "  edit-env      - Edit environment variables"
echo "  setup-tailnet - Install and setup Tailscale" 
echo "  restart-pos   - Restart POS services"
echo "  pos-logs      - View POS application logs"
echo "  generate-key  - Generate new encryption key"
echo "  check-env     - View current .env settings"
echo "  pdf-storage   - Check PDF storage directory"
echo "  admin-mode    - Toggle between kiosk and admin mode"
echo "  kiosk-mode    - Start POS kiosk mode"
echo ""
echo "Hotkey: Ctrl+Alt+T to toggle admin mode"
echo "=========================="
EOF

# Create POS user profile setup
sudo tee /home/posuser/.profile << 'EOF'
# Setup POS environment
export PATH="/usr/local/bin:$PATH"

# Auto-setup hotkeys on first login
if [ ! -f ~/.hotkeys-setup ]; then
    /home/posuser/setup-hotkeys.sh
    touch ~/.hotkeys-setup
fi
EOF

# Set proper permissions
sudo chown -R posuser:posuser /home/posuser
sudo chmod +x /home/posuser/.profile

# Configure auto-login for posuser
sudo mkdir -p /etc/gdm3
sudo tee /etc/gdm3/custom.conf << 'EOF'
[daemon]
AutomaticLoginEnable = true
AutomaticLogin = posuser

[security]

[xdmcp]

[chooser]

[debug]
EOF

# Enable services
sudo systemctl daemon-reload
sudo systemctl enable pos-system

# Disable Ubuntu's automatic updates to prevent interruptions
sudo systemctl disable unattended-upgrades
sudo systemctl mask unattended-upgrades

# Configure firewall for POS system
sudo ufw allow 3000/tcp
sudo ufw allow ssh
echo "y" | sudo ufw enable

echo ""
echo "=== SETUP COMPLETE ==="
echo ""
echo "IMPORTANT: Reboot the system to start POS kiosk mode"
echo "sudo reboot"
echo ""
echo "=== POS SYSTEM INFORMATION ==="
echo "• POS will auto-start in kiosk mode on boot"
echo "• Access URL: http://localhost:3000"
echo "• POS User: posuser / posuser123"
echo ""
echo "=== ADMIN ACCESS ==="
echo "• Hotkey: Ctrl+Alt+T (toggle admin/kiosk mode)"
echo "• Terminal: Open terminal and run any pos command"
echo "• SSH: ssh posuser@[ip-address]"
echo ""
echo "=== AVAILABLE COMMANDS ==="
echo "• edit-env      - Edit configuration"
echo "• setup-tailnet - Install Tailscale VPN" 
echo "• restart-pos   - Restart POS system"
echo "• pos-logs      - View system logs"
echo "• generate-key  - Generate new encryption key"
echo "• check-env     - View current settings"
echo "• pdf-storage   - Check PDF storage"
echo "• admin-mode    - Toggle kiosk/admin mode"
echo ""
echo "System ready for reboot!"
