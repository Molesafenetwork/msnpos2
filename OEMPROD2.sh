#!/bin/bash
# Armbian Orange Pi POS System Setup Script
# Compatible with both Zero 3 and 4 LTS
# Use with Armbian Minimal (Jammy or Bookworm)

set -e

echo "=== Armbian Orange Pi POS System Setup ==="

# Detect board type
BOARD=$(cat /proc/device-tree/model 2>/dev/null || echo "Unknown")
echo "Detected board: $BOARD"

# Update Armbian system
echo "Updating Armbian system..."
sudo apt update && sudo apt upgrade -y

# Install Armbian config tool if not present
if ! command -v armbian-config &> /dev/null; then
    sudo apt install -y armbian-config
fi

# Detect if this is Zero 3 (1GB RAM) or 4 LTS (4GB RAM)
MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEMORY_GB=$((MEMORY_KB / 1024 / 1024))

if [ $MEMORY_GB -le 1 ]; then
    echo "Detected low memory system (${MEMORY_GB}GB) - applying optimizations..."
    LOW_MEMORY=true
else
    echo "Detected higher memory system (${MEMORY_GB}GB) - standard configuration..."
    LOW_MEMORY=false
fi

# Install packages based on memory
if [ "$LOW_MEMORY" = true ]; then
    echo "Installing minimal packages for low memory system..."
    sudo apt install -y curl git nodejs npm xinit xserver-xorg-core \
        matchbox-window-manager chromium-browser unclutter nano \
        build-essential --no-install-recommends
    
    # Memory optimizations for Zero 3
    echo "Applying memory optimizations..."
    echo "gpu_mem=16" | sudo tee -a /boot/armbianEnv.txt
    
    # Create swap file
    sudo fallocate -l 1G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
else
    echo "Installing packages for standard memory system..."
    sudo apt install -y curl git nodejs npm xinit xserver-xorg \
        chromium-browser unclutter nano build-essential
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

# Install Node.js dependencies
echo "Installing Node.js dependencies..."
if [ "$LOW_MEMORY" = true ]; then
    sudo -u posuser npm install --production --no-optional
else
    sudo -u posuser npm install
fi

# Create X11 startup script optimized for Armbian
sudo tee /home/posuser/.xinitrc << 'EOF'
#!/bin/bash
export DISPLAY=:0

# Disable screen blanking and power management
xset s off
xset s noblank
xset -dpms

# Hide cursor after inactivity
unclutter -idle 1 &

# Wait for POS server to be ready
echo "Waiting for POS server to start..."
while ! curl -s http://localhost:3000 > /dev/null 2>&1; do
    sleep 2
    echo -n "."
done
echo " POS server ready!"

# Detect memory and adjust browser settings
MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEMORY_GB=$((MEMORY_KB / 1024 / 1024))

if [ $MEMORY_GB -le 1 ]; then
    # Low memory configuration
    exec chromium-browser \
      --kiosk \
      --no-first-run \
      --disable-restore-session-state \
      --disable-infobars \
      --disable-translate \
      --disable-features=TranslateUI \
      --disable-dev-shm-usage \
      --no-sandbox \
      --memory-pressure-off \
      --max_old_space_size=200 \
      --disable-background-timer-throttling \
      --disable-renderer-backgrounding \
      --disk-cache-dir=/tmp \
      --disk-cache-size=25000000 \
      --disable-extensions \
      --disable-plugins \
      http://localhost:3000
else
    # Standard memory configuration
    exec chromium-browser \
      --kiosk \
      --no-first-run \
      --disable-restore-session-state \
      --disable-infobars \
      --disable-translate \
      --disable-features=TranslateUI \
      --disable-dev-shm-usage \
      --no-sandbox \
      --disk-cache-dir=/tmp \
      --start-maximized \
      http://localhost:3000
fi
EOF

# Create Node.js service with memory detection
sudo tee /etc/systemd/system/pos-system.service << EOF
[Unit]
Description=POS System Node.js Application
After=network.target

[Service]
Type=simple
User=posuser
WorkingDirectory=/home/posuser/pos-system
Environment=NODE_ENV=production
$(if [ "$LOW_MEMORY" = true ]; then echo 'Environment=NODE_OPTIONS="--max_old_space_size=400"'; else echo 'Environment=NODE_OPTIONS="--max_old_space_size=1024"'; fi)
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
$(if [ "$LOW_MEMORY" = true ]; then echo 'MemoryMax=500M'; fi)

