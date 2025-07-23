#!/bin/bash
# Orange Pi Zero 3 Optimized POS System Setup Script
# Lightweight version for 1GB RAM constraint

set -e

echo "=== Orange Pi Zero 3 POS System Setup (Optimized) ==="

# Update system
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# Install minimal packages for Zero 3
echo "Installing essential packages (minimal set)..."
sudo apt install -y curl git nodejs npm xinit xserver-xorg-core \
    matchbox-window-manager chromium-browser unclutter nano \
    --no-install-recommends

# Configure memory optimization
echo "Configuring memory optimization..."
# Reduce GPU memory split
echo "gpu_mem=16" | sudo tee -a /boot/config.txt
# Add swap file for PDF generation
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

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

# Install Node.js dependencies with memory optimization
echo "Installing Node.js dependencies..."
sudo -u posuser npm install --production --no-optional

# Create lightweight window manager config
sudo mkdir -p /home/posuser/.matchbox
sudo tee /home/posuser/.matchbox/session << 'EOF'
matchbox-panel &
chromium-browser --kiosk --no-sandbox --disable-dev-shm-usage http://localhost:3000
EOF

# Create optimized X11 startup script for Zero 3
sudo tee /home/posuser/.xinitrc << 'EOF'
#!/bin/bash
# Memory-optimized X session
export DISPLAY=:0

# Disable screen blanking
xset s off
xset s noblank
xset -dpms

# Hide cursor
unclutter -idle 1 &

# Wait for POS server
while ! curl -s http://localhost:3000 > /dev/null 2>&1; do
  sleep 2
done

# Start lightweight browser (optimized for 1GB RAM)
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
  --max_old_space_size=256 \
  --disable-background-timer-throttling \
  --disable-renderer-backgrounding \
  --disk-cache-dir=/tmp \
  --disk-cache-size=50000000 \
  http://localhost:3000
EOF

# Create memory-optimized Node.js service
sudo tee /etc/systemd/system/pos-system.service << 'EOF'
[Unit]
Description=POS System Node.js Application
After=network.target

[Service]
Type=simple
User=posuser
WorkingDirectory=/home/posuser/pos-system
Environment=NODE_ENV=production
Environment=NODE_OPTIONS="--max_old_space_size=512"
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
MemoryMax=600M

[Install]
WantedBy=multi-user.target
EOF

# Create X11 display service (lightweight)
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

# Create admin commands (same as before but optimized)
sudo mkdir -p /usr/local/bin

sudo tee /usr/local/bin/edit-env << 'EOF'
#!/bin/bash
nano /home/posuser/pos-system/.env
sudo systemctl restart pos-system
EOF

sudo tee /usr/local/bin/setup-tailnet << 'EOF'
#!/bin/bash
echo "Installing Tailscale (lightweight)..."
curl -fsSL https://tailscale.com/install.sh | sh
echo "Run 'sudo tailscale up' to authenticate"
EOF

sudo tee /usr/local/bin/restart-pos << 'EOF'
#!/bin/bash
sudo systemctl restart pos-system pos-display
EOF

sudo tee /usr/local/bin/check-memory << 'EOF'
#!/bin/bash
echo "=== Memory Usage ==="
free -h
echo ""
echo "=== Top Processes ==="
ps aux --sort=-%mem | head -10
EOF

# Make commands executable
sudo chmod +x /usr/local/bin/edit-env
sudo chmod +x /usr/local/bin/setup-tailnet
sudo chmod +x /usr/local/bin/restart-pos
sudo chmod +x /usr/local/bin/check-memory

# Create optimized bashrc
sudo tee /home/posuser/.bashrc << 'EOF'
# Zero 3 Optimized POS Terminal Commands
alias edit-env='nano /home/posuser/pos-system/.env && sudo systemctl restart pos-system'
alias setup-tailnet='curl -fsSL https://tailscale.com/install.sh | sh && echo "Run: sudo tailscale up"'
alias restart-pos='sudo systemctl restart pos-system pos-display'
alias pos-logs='journalctl -u pos-system -f --lines=50'
alias check-mem='check-memory'
alias cleanup='sudo apt autoremove && sudo apt autoclean && sudo journalctl --vacuum-time=7d'

PS1='\[\033[01;32m\]POS-ZERO3\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

echo "Orange Pi Zero 3 POS Admin Terminal"
echo "Commands available:"
echo "  edit-env      - Edit environment variables"
echo "  setup-tailnet - Install Tailscale"
echo "  restart-pos   - Restart POS services"
echo "  pos-logs      - View POS logs"
echo "  check-mem     - Check memory usage"
echo "  cleanup       - Clean up system files"
EOF

# Set permissions
sudo chown -R posuser:posuser /home/posuser
sudo chmod +x /home/posuser/.xinitrc

# Enable services
sudo systemctl daemon-reload
sudo systemctl enable pos-system pos-display

# Configure auto-login
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --autologin posuser %I $TERM
Type=idle
EOF

echo "Setup complete!"
echo ""
echo "=== ORANGE PI ZERO 3 SETUP INFORMATION ==="
echo "Hardware Requirements:"
echo "- 1 USB-C hub with multiple ports (for display + peripherals)"
echo "- Large SD card (64GB+ recommended)"
echo "- USB display compatible with Linux"
echo ""
echo "Memory Optimizations Applied:"
echo "- 1GB swap file created"
echo "- GPU memory reduced to 16MB"
echo "- Node.js limited to 512MB"
echo "- Browser optimized for low memory"
echo ""
echo "1. Connect USB-C hub with your display and peripherals"
echo "2. Reboot the system: sudo reboot"
echo "3. POS will auto-start (may take 30-60 seconds)"
echo "4. Admin access: Ctrl+Alt+F1, login as posuser"
echo ""
echo "Additional commands:"
echo "- check-mem: Monitor memory usage"
echo "- cleanup: Free up disk space"
echo "  edit-env      - Edit environment variables"
echo "  setup-tailnet - Install Tailscale"
echo "  restart-pos   - Restart POS services"
echo "  pos-logs      - View POS logs"
echo " - enjoy your msn point of sales system. - "
