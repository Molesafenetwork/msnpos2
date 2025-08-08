#!/bin/bash
# Orange Pi 3B POS System Setup Script for Ubuntu Focal (20.04)
# NO SYSTEM UPGRADE - Uses existing packages where possible
# Compatible with RK3566 chipset and XFCE Desktop Environment
# Run with: curl -sSL https://raw.githubusercontent.com/Molesafenetwork/msnpos2/refs/heads/main/oemubfdesk20.sh | bash
#set -e

echo "                MOLE - POS - ORANGEPI 3b MSN POS (FOCAL - NO SNAP)                 "

# Check Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "unknown")
echo "Detected Ubuntu version: $UBUNTU_VERSION (focal)"

# Check if running on XFCE desktop environment
if [ "$XDG_CURRENT_DESKTOP" = "XFCE" ]; then
    echo "✅ XFCE Desktop detected - configuring for XFCE environment"
elif [ -z "$XDG_CURRENT_DESKTOP" ]; then
    echo "⚠️ Warning: No desktop environment detected. Assuming XFCE."
else
    echo "⚠️ Warning: Detected $XDG_CURRENT_DESKTOP. This script is optimized for XFCE."
fi

# Update package lists only (no system upgrade)
echo "Refreshing package lists (no system upgrade)..."
sudo apt update

# Install essential packages for XFCE Desktop (focal compatible)
echo "Installing essential packages for XFCE..."
sudo apt install -y curl git unclutter sed nano \
    wmctrl xdotool lightdm x11-utils xfce4-session \
    systemd-timesyncd openssh-server build-essential ufw \
    xfce4-terminal xfce4-panel xfce4-settings xinit xorg

# Install browser - try multiple options, avoid snap
echo "Installing web browser (avoiding snap)..."
BROWSER_INSTALLED=false

# Try chromium-browser first
if apt-cache show chromium-browser >/dev/null 2>&1; then
    echo "Installing chromium-browser from apt..."
    sudo apt install -y chromium-browser && BROWSER_INSTALLED=true
fi

# Try chromium if chromium-browser failed
if [ "$BROWSER_INSTALLED" = false ] && apt-cache show chromium >/dev/null 2>&1; then
    echo "Installing chromium from apt..."
    sudo apt install -y chromium && BROWSER_INSTALLED=true
fi

# Try firefox as fallback
if [ "$BROWSER_INSTALLED" = false ]; then
    echo "Installing Firefox as fallback browser..."
    sudo apt install -y firefox && BROWSER_INSTALLED=true
    # Create chromium-browser symlink pointing to firefox
    sudo ln -sf /usr/bin/firefox /usr/local/bin/chromium-browser
fi

# Last resort - download chromium manually
if [ "$BROWSER_INSTALLED" = false ]; then
    echo "Installing Chromium manually for ARM64..."
    cd /tmp
    wget -O chromium-browser.deb https://launchpad.net/ubuntu/+archive/primary/+files/chromium-browser_1%3a85.0.4183.83-0ubuntu0.20.04.3_arm64.deb
    sudo dpkg -i chromium-browser.deb || sudo apt-get install -f -y
    BROWSER_INSTALLED=true
fi

if [ "$BROWSER_INSTALLED" = true ]; then
    echo "✅ Browser installation completed"
else
    echo "❌ Browser installation failed - will use alternative method"
fi

# Install Node.js 18.x LTS from NodeSource repository (focal compatible)
echo "Installing Node.js 18.x LTS for Ubuntu focal..."
# Check if Node.js is already installed
if command -v node >/dev/null 2>&1; then
    CURRENT_NODE_VERSION=$(node --version)
    echo "Current Node.js version: $CURRENT_NODE_VERSION"
    if [[ "$CURRENT_NODE_VERSION" =~ ^v18\. ]]; then
        echo "Node.js 18.x already installed, skipping..."
    else
        echo "Upgrading Node.js to 18.x..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt install -y nodejs
    fi
