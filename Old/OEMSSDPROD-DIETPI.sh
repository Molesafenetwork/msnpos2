#!/bin/bash
# Orange Pi 3B POS System Setup Script - DietPi Optimized
# Compatible with RK3566 chipset and DietPi OS
# Run with: curl -sSL https://raw.githubusercontent.com/Molesafenetwork/msnpos2/refs/heads/main/OEMSSDPROD-DIETPI.sh | bash

set -e

echo "Orange Pi 3B MSN open-POS System Setup - DietPi Optimized"

# Check if running on DietPi
if [ ! -f /boot/dietpi/.version ]; then
    echo "Warning: This script is optimized for DietPi OS"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# DietPi-specific: Update using DietPi tools first
echo "Updating DietPi system..."
if command -v dietpi-update &> /dev/null; then
    sudo dietpi-update
else
    sudo apt update && sudo apt upgrade -y
fi

# Check and configure desktop environment
echo "Configuring desktop environment for kiosk mode..."
if ! systemctl is-enabled lightdm &> /dev/null && ! systemctl is-enabled gdm3 &> /dev/null; then
    echo "Installing minimal desktop environment via DietPi..."
    # Install desktop via dietpi-software (LXDE is lightweight)
    sudo dietpi-software install 23  # LXDE desktop
fi

# DietPi-specific: Install packages using dietpi-software where possible
echo "Installing software via DietPi package manager..."

# Install Node.js via DietPi
sudo dietpi-software install 9  # Node.js

# Install Chromium via DietPi (more optimized)
sudo dietpi-software install 113  # Chromium

# Install additional packages via apt (those not available in dietpi-software)
echo "Installing additional packages..."
sudo apt install -y curl git xinit xserver-xorg-video-fbdev \
    xserver-xorg-input-evdev unclutter sed nano \
    xserver-xorg-video-rockchip x11-xserver-utils

# DietPi optimization: Configure GPU memory split for better graphics performance
echo "Optimizing GPU memory allocation..."
if [ -f /boot/config.txt ]; then
    if ! grep -q "gpu_mem=" /boot/config.txt; then
        echo "gpu_mem=128" | sudo tee -a /boot/config.txt
    fi
fi

# Install PM2 globally
echo "Installing PM2..."
sudo npm install -g pm2

# Create POS user (check if already exists)
echo "Creating POS user..."
if ! id "posuser" &>/dev/null; then
    sudo useradd -m -s /bin/bash posuser
    echo "posuser:posuser123" | sudo chpasswd
    # Add posuser to necessary groups for hardware access
    sudo usermod -a -G video,audio,input,dialout posuser
fi

# Clone POS repository
echo "Cloning POS application..."
cd /home/posuser
if [ -d "pos-system" ]; then
    echo "POS system directory exists, updating..."
    sudo -u posuser git -C pos-system pull
else
    sudo -u posuser git clone https://github.com/Molesafenetwork/msnpos2.git pos-system
fi
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

# Create DietPi-specific commands
sudo tee /usr/local/bin/dietpi-pos-config << 'EOF'
#!/bin/bash
echo "DietPi POS Configuration Menu"
echo "1. Edit environment variables"
echo "2. Configure network (DietPi-Config)"
echo "3. Software management (DietPi-Software)"
echo "4. System optimization (DietPi-Optimize)"
echo "5. Backup configuration (DietPi-Backup)"
read -p "Select option (1-5): " choice
case $choice in
    1) nano /home/posuser/pos-system/.env && sudo systemctl restart pos-system ;;
    2) sudo dietpi-config ;;
    3) sudo dietpi-software ;;
    4) sudo dietpi-optimize ;;
    5) sudo dietpi-backup ;;
    *) echo "Invalid option" ;;
esac
EOF

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

# DietPi system monitoring command
sudo tee /usr/local/bin/pos-monitor << 'EOF'
#!/bin/bash
echo "=== DietPi POS System Monitor ==="
echo "System Load:"
uptime
echo ""
echo "Memory Usage:"
free -h
echo ""
echo "Disk Usage:"
df -h /
echo ""
echo "POS Service Status:"
systemctl status pos-system --no-pager -l
echo ""
echo "Temperature:"
if command -v vcgencmd &> /dev/null; then
    vcgencmd measure_temp