[Install]
WantedBy=multi-user.target
EOF

# Create display service
sudo tee /etc/systemd/system/pos-display.service << 'EOF'
[Unit]
Description=POS Display Service
After=pos-system.service
Wants=pos-system.service

[Service]
Type=simple
User=posuser
Environment=DISPLAY=:0
WorkingDirectory=/home/posuser
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/xinit /home/posuser/.xinitrc -- :0 vt7
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Create admin commands
sudo mkdir -p /usr/local/bin

sudo tee /usr/local/bin/edit-env << 'EOF'
#!/bin/bash
nano /home/posuser/pos-system/.env
sudo systemctl restart pos-system
echo "Environment updated and POS restarted"
EOF

sudo tee /usr/local/bin/generate-key << 'EOF'
#!/bin/bash
cd /home/posuser/pos-system

echo "=== POS Encryption Key Generator ==="

# Check if crypto-js is installed
if ! npm list crypto-js &>/dev/null; then
    echo "Installing crypto-js..."
    npm install crypto-js
fi

# Generate encryption key
echo "Generating new encryption key..."
ENCRYPTION_KEY=$(node -e "const CryptoJS = require('crypto-js'); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());")

echo "Generated key: $ENCRYPTION_KEY"

# Check if .env exists, create if not
if [ ! -f .env ]; then
    echo "Creating new .env file..."
    cat > .env << ENVEOF
# POS System Configuration
ENCRYPTION_KEY=$ENCRYPTION_KEY

# Store Configuration
STORE_NAME=Your Store Name
STORE_ADDRESS=123 Main St
STORE_PHONE=+1234567890
STORE_EMAIL=contact@yourstore.com

# Receipt Configuration
RECEIPT_FOOTER=Thank you for your business!

# Security Configuration
SESSION_SECRET=your_session_secret_here
JWT_SECRET=your_jwt_secret_here

# Printer Configuration (if applicable)
PRINTER_IP=192.168.1.100
PRINTER_PORT=9100

ENVEOF
    echo "✅ Created new .env file with generated encryption key"
else
    # Update existing .env file
    echo "Updating existing .env file..."
    if grep -q "ENCRYPTION_KEY=" .env; then
        sed -i "s/ENCRYPTION_KEY=.*/ENCRYPTION_KEY=$ENCRYPTION_KEY/" .env
        echo "✅ Updated ENCRYPTION_KEY in existing .env file"
    else
        echo "ENCRYPTION_KEY=$ENCRYPTION_KEY" | cat - .env > temp && mv temp .env
        echo "✅ Added ENCRYPTION_KEY to existing .env file"
    fi
fi

# Log the key generation (for history reference)
echo "# Generated encryption key on $(date)" >> ~/.bash_history
echo "node -e \"const CryptoJS = require('crypto-js'); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());\"" >> ~/.bash_history

echo ""
echo "=== Next Steps ==="
echo "1. Review and update other variables in .env:"
echo "   edit-env"
echo ""
echo "2. Restart POS system to apply changes:"
echo "   restart-pos"
echo ""
echo "3. Check .bash_history for crypto.js commands:"
echo "   tail ~/.bash_history"
echo ""
echo "🔒 Encryption key has been generated and stored securely!"

# Set proper permissions
chmod 600 .env
chown posuser:posuser .env
EOF

sudo tee /usr/local/bin/setup-pos << 'EOF'
#!/bin/bash
echo "=== Complete POS Setup Wizard ==="
cd /home/posuser/pos-system

# Step 1: Generate encryption key
echo "Step 1: Generating encryption key..."
generate-key

echo ""
echo "Step 2: Configure your store details..."
echo "Opening .env file for editing..."
echo "Please update the following variables:"
echo "- STORE_NAME, STORE_ADDRESS, STORE_PHONE, STORE_EMAIL"
echo ""
read -p "Press Enter to open .env editor..."
nano .env

echo ""
echo "Step 3: Installing any missing dependencies..."
npm install

echo ""
echo "Step 4: Testing POS system..."
echo "Starting POS system test..."
timeout 10s node server.js &
TEST_PID=$!
sleep 5

if curl -s http://localhost:3000 > /dev/null; then
    echo "✅ POS system test successful!"
    kill $TEST_PID 2>/dev/null || true
else
    echo "❌ POS system test failed - check logs"
    kill $TEST_PID 2>/dev/null || true
fi

echo ""
echo "Step 5: Setting up services..."
sudo systemctl daemon-reload
sudo systemctl enable pos-system pos-display
sudo systemctl start pos-system