else
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# Verify Node.js installation
echo "Node.js version: $(node --version)"
echo "NPM version: $(npm --version)"

# Install PM2 globally if not already installed
if ! command -v pm2 >/dev/null 2>&1; then
    echo "Installing PM2..."
    sudo npm install -g pm2
else
    echo "PM2 already installed: $(pm2 --version)"
fi

# Create POS user if it doesn't exist
if ! id "posuser" &>/dev/null; then
    echo "Creating POS user..."
    sudo useradd -m -s /bin/bash posuser
    echo "posuser:posuser123" | sudo chpasswd
    # Add posuser to necessary groups (focal compatible)
    sudo usermod -a -G sudo,audio,video posuser
else
    echo "User 'posuser' already exists"
fi

# Clone or update POS repository
echo "Setting up POS application..."
if [ -d "/home/posuser/pos-system" ]; then
    echo "POS system directory exists, pulling latest changes..."
    cd /home/posuser/pos-system
    sudo -u posuser git pull
else
    echo "Cloning POS application..."
    cd /home/posuser
    sudo -u posuser git clone https://github.com/Molesafenetwork/msnpos2.git pos-system
fi

cd /home/posuser/pos-system

# Install Node.js dependencies with compatibility for older systems
echo "Installing Node.js dependencies for focal..."
# Clear npm cache first
sudo -u posuser npm cache clean --force

# Create package.json if it doesn't exist
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
    "axios": "^1.6.0",
    "bcrypt": "^5.0.1",
    "body-parser": "^1.19.0",
    "chart.js": "^3.7.1",
    "compression": "^1.7.4",
    "cookie-parser": "^1.4.6",
    "cors": "^2.8.5",
    "crypto-js": "^4.1.1",
    "dotenv": "^16.0.0",
    "ejs": "^3.1.6",
    "express": "^4.18.0",
    "express-ejs-layouts": "^2.5.1",
    "express-rate-limit": "^5.3.0",
    "express-session": "^1.17.0",
    "fs-extra": "^10.0.0",
    "helmet": "^4.6.0",
    "moment": "^2.29.1",
    "morgan": "^1.10.0",
    "multer": "^1.4.5",
    "pdfkit": "^0.13.0",
    "sharp": "^0.30.0",
    "uuid": "^8.3.2"
  },
  "engines": {
    "node": "18.x"
  },
  "license": "MIT"
}
PKGJSON
fi

# Install dependencies with older versions for focal compatibility
echo "Installing crypto-js and core dependencies..."
sudo -u posuser npm install crypto-js express body-parser cors --save || echo "Some packages may have warnings, continuing..."

# Try to install remaining dependencies with fallbacks
echo "Installing remaining dependencies..."
sudo -u posuser npm install || echo "Some optional dependencies may have failed, continuing..."

# Run npm audit fix but don't force (safer for older systems)
sudo -u posuser npm audit fix || echo "Audit fix completed with warnings"

ENV_PATH=".env"
cd /home/posuser/pos-system

# Generate crypto key using system Node.js
if [ -f "$ENV_PATH" ] && grep -q 'ENCRYPTION_KEY=' "$ENV_PATH" && ! grep -q 'ENCRYPTION_KEY=$' "$ENV_PATH"; then
    echo ".env file exists with encryption key, skipping key generation..."
else
    echo "Generating encryption key..."
    CRYPTO_KEY=$(sudo -u posuser bash -c 'cd /home/posuser/pos-system && node -e "const CryptoJS = require(\"crypto-js\"); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());"' 2>/dev/null || echo "fallback_key_$(date +%s)")
    
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
        fi
    fi
fi

echo "✅ Encryption key process completed."

# Ensure .data directory exists
echo "Making sure .data directory exists"
sudo -u posuser mkdir -p public/.data
sudo chmod 755 public/.data
echo "PDF storage configured at: ./public/.data"

# Create custom commands directory
echo "Setting up custom commands..."
sudo mkdir -p /usr/local/bin

