#!/bin/bash
# Orange Pi 3B POS System Setup Script
# Compatible with RK3566 chipset and Armbian
# Run with: curl -sSL https://your-repo.com/setup.sh | bash

set -e

echo "=== Orange Pi 3B POS System Setup ==="

# Update system
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# Install essential packages (optimized for RK3566)
echo "Installing essential packages..."
sudo apt install -y curl git nodejs npm xinit xserver-xorg-video-fbdev \
    xserver-xorg-input-evdev chromium-browser unclutter sed nano \
    xserver-xorg-video-rockchip

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
sudo -u posuser npm install

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

# Make commands executable
sudo chmod +x /usr/local/bin/edit-env
sudo chmod +x /usr/local/bin/setup-tailnet

# Create X11 startup script with display optimization
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

# Terminal customization
PS1='\[\033[01;32m\]POS-ADMIN\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

echo "POS Admin Terminal"
echo "Commands available:"
echo "  edit-env      - Edit environment variables"
echo "  setup-tailnet - Install and setup Tailscale"
echo "  restart-pos   - Restart POS services"
echo "  pos-logs      - View POS application logs"
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
sudo pkill -f chromium-browser
sudo pkill -f xinit
sudo -u posuser bash
# Restart kiosk after admin exits
sudo systemctl start pos-kiosk
EOF

sudo chmod +x /usr/local/bin/admin-terminal

# Configure hotkey (Ctrl+Alt+F1 to switch to TTY, then Ctrl+Alt+T for terminal)
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
echo ""
echo "Replace 'https://github.com/Molesafenetwork/msnpos2.git' with your actual Git repository URL if different"
