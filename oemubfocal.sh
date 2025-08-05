#!/bin/bash
# Orange Pi 3B v2 POS System Setup Script
# Compatible with Ubuntu Focal and RK3566 chipset
# Run with: curl -sSL https://raw.githubusercontent.com/Molesafenetwork/msnpos2/refs/heads/main/oemubfocal.sh | bash

set -e

echo "Orange Pi 3B v2 MSN open-POS System Setup (Ubuntu Focal)"

# Update system
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# Install essential packages (Ubuntu Focal optimized)
echo "Installing essential packages..."
sudo apt install -y curl git nodejs npm xinit xserver-xorg \
    xserver-xorg-video-fbdev xserver-xorg-input-evdev \
    chromium-browser unclutter sed nano x11-xserver-utils \
    xserver-xorg-legacy mesa-utils

# Check if we need to install Node.js from NodeSource (Ubuntu Focal has older Node.js)
NODE_VERSION=$(node --version 2>/dev/null | cut -d'v' -f2 | cut -d'.' -f1 || echo "0")
if [ "$NODE_VERSION" -lt "14" ]; then
    echo "Installing newer Node.js from NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Install PM2 globally
echo "Installing PM2..."
sudo npm install -g pm2

# Create POS user
echo "Creating POS user..."
sudo useradd -m -s /bin/bash posuser || true
echo "posuser:posuser123" | sudo chpasswd

# Clone your POS repository
echo "Cloning POS application..."
cd /home/posuser
sudo -u posuser git clone https://github.com/Molesafenetwork/msnpos2.git pos-system || \
    (cd pos-system && sudo -u posuser git pull)
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

# Configure X11 for Orange Pi (Ubuntu Focal specific)
echo "Configuring X11 for Orange Pi 3B v2..."
sudo tee /etc/X11/xorg.conf << 'EOF'
Section "Device"
    Identifier "Orange Pi GPU"
    Driver "fbdev"
    Option "fbdev" "/dev/fb0"
    Option "SWcursor" "true"
EndSection

Section "Screen"
    Identifier "Default Screen"
    Device "Orange Pi GPU"
    DefaultDepth 24
EndSection

Section "ServerLayout"
    Identifier "Default Layout"
    Screen "Default Screen"
EndSection
EOF

# Create X11 startup script with display optimization for Orange Pi
sudo tee /home/posuser/.xinitrc << 'EOF'
#!/bin/bash
# Configure display for Orange Pi
export DISPLAY=:0

# Disable screen blanking and power management
xset s off
xset s noblank
xset -dpms

# Hide cursor after 1 second of inactivity
unclutter -idle 1 &

# Wait for POS server to be ready
echo "Waiting for POS server to start..."
while ! curl -s http://localhost:3000 > /dev/null; do
  sleep 2
done

# Start Chromium in kiosk mode pointing to your POS
chromium-browser \
  --kiosk \
  --no-first-run \
  --disable-restore-session-state \
  --disable-infobars \
  --disable-translate \
  --disable-features=TranslateUI \
  --disable-dev-shm-usage \
  --no-sandbox \
  --disable-gpu \
  --disable-software-rasterizer \
  --disable-background-timer-throttling \
  --disable-backgrounding-occluded-windows \
  --disable-renderer-backgrounding \
  --disk-cache-dir=/tmp \
  --aggressive-cache-discard \
  --memory-pressure-off \
  --start-maximized \
  --window-position=0,0 \
  --ignore-gpu-blacklist \
  --enable-features=VizDisplayCompositor \
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
Environment=NODE_OPTIONS=--max-old-space-size=512
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create X11 kiosk service (Ubuntu Focal specific)
sudo tee /etc/systemd/system/pos-kiosk.service << 'EOF'
[Unit]
Description=POS Kiosk Display
After=pos-system.service graphical-session.target
Wants=pos-system.service

[Service]
Type=simple
User=posuser
Group=posuser
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/posuser/.Xauthority
WorkingDirectory=/home/posuser
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/xinit /home/posuser/.xinitrc -- :0 vt7
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
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

echo "POS Admin Terminal (Ubuntu Focal)"
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

# Add posuser to necessary groups for Ubuntu
sudo usermod -a -G video,audio,dialout,plugdev posuser

# Configure auto-login for posuser (Ubuntu Focal way)
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin posuser %I $TERM
Type=idle
EOF

# Enable automatic graphical login (Ubuntu specific)
sudo systemctl set-default graphical.target

# Create admin access script
sudo tee /usr/local/bin/admin-terminal << 'EOF'
#!/bin/bash
# Kill kiosk and start admin terminal
sudo pkill -f chromium-browser
sudo pkill -f xinit
sudo -u posuser bash
# Restart kiosk after admin exits
sudo systemctl start pos-kiosk
EOF

sudo chmod +x /usr/local/bin/admin-terminal

# Enable services
sudo systemctl daemon-reload
sudo systemctl enable pos-system pos-kiosk

# Ubuntu Focal specific: Ensure X11 can run without root
echo "Configuring X11 permissions for Ubuntu Focal..."
sudo dpkg-reconfigure xserver-xorg-legacy || true

# Create a simple display manager override if needed
if [ ! -f /etc/X11/Xwrapper.config ]; then
    sudo tee /etc/X11/Xwrapper.config << 'EOF'
allowed_users=anybody
needs_root_rights=yes
EOF
fi

# Final system optimizations for Orange Pi 3B v2
echo "Applying Orange Pi 3B v2 optimizations..."

# GPU memory split (if applicable)
if [ -f /boot/config.txt ]; then
    echo "gpu_mem=128" | sudo tee -a /boot/config.txt
fi

# Disable unnecessary services to free up memory
sudo systemctl disable bluetooth.service || true
sudo systemctl disable cups.service || true
sudo systemctl disable avahi-daemon.service || true

echo "Setup complete!"
echo ""
echo "=== Orange Pi 3B v2 Ubuntu Focal Setup Information ==="
echo "1. Reboot the system: sudo reboot"
echo "2. The POS will auto-start on boot"
echo "3. Admin access:"
echo "   - Press Ctrl+Alt+F2 to switch to TTY2"
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
echo "5. Troubleshooting:"
echo "   - Check logs: journalctl -u pos-system"
echo "   - Check kiosk: journalctl -u pos-kiosk"
echo "   - Manual start: sudo systemctl start pos-kiosk"
echo ""