# Create all the custom commands with browser detection
sudo tee /usr/local/bin/edit-env << 'EOF'
#!/bin/bash
sudo nano /home/posuser/pos-system/.env
EOF

sudo tee /usr/local/bin/setup-tailnet << 'EOF'
#!/bin/bash
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh
echo "Run 'sudo tailscale up' to authenticate"
EOF

sudo tee /usr/local/bin/generate-key << 'EOF'
#!/bin/bash
cd /home/posuser/pos-system
echo "Generating new encryption key..."
NEW_KEY=$(node -e "const CryptoJS = require('crypto-js'); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());" 2>/dev/null || echo "fallback_key_$(date +%s)")
echo "New encryption key: $NEW_KEY"
echo "To use this key, run: edit-env"
echo "Then update ENCRYPTION_KEY=$NEW_KEY"
EOF

sudo tee /usr/local/bin/check-env << 'EOF'
#!/bin/bash
echo "Current .env configuration:"
cat /home/posuser/pos-system/.env
EOF

sudo tee /usr/local/bin/pdf-storage << 'EOF'
#!/bin/bash
echo "PDF storage directory contents:"
ls -la /home/posuser/pos-system/public/.data/
echo ""
echo "Storage usage:"
du -sh /home/posuser/pos-system/public/.data/
EOF

sudo tee /usr/local/bin/pos-logs << 'EOF'
#!/bin/bash
echo "POS System logs (press Ctrl+C to exit):"
journalctl -u pos-system -f
EOF

sudo tee /usr/local/bin/restart-pos << 'EOF'
#!/bin/bash
echo "Restarting POS system and kiosk..."
sudo systemctl restart pos-system pos-kiosk
echo "POS system restarted"
EOF

# Create admin-mode command with browser detection
sudo tee /usr/local/bin/admin-mode << 'EOF'
#!/bin/bash
# Toggle between POS kiosk and admin mode (XFCE focal version)
PID=$(pgrep -f "kiosk.*localhost:3000")
if [ ! -z "$PID" ]; then
    echo "Switching to admin mode..."
    kill $PID
    # Start XFCE terminal in fullscreen
    DISPLAY=:0 xfce4-terminal --fullscreen &
else
    echo "Starting POS kiosk mode..."
    /usr/local/bin/start-pos-kiosk &
fi
EOF

# Create start-pos-kiosk command with intelligent browser detection
sudo tee /usr/local/bin/start-pos-kiosk << 'EOF'
#!/bin/bash
# Wait for POS server to be ready
echo "Waiting for POS server to start..."
for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null; then
        break
    fi
    sleep 2
done

# Wait for X server to be ready
while ! xset q >/dev/null 2>&1; do
    sleep 1
done

# Set display to primary display
export DISPLAY=:0

# Hide cursor
unclutter -idle 1 -display :0 &

# Disable XFCE screensaver/power management
xset -display :0 s off
xset -display :0 -dpms
xset -display :0 s noblank

# Determine which browser to use (priority order)
BROWSER_CMD=""
BROWSER_ARGS=""

if command -v chromium-browser >/dev/null 2>&1; then
    BROWSER_CMD="chromium-browser"
    BROWSER_ARGS="--kiosk --no-first-run --disable-restore-session-state --disable-infobars --disable-translate --disable-dev-shm-usage --no-sandbox --disk-cache-dir=/tmp --start-maximized --window-position=0,0 --user-data-dir=/tmp/chromium-kiosk"
elif command -v chromium >/dev/null 2>&1; then
    BROWSER_CMD="chromium"
    BROWSER_ARGS="--kiosk --no-first-run --disable-restore-session-state --disable-infobars --disable-translate --disable-dev-shm-usage --no-sandbox --disk-cache-dir=/tmp --start-maximized --window-position=0,0 --user-data-dir=/tmp/chromium-kiosk"
elif command -v firefox >/dev/null 2>&1; then
    BROWSER_CMD="firefox"
    BROWSER_ARGS="--kiosk --private-window"
else
    echo "Error: No suitable browser found"
    exit 1
fi