fi
EOF

# Make commands executable
sudo chmod +x /usr/local/bin/dietpi-pos-config
sudo chmod +x /usr/local/bin/edit-env
sudo chmod +x /usr/local/bin/setup-tailnet
sudo chmod +x /usr/local/bin/generate-key
sudo chmod +x /usr/local/bin/check-env
sudo chmod +x /usr/local/bin/pdf-storage
sudo chmod +x /usr/local/bin/pos-logs
sudo chmod +x /usr/local/bin/restart-pos
sudo chmod +x /usr/local/bin/pos-monitor

# Create X11 startup script optimized for DietPi/RK3566
sudo tee /home/posuser/.xinitrc << 'EOF'
#!/bin/bash
# DietPi optimized X11 startup

# Disable screen blanking and power management
xset s off
xset s noblank
xset -dpms

# Hide cursor after 1 second of inactivity
unclutter -idle 1 &

# Set display resolution (adjust as needed for your display)
xrandr --output HDMI-1 --mode 1920x1080 2>/dev/null || true

# Wait for POS server to be ready
echo "Waiting for POS server to start..."
while ! curl -s http://localhost:3000 > /dev/null; do
  sleep 2
done

# DietPi-optimized Chromium flags for ARM/RK3566
chromium-browser \
  --kiosk \
  --no-first-run \
  --disable-restore-session-state \
  --disable-infobars \
  --disable-translate \
  --disable-features=TranslateUI \
  --disable-dev-shm-usage \
  --no-sandbox \
  --disable-gpu-sandbox \
  --disk-cache-dir=/tmp \
  --aggressive-cache-discard \
  --start-maximized \
  --window-position=0,0 \
  --disable-background-timer-throttling \
  --disable-renderer-backgrounding \
  --disable-backgrounding-occluded-windows \
  --disable-features=VizDisplayCompositor \
  --enable-features=OverlayScrollbar \
  --force-device-scale-factor=1 \
  http://localhost:3000
EOF

# Create optimized POS startup service
sudo tee /etc/systemd/system/pos-system.service << 'EOF'
[Unit]
Description=POS System Node.js Application
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=posuser
WorkingDirectory=/home/posuser/pos-system
Environment=NODE_ENV=production
Environment=NODE_OPTIONS="--max-old-space-size=512"
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

# DietPi optimization: Resource limits
MemoryMax=256M
CPUQuota=80%

[Install]
WantedBy=multi-user.target
EOF

# Create X11 kiosk service optimized for DietPi
sudo tee /etc/systemd/system/pos-kiosk.service << 'EOF'
[Unit]
Description=POS Kiosk Display
After=pos-system.service graphical.target
Wants=pos-system.service
StartLimitIntervalSec=0

[Service]
Type=simple
User=posuser
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/1001
WorkingDirectory=/home/posuser
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/xinit /home/posuser/.xinitrc
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Ensure X11 directories exist
ExecStartPre=+/bin/mkdir -p /run/user/1001
ExecStartPre=+/bin/chown posuser:posuser /run/user/1001

[Install]
WantedBy=graphical.target
EOF

# Create DietPi-optimized bashrc
sudo tee /home/posuser/.bashrc << 'EOF'
# DietPi POS Terminal Commands
alias dietpi-pos='dietpi-pos-config'
alias edit-env='nano /home/posuser/pos-system/.env && sudo systemctl restart pos-system'
alias setup-tailnet='curl -fsSL https://tailscale.com/install.sh | sh && echo "Run: sudo tailscale up"'
alias restart-pos='sudo systemctl restart pos-system pos-kiosk'
alias pos-logs='journalctl -u pos-system -f'
alias pos-monitor='pos-monitor'
alias generate-key='cd /home/posuser/pos-system && node -e "const CryptoJS = require(\"crypto-js\"); const key = CryptoJS.lib.WordArray.random(32); console.log(\"New key:\", key.toString());"'
alias check-env='cat /home/posuser/pos-system/.env'
alias pdf-storage='ls -la /home/posuser/pos-system/public/.data/'

