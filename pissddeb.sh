#!/bin/bash
# Debian Bullseye 6.6 POS System Setup Script
# Run with: curl -sSL [YOUR_URL] | bash

set -e

echo "Debian Bullseye 6.6 MSN open-POS System Setup"

# Update system
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# Install essential packages (Debian Bullseye compatible)
echo "Installing essential packages..."
sudo apt install -y curl git nodejs npm xinit xserver-xorg-video-fbdev \
    xserver-xorg-input-evdev chromium unclutter sed nano \
    xserver-xorg-core xserver-xorg build-essential

# Check if we need to install Node.js from NodeSource (Bullseye has older Node)
NODE_VERSION=$(node --version 2>/dev/null | cut -c2- || echo "0.0.0")
REQUIRED_VERSION="14.0.0"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$NODE_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
    echo "Node.js version is sufficient: $NODE_VERSION"
else
    echo "Installing newer Node.js from NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Install PM2 globally
echo "Installing PM2..."
sudo npm install -g pm2

# Create POS user
echo "Creating POS user..."
sudo useradd -m -s /bin/bash posuser
echo "posuser:posuser123" | sudo chpasswd

# Clone your POS repository
echo "Cloning POS application..."
cd /home/posuser
sudo -u posuser git clone https://github.com/Molesafenetwork/msnpos2.git pos-system
cd pos-system

# Install Node.js dependencies and setup crypto key
echo "Installing Node.js dependencies and generating crypto key..."
sudo -u posuser npm install
sudo -u posuser npm install crypto-js

ENV_PATH=".env"
cd /home/posuser/pos-system

# Generate crypto key
CRYPTO_KEY=$(sudo -u posuser node -e "const CryptoJS = require('crypto-js'); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());")

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
echo "node -e \"const CryptoJS = require('crypto-js'); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());\"" >> /home/posuser/.bash_history

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
nano /home/posuser/pos-system/.env
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
echo "Restarting POS system and display..."
sudo systemctl restart pos-system pos-kiosk
echo "POS system restarted"
EOF

# Make commands executable
sudo chmod +x /usr/local/bin/edit-env
sudo chmod +x /usr/local/bin/setup-tailnet
sudo chmod +x /usr/local/bin/generate-key
sudo chmod +x /usr/local/bin/check-env
sudo chmod +x /usr/local/bin/pdf-storage
sudo chmod +x /usr/local/bin/pos-logs
sudo chmod +x /usr/local/bin/restart-pos

# Create X11 startup script with display optimization (Debian compatible)
sudo tee /home/posuser/.xinitrc << 'EOF'
#!/bin/bash
# Disable screen blanking and power management
xset s off
xset s noblank
xset -dpms

# Hide cursor after 1 second of inactivity
unclutter -idle 1 &

# Wait for POS server to be ready
while ! curl -s http://localhost:3000 > /dev/null; do
  sleep 1
done

# Start Chromium in kiosk mode pointing to your POS
# Note: Debian Bullseye uses 'chromium' instead of 'chromium-browser'
chromium \
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
  --disable-gpu \
  --disable-software-rasterizer \
  http://localhost:3000
EOF

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

# Create X11 kiosk service
sudo tee /etc/systemd/system/pos-kiosk.service << 'EOF'
[Unit]
Description=POS Kiosk Display
After=pos-system.service
Wants=pos-system.service

[Service]
Type=simple
User=posuser
Environment=DISPLAY=:0
WorkingDirectory=/home/posuser
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/xinit /home/posuser/.xinitrc
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Create custom bashrc with hotkeys
sudo tee /home/posuser/.bashrc << 'EOF'
# Custom POS Terminal Commands
alias edit-env='nano /home/posuser/pos-system/.env && sudo systemctl restart pos-system'
alias setup-tailnet='curl -fsSL https://tailscale.com/install.sh | sh && echo "Run: sudo tailscale up"'
alias restart-pos='sudo systemctl restart pos-system pos-kiosk'
alias pos-logs='journalctl -u pos-system -f'
alias generate-key='cd /home/posuser/pos-system && node -e "const CryptoJS = require(\"crypto-js\"); const key = CryptoJS.lib.WordArray.random(32); console.log(\"New key:\", key.toString());"'
alias check-env='cat /home/posuser/pos-system/.env'
alias pdf-storage='ls -la /home/posuser/pos-system/public/.data/'

# Terminal customization
PS1='\[\033[01;32m\]POS-ADMIN\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

echo "POS Admin Terminal - Debian Bullseye"
echo "Commands available:"
echo "  edit-env      - Edit environment variables"
echo "  setup-tailnet - Install and setup Tailscale" 
echo "  restart-pos   - Restart POS services"
echo "  pos-logs      - View POS application logs"
echo "  generate-key  - Generate new encryption key"
echo "  check-env     - View current .env settings"
echo "  pdf-storage   - Check PDF storage directory"
EOF

# Set permissions
sudo chown -R posuser:posuser /home/posuser
sudo chmod +x /home/posuser/.xinitrc

# Enable services
sudo systemctl daemon-reload
sudo systemctl enable pos-system pos-kiosk

# Configure auto-login for posuser (kiosk mode)
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin posuser %I $TERM
Type=idle
EOF

# Create admin access script
sudo tee /usr/local/bin/admin-terminal << 'EOF'
#!/bin/bash
# Kill kiosk and start admin terminal
sudo pkill -f chromium
sudo pkill -f xinit
sudo -u posuser bash
# Restart kiosk after admin exits
sudo systemctl start pos-kiosk
EOF

sudo chmod +x /usr/local/bin/admin-terminal

# Debian-specific: Ensure display manager doesn't interfere
echo "Configuring display manager..."
if systemctl is-enabled gdm3 >/dev/null 2>&1; then
    sudo systemctl disable gdm3
    echo "Disabled GDM3 to prevent conflicts with kiosk mode"
fi

if systemctl is-enabled lightdm >/dev/null 2>&1; then
    sudo systemctl disable lightdm
    echo "Disabled LightDM to prevent conflicts with kiosk mode"
fi

echo "Setup complete!"
echo ""
echo "=== IMPORTANT SETUP INFORMATION ==="
echo "1. Reboot the system: sudo reboot"
echo "2. The POS will auto-start on boot"
echo "3. Admin access:"
echo "   - Press Ctrl+Alt+F1 to switch to TTY"
echo "   - Login as: posuser / posuser123"
echo "   - Or run: admin-terminal"
echo "4. Available admin commands:"
echo "   - edit-env: Edit .env file"
echo "   - setup-tailnet: Install Tailscale"
echo "   - restart-pos: Restart POS system"
echo "   - generate-key: Generate new encryption key"
echo "   - check-env: View current .env settings"
echo "   - pdf-storage: Check PDF storage directory"
echo ""
echo "=== DEBIAN BULLSEYE SPECIFIC NOTES ==="
echo "- Using 'chromium' instead of 'chromium-browser'"
echo "- Node.js updated to v18 for compatibility"
echo "- Display managers (GDM3/LightDM) disabled for kiosk mode"
echo "- Added GPU acceleration flags for better performance"
echo ""