# Start browser in kiosk mode
echo "Starting POS kiosk with $BROWSER_CMD..."
DISPLAY=:0 $BROWSER_CMD $BROWSER_ARGS http://localhost:3000 &
EOF

# Make commands executable
sudo chmod +x /usr/local/bin/*

# Create systemd services
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

sudo tee /etc/systemd/system/pos-kiosk.service << 'EOF'
[Unit]
Description=POS Kiosk Display
After=pos-system.service lightdm.service
Wants=pos-system.service
Requires=graphical.target

[Service]
Type=forking
User=posuser
Group=posuser
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/1001
WorkingDirectory=/home/posuser
ExecStartPre=/bin/sleep 20
ExecStart=/usr/local/bin/start-pos-kiosk
Restart=always
RestartSec=10
RestartPreventExitStatus=0

[Install]
WantedBy=graphical.target
EOF

# Create XFCE autostart and configuration
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

# XFCE keyboard shortcut setup
sudo tee /home/posuser/setup-hotkeys.sh << 'EOF'
#!/bin/bash
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml
cat > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml << 'XFCE_KEYS'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-keyboard-shortcuts" version="1.0">
  <property name="commands" type="empty">
    <property name="custom" type="empty">
      <property name="&lt;Primary&gt;&lt;Alt&gt;t" type="string" value="/usr/local/bin/admin-mode"/>
      <property name="override" type="bool" value="true"/>
    </property>
  </property>
</channel>
XFCE_KEYS
EOF

sudo chmod +x /home/posuser/setup-hotkeys.sh

# Create bashrc
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
PS1='\[\033[01;32m\]POS-FOCAL\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

echo "=== POS Admin Terminal (Ubuntu Focal - No Snap) ==="
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
echo "Ubuntu Focal (20.04) - Browser: $(command -v chromium-browser || command -v chromium || command -v firefox || echo 'Unknown')"
echo "=========================="
EOF

sudo tee /home/posuser/.profile << 'EOF'
export PATH="/usr/local/bin:$PATH"
if [ ! -f ~/.hotkeys-setup ]; then
    /home/posuser/setup-hotkeys.sh
    touch ~/.hotkeys-setup
fi
EOF

# Set proper permissions
sudo chown -R posuser:posuser /home/posuser
sudo chmod +x /home/posuser/.profile

# Configure LightDM for focal
if [ -f /etc/lightdm/lightdm.conf ]; then
    sudo cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup
fi

sudo tee /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
autologin-user=posuser
autologin-user-timeout=0
user-session=xfce
EOF

# XFCE power management
sudo mkdir -p /home/posuser/.config/xfce4/xfconf/xfce-perchannel-xml
sudo tee /home/posuser/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="blank-on-battery" type="int" value="0"/>
    <property name="dpms-enabled" type="bool" value="false"/>
  </property>
</channel>
EOF

sudo chown -R posuser:posuser /home/posuser/.config

# Enable services
sudo systemctl daemon-reload
sudo systemctl enable pos-system
sudo systemctl enable lightdm

# Configure firewall
sudo ufw allow 3000/tcp
sudo ufw allow ssh
echo "y" | sudo ufw enable

echo ""
echo "=== FOCAL POS SETUP COMPLETE (No Snap Issues) ==="
echo ""
echo "IMPORTANT: Reboot the system to start POS kiosk mode"
echo "sudo reboot"
echo ""
echo "=== SYSTEM INFORMATION ==="
echo "• Ubuntu Focal (20.04) - No snap packages used"
echo "• Browser: $(command -v chromium-browser || command -v chromium || command -v firefox || echo 'Fallback browser installed')"
echo "• Desktop Environment: XFCE"
echo "• Access URL: http://localhost:3000"
echo "• POS User: posuser / posuser123"
echo ""
echo "=== ADMIN ACCESS ==="
echo "• Hotkey: Ctrl+Alt+T (toggle admin/kiosk mode)"
echo "• SSH: ssh posuser@[ip-address]"
echo ""
echo "System ready for reboot!"