echo ""
echo "=== Setup Complete! ==="
echo "Commands available:"
echo "  restart-pos    - Restart POS system"
echo "  pos-logs       - View logs"
echo "  edit-env       - Edit configuration"
echo "  generate-key   - Generate new encryption key"
echo ""
echo "Reboot system to start kiosk mode: sudo reboot"
EOF

sudo tee /usr/local/bin/setup-tailnet << 'EOF'
#!/bin/bash
echo "Installing Tailscale for Armbian..."
curl -fsSL https://tailscale.com/install.sh | sh
echo ""
echo "Run the following commands:"
echo "  sudo tailscale up"
echo "  sudo tailscale status"
EOF

sudo tee /usr/local/bin/armbian-pos-info << 'EOF'
#!/bin/bash
echo "=== Armbian POS System Information ==="
echo "Board: $(cat /proc/device-tree/model 2>/dev/null || echo 'Unknown')"
echo "Armbian: $(cat /etc/armbian-release | grep VERSION)"
echo "Kernel: $(uname -r)"
echo "Memory: $(free -h | grep Mem)"
echo "Storage: $(df -h / | tail -1)"
echo "Uptime: $(uptime)"
echo ""
echo "=== POS Service Status ==="
sudo systemctl status pos-system --no-pager -l
echo ""
sudo systemctl status pos-display --no-pager -l
EOF

# Make commands executable
sudo chmod +x /usr/local/bin/edit-env
sudo chmod +x /usr/local/bin/setup-tailnet
sudo chmod +x /usr/local/bin/armbian-pos-info
sudo chmod +x /usr/local/bin/generate-key
sudo chmod +x /usr/local/bin/setup-pos

# Create Armbian-optimized bashrc
sudo tee /home/posuser/.bashrc << 'EOF'
# Armbian POS Terminal Commands
alias edit-env='edit-env'
alias setup-tailnet='setup-tailnet'
alias restart-pos='sudo systemctl restart pos-system pos-display'
alias pos-logs='journalctl -u pos-system -f --lines=50'
alias pos-info='armbian-pos-info'
alias armbian-config='sudo armbian-config'
alias check-temp='sudo armbianmonitor -m'
alias generate-key='generate-key'
alias setup-pos='setup-pos'

PS1='\[\033[01;32m\]ARMBIAN-POS\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

echo "Armbian Orange Pi POS Admin Terminal"
echo "Quick Setup Commands:"
echo "  setup-pos      - Complete POS setup wizard"
echo "  generate-key   - Generate encryption key & setup .env"
echo ""
echo "Management Commands:"
echo "  edit-env       - Edit environment variables"
echo "  setup-tailnet  - Install Tailscale VPN"
echo "  restart-pos    - Restart POS services"
echo "  pos-logs       - View POS application logs"
echo "  pos-info       - Show system and service info"
echo "  armbian-config - Armbian configuration tool"
echo "  check-temp     - Monitor system temperature"
EOF

# Set permissions
sudo chown -R posuser:posuser /home/posuser
sudo chmod +x /home/posuser/.xinitrc

# Enable services
sudo systemctl daemon-reload
sudo systemctl enable pos-system pos-display

# Configure auto-login for kiosk mode
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin posuser %I $TERM
Type=idle
EOF

# Armbian-specific optimizations
echo "Applying Armbian optimizations..."

# Enable hardware optimization
sudo armbian-config --cmd AVA02 2>/dev/null || echo "Hardware optimization skipped"

# Set CPU governor for consistent performance
echo 'GOVERNOR=performance' | sudo tee -a /etc/default/armbian-zram-config

echo ""
echo "=== ARMBIAN POS SETUP COMPLETE ==="
echo "Board detected: $BOARD"
echo "Memory configuration: ${MEMORY_GB}GB"
echo "Optimizations applied: $(if [ "$LOW_MEMORY" = true ]; then echo "Low memory"; else echo "Standard"; fi)"
echo ""
echo "Next steps:"
echo "1. Reboot the system: sudo reboot"
echo "2. POS will auto-start in kiosk mode"
echo "3. Admin access: Ctrl+Alt+F1, login as posuser"
echo "4. Use 'armbian-config' for system configuration"
echo ""
echo "Armbian-specific features:"
echo "- Hardware optimization enabled"
echo "- Temperature monitoring available"
echo "- Kernel updates through Armbian repos"
echo "- Professional-grade stability"