# DietPi shortcuts
alias dietpi-config='sudo dietpi-config'
alias dietpi-software='sudo dietpi-software'
alias dietpi-backup='sudo dietpi-backup'

# Terminal customization
PS1='\[\033[01;32m\]DietPi-POS\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

echo "DietPi POS Admin Terminal"
echo "Commands available:"
echo "  dietpi-pos    - DietPi POS configuration menu"
echo "  edit-env      - Edit environment variables"
echo "  setup-tailnet - Install and setup Tailscale"
echo "  restart-pos   - Restart POS services"
echo "  pos-logs      - View POS application logs"
echo "  pos-monitor   - System monitoring"
echo "  generate-key  - Generate new encryption key"
echo "  check-env     - View current .env settings"
echo "  pdf-storage   - Check PDF storage directory"
echo ""
echo "DietPi Tools:"
echo "  dietpi-config   - System configuration"
echo "  dietpi-software - Software installation"
echo "  dietpi-backup   - Backup management"
EOF

# Set permissions
sudo chown -R posuser:posuser /home/posuser
sudo chmod +x /home/posuser/.xinitrc

# Enable services
sudo systemctl daemon-reload
sudo systemctl enable pos-system pos-kiosk

# DietPi-specific: Configure auto-login via DietPi method
echo "Configuring auto-login for kiosk mode..."
if [ -f /boot/dietpi.txt ]; then
    # Use DietPi's auto-login configuration
    sudo sed -i 's/^AUTO_SETUP_AUTOMATED=.*/AUTO_SETUP_AUTOMATED=1/' /boot/dietpi.txt
    sudo sed -i 's/^AUTO_SETUP_GLOBAL_PASSWORD=.*/AUTO_SETUP_GLOBAL_PASSWORD=posuser123/' /boot/dietpi.txt
else
    # Fallback to systemd method
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
    sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin posuser %I $TERM
Type=idle
EOF
fi

# Create admin access script
sudo tee /usr/local/bin/admin-terminal << 'EOF'
#!/bin/bash
# Kill kiosk and start admin terminal
sudo systemctl stop pos-kiosk
sudo -u posuser bash
# Restart kiosk after admin exits
sudo systemctl start pos-kiosk
EOF

sudo chmod +x /usr/local/bin/admin-terminal

# DietPi optimization: Create swap file if not exists and system has low RAM
TOTAL_RAM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
if [ "$TOTAL_RAM" -lt 2048 ] && [ ! -f /swapfile ]; then
    echo "Creating swap file for low RAM system..."
    sudo fallocate -l 1G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab
fi

# Configure DietPi to start in desktop mode
if [ -f /boot/dietpi.txt ]; then
    sudo sed -i 's/^AUTO_SETUP_DESKTOP=.*/AUTO_SETUP_DESKTOP=1/' /boot/dietpi.txt
fi

echo "Setup complete!"
echo ""
echo "=== DIETPI POS SETUP INFORMATION ==="
echo "1. Reboot the system: sudo reboot"
echo "2. The POS will auto-start on boot in kiosk mode"
echo "3. Admin access methods:"
echo "   - SSH in and run: admin-terminal"
echo "   - Press Ctrl+Alt+F2 for console access"
echo "   - Login as: posuser / posuser123"
echo ""
echo "4. Available admin commands:"
echo "   - dietpi-pos: Main configuration menu"
echo "   - edit-env: Edit .env file"
echo "   - setup-tailnet: Install Tailscale"
echo "   - restart-pos: Restart POS system"
echo "   - pos-monitor: System monitoring"
echo "   - generate-key: Generate new encryption key"
echo "   - check-env: View current .env settings"
echo "   - pdf-storage: Check PDF storage directory"
echo ""
echo "5. DietPi specific features:"
echo "   - GPU memory optimized for RK3566"
echo "   - Resource limits configured"
echo "   - Swap file created if needed"
echo "   - Integration with DietPi tools"
echo ""
echo "🍓 Optimized for DietPi OS!"
