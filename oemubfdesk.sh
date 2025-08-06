#!/bin/bash
# Orange Pi 3B POS System Setup Script for Ubuntu XFCE 22.04
# Compatible with RK3566 chipset and XFCE Desktop
# Run with: curl -sSL https://raw.githubusercontent.com/Molesafenetwork/msnpos2/refs/heads/main/oemubfdesk.sh | bash

set -e

echo "                MOLE - POS - ORANGEPI 3b MSN POS (XFCE)                 "

# Check if running XFCE
if [ "$XDG_CURRENT_DESKTOP" = "XFCE" ] || [ "$DESKTOP_SESSION" = "xfce" ]; then
    echo "XFCE desktop environment detected. Good!"
elif [ -z "$XDG_CURRENT_DESKTOP" ]; then
    echo "Warning: No desktop environment detected. Assuming XFCE."
else
    echo "Warning: Desktop environment is $XDG_CURRENT_DESKTOP. This script is optimized for XFCE."
fi

# Update system
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# Install essential packages for Ubuntu XFCE
echo "Installing essential packages..."
sudo apt install -y curl git chromium-browser unclutter sed nano \
    wmctrl xdotool lightdm x11-utils xorg-dev \
    systemd-timesyncd openssh-server build-essential ufw snapd \
    xfce4-terminal xfce4-settings-manager

# Install Node.js 18.x LTS from NodeSource repository
echo "Installing Node.js 18.x LTS..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Verify Node.js installation
echo "Node.js version: $(node --version)"
echo "NPM version: $(npm --version)"

# Install PM2 globally
echo "Installing PM2..."
sudo npm install -g pm2

# User Management - Create proper accounts and remove default user
echo "Setting up user accounts..."

# Get the current user (should be the default orangepi user)
CURRENT_USER=$(whoami)
echo "Current user detected: $CURRENT_USER"

# Create admin user with strong password
echo "Creating admin user..."
sudo useradd -m -s /bin/bash admin
# Generate a random strong password for admin
ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
echo "admin:$ADMIN_PASSWORD" | sudo chpasswd
sudo usermod -a -G sudo,audio,video admin

# Create POS user with simple password for daily use
echo "Creating POS user..."
sudo useradd -m -s /bin/bash posuser
echo "posuser:pos2024!" | sudo chpasswd
# Add posuser to necessary groups (but not sudo for security)
sudo usermod -a -G audio,video posuser

# Store admin credentials securely
sudo mkdir -p /root/credentials
sudo tee /root/credentials/admin_info.txt << EOF
=== ADMIN ACCOUNT CREDENTIALS ===
Username: admin
Password: $ADMIN_PASSWORD
Created: $(date)

=== POS ACCOUNT CREDENTIALS ===  
Username: posuser
Password: pos2024!
Purpose: Daily POS operations (no sudo access)

=== SECURITY NOTES ===
- Default user '$CURRENT_USER' will be removed after reboot
- Admin user has full sudo access
- POS user has no sudo access (security)
- SSH is enabled for remote admin access
EOF

sudo chmod 600 /root/credentials/admin_info.txt

echo "✅ Admin user created with password: $ADMIN_PASSWORD"
echo "✅ POS user created with password: pos2024!"
echo "✅ Credentials saved to /root/credentials/admin_info.txt"

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
sudo nano /home/posuser/pos-system/.env
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

# Create admin-mode command for XFCE
sudo tee /usr/local/bin/admin-mode << 'EOF'
#!/bin/bash
# Toggle between POS kiosk and admin mode for XFCE
PID=$(pgrep -f "chromium.*kiosk.*localhost:3000")
if [ ! -z "$PID" ]; then
    echo "Switching to admin mode..."
    kill $PID
    # Start XFCE terminal in fullscreen
    DISPLAY=:0 xfce4-terminal --maximize --hold &
else
    echo "Starting POS kiosk mode..."
    /usr/local/bin/start-pos-kiosk &
fi
EOF

# Create start-pos-kiosk command for XFCE
sudo tee /usr/local/bin/start-pos-kiosk << 'EOF'
#!/bin/bash
export DISPLAY=:0

# Wait for POS server to be ready
echo "Waiting for POS server to start..."
while ! curl -s http://localhost:3000 > /dev/null; do
  sleep 1
done

# Kill any existing chromium processes
pkill -f chromium-browser || true

# Hide cursor
unclutter -idle 1 &

# Disable XFCE screensaver/power management
xfconf-query -c xfce4-screensaver -p /saver/enabled -s false 2>/dev/null || true
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-enabled -s false 2>/dev/null || true
xset -dpms
xset s off

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
  --disable-extensions \
  --disable-plugins \
  --disable-background-timer-throttling \
  --disable-backgrounding-occluded-windows \
  --disable-renderer-backgrounding \
  http://localhost:3000 &

echo "POS kiosk mode started"
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
StartLimitBurst=5
StartLimitIntervalSec=60

[Service]
Type=simple
User=posuser
WorkingDirectory=/home/posuser/pos-system
Environment=NODE_ENV=production
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create POS kiosk service for XFCE desktop environment
sudo tee /etc/systemd/system/pos-kiosk.service << 'EOF'
[Unit]
Description=POS Kiosk Display
After=pos-system.service graphical-session.target lightdm.service
Wants=pos-system.service
Requires=graphical.target

[Service]
Type=simple
User=posuser
Group=posuser
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/1001
Environment=HOME=/home/posuser
WorkingDirectory=/home/posuser
ExecStartPre=/bin/sleep 15
ExecStart=/usr/local/bin/start-pos-kiosk
Restart=always
RestartSec=10
KillMode=mixed
TimeoutStopSec=30

[Install]
WantedBy=graphical.target
EOF

# Create XFCE autostart directory and entry for POS kiosk
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
Terminal=false
EOF

# Create XFCE keyboard shortcut setup script
sudo tee /home/posuser/setup-xfce-hotkeys.sh << 'EOF'
#!/bin/bash
# Setup custom keyboard shortcuts for XFCE
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml

# Create keyboard shortcuts configuration
cat > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml << 'XFCEKEYS'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-keyboard-shortcuts" version="1.0">
  <property name="commands" type="empty">
    <property name="default" type="empty">
      <property name="&lt;Alt&gt;F1" type="string" value="xfce4-popup-applicationsmenu"/>
      <property name="&lt;Alt&gt;F2" type="string" value="xfrun4"/>
    </property>
    <property name="custom" type="empty">
      <property name="&lt;Primary&gt;&lt;Alt&gt;t" type="string" value="/usr/local/bin/admin-mode"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;r" type="string" value="/usr/local/bin/restart-pos"/>
      <property name="override" type="bool" value="true"/>
    </property>
  </property>
  <property name="xfwm4" type="empty">
    <property name="default" type="empty">
      <property name="&lt;Alt&gt;Tab" type="string" value="cycle_windows_key"/>
      <property name="Escape" type="string" value="cancel_key"/>
    </property>
    <property name="custom" type="empty">
      <property name="override" type="bool" value="true"/>
    </property>
  </property>
  <property name="providers" type="array">
    <value type="string" value="xfwm4"/>
    <value type="string" value="commands"/>
  </property>
</channel>
XFCEKEYS
EOF

sudo chmod +x /home/posuser/setup-xfce-hotkeys.sh

# Create admin user bashrc with additional system commands
sudo tee /home/admin/.bashrc << 'EOF'
# Admin Terminal Commands (Full System Access)
alias edit-env='sudo nano /home/posuser/pos-system/.env && sudo systemctl restart pos-system'
alias setup-tailnet='curl -fsSL https://tailscale.com/install.sh | sh && echo "Run: sudo tailscale up"'
alias restart-pos='sudo systemctl restart pos-system pos-kiosk'
alias pos-logs='journalctl -u pos-system -f'
alias generate-key='cd /home/posuser/pos-system && sudo -u posuser node -e "const CryptoJS = require(\"crypto-js\"); const key = CryptoJS.lib.WordArray.random(32); console.log(\"New key:\", key.toString());"'
alias check-env='cat /home/posuser/pos-system/.env'
alias pdf-storage='ls -la /home/posuser/pos-system/public/.data/'
alias admin-mode='sudo -u posuser /usr/local/bin/admin-mode'
alias kiosk-mode='sudo -u posuser /usr/local/bin/start-pos-kiosk'
alias show-credentials='sudo cat /root/credentials/admin_info.txt'
alias remove-default-user='sudo /usr/local/bin/remove-default-user'
alias system-status='systemctl status pos-system pos-kiosk && echo "=== NETWORK ===" && ip addr show && echo "=== DISK ===" && df -h'

# Terminal customization
PS1='\[\033[01;31m\]ADMIN\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

echo "=== ADMIN Terminal (Full Access) ==="
echo "Available commands:"
echo "  edit-env           - Edit POS environment variables"
echo "  setup-tailnet      - Install and setup Tailscale VPN" 
echo "  restart-pos        - Restart POS services"
echo "  pos-logs           - View POS application logs"
echo "  generate-key       - Generate new encryption key"
echo "  check-env          - View current POS settings"
echo "  pdf-storage        - Check PDF storage directory"
echo "  admin-mode         - Switch POS to admin mode"
echo "  kiosk-mode         - Switch POS to kiosk mode"
echo "  show-credentials   - Show admin/POS passwords"
echo "  remove-default-user- Remove default orangepi user"
echo "  system-status      - Show system and POS status"
echo ""
echo "Security: Admin account with full sudo access"
echo "================================="
EOF

# Create custom bashrc for posuser with POS commands (limited access)
sudo tee /home/posuser/.bashrc << 'EOF'
# Custom POS Terminal Commands (Limited Access)
alias edit-env='echo "Access denied. Contact admin to edit environment variables."'
alias setup-tailnet='echo "Access denied. Contact admin for Tailscale setup."'
alias restart-pos='echo "Access denied. Use Ctrl+Alt+R hotkey or contact admin."'
alias pos-logs='journalctl -u pos-system -f'
alias generate-key='echo "Access denied. Contact admin for key generation."'
alias check-env='echo "Access denied. Contact admin to view environment settings."'
alias pdf-storage='ls -la /home/posuser/pos-system/public/.data/'
alias admin-mode='/usr/local/bin/admin-mode'
alias kiosk-mode='/usr/local/bin/start-pos-kiosk'
alias contact-admin='echo "Admin SSH: ssh admin@$(hostname -I | cut -d\" \" -f1)"'

# Terminal customization
PS1='\[\033[01;32m\]POS-USER\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

echo "=== POS User Terminal (Limited Access) ==="
echo "Available commands:"
echo "  pos-logs      - View POS application logs"
echo "  pdf-storage   - Check PDF storage directory"
echo "  admin-mode    - Toggle between kiosk and admin mode"
echo "  kiosk-mode    - Start POS kiosk mode"
echo "  contact-admin - Show admin SSH connection info"
echo ""
echo "Note: Limited access account for POS operations only"
echo "Hotkeys: Ctrl+Alt+T (admin mode), Ctrl+Alt+R (restart)"
echo "For system changes, contact admin user"
echo "=========================="
EOF

# Create POS user profile setup for XFCE
sudo tee /home/posuser/.profile << 'EOF'
# Setup POS environment
export PATH="/usr/local/bin:$PATH"

# Auto-setup XFCE hotkeys on first login
if [ ! -f ~/.xfce-hotkeys-setup ]; then
    /home/posuser/setup-xfce-hotkeys.sh
    touch ~/.xfce-hotkeys-setup
fi

# Set XFCE as the desktop session
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=xfce
EOF

# Create script to safely remove default user after reboot
sudo tee /usr/local/bin/remove-default-user << 'EOF'
#!/bin/bash
# Script to remove default orangepi user safely

# Get the original user that ran the setup
ORIGINAL_USER="orangepi"
if [ -f /tmp/setup-original-user ]; then
    ORIGINAL_USER=$(cat /tmp/setup-original-user)
fi

echo "This will remove the default user: $ORIGINAL_USER"
echo "Make sure you're logged in as 'admin' user before proceeding!"
echo ""
read -p "Are you sure you want to remove user '$ORIGINAL_USER'? (yes/no): " confirm

if [ "$confirm" = "yes" ]; then
    # Check if we're not running as the user we want to delete
    if [ "$(whoami)" = "$ORIGINAL_USER" ]; then
        echo "Error: You cannot delete the user you're currently logged in as!"
        echo "Please log in as 'admin' user first, then run this command."
        exit 1
    fi
    
    echo "Removing user $ORIGINAL_USER..."
    
    # Kill any processes owned by the user
    sudo pkill -u "$ORIGINAL_USER" || true
    
    # Remove the user and their home directory
    sudo userdel -r "$ORIGINAL_USER" 2>/dev/null || true
    
    # Remove from any additional groups
    sudo deluser "$ORIGINAL_USER" sudo 2>/dev/null || true
    
    echo "✅ User '$ORIGINAL_USER' has been removed"
    echo "✅ System is now secure with only admin and posuser accounts"
    
    # Clean up
    sudo rm -f /tmp/setup-original-user
else
    echo "Operation cancelled"
fi
EOF

# Create a record of the original user for later removal
echo "$CURRENT_USER" | sudo tee /tmp/setup-original-user > /dev/null

sudo chmod +x /usr/local/bin/remove-default-user

# Set proper permissions for both user accounts
sudo chown -R admin:admin /home/admin
sudo chown -R posuser:posuser /home/posuser
sudo chmod +x /home/admin/.profile /home/posuser/.profile 2>/dev/null || true

# Configure auto-login for posuser with LightDM (XFCE uses LightDM, not GDM)
sudo tee /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
autologin-guest=false
autologin-user=posuser
autologin-user-timeout=0
autologin-session=xfce
EOF

# Create a script to ensure services start in correct order
sudo tee /usr/local/bin/pos-startup-check << 'EOF'
#!/bin/bash
# Ensure POS system starts correctly
sleep 5

# Check if POS system is running
if ! systemctl is-active --quiet pos-system; then
    echo "Starting POS system..."
    systemctl start pos-system
    sleep 10
fi

# Check if we're in a desktop session before starting kiosk
if [ -n "$DISPLAY" ] && [ "$XDG_CURRENT_DESKTOP" = "XFCE" ]; then
    if ! pgrep -f "chromium.*kiosk.*localhost:3000" > /dev/null; then
        echo "Starting POS kiosk..."
        /usr/local/bin/start-pos-kiosk &
    fi
fi
EOF

sudo chmod +x /usr/local/bin/pos-startup-check

# Enable services
sudo systemctl daemon-reload
sudo systemctl enable pos-system

# Don't enable pos-kiosk service by default to avoid conflicts
# We'll use autostart instead for XFCE

# Disable Ubuntu's automatic updates to prevent interruptions
sudo systemctl disable unattended-upgrades 2>/dev/null || true
sudo systemctl mask unattended-upgrades 2>/dev/null || true

# Configure firewall for POS system
sudo ufw allow 3000/tcp
sudo ufw allow ssh
echo "y" | sudo ufw enable

echo ""
echo "=== SETUP COMPLETE FOR XFCE ==="
echo ""
echo "IMPORTANT SECURITY INFORMATION:"
echo "================================="
echo "✅ Admin user created with password: $ADMIN_PASSWORD"
echo "✅ POS user created with password: pos2024!"
echo "✅ Credentials saved to: /root/credentials/admin_info.txt"
echo ""
echo "⚠️  DEFAULT USER SECURITY:"
echo "- Default user '$CURRENT_USER' is still active"
echo "- After reboot, log in as 'admin' and run: remove-default-user"
echo "- Or SSH as admin: ssh admin@[ip-address]"
echo ""
echo "REBOOT REQUIRED:"
echo "sudo reboot"
echo ""
echo "=== POST-REBOOT ACCESS ==="
echo "• Kiosk Mode: Automatic (POS interface)"
echo "• Admin Access: ssh admin@[ip-address] (password: $ADMIN_PASSWORD)"
echo "• POS User: Kiosk will auto-login as posuser"
echo "• Admin Console: Ctrl+Alt+T when in kiosk"
echo ""
echo "=== USER ACCOUNT STRUCTURE ==="
echo "• admin    - Full system access, sudo, SSH (password: $ADMIN_PASSWORD)"
echo "• posuser  - POS operations only, auto-login (password: pos2024!)"
echo "• $CURRENT_USER - Default user (REMOVE after confirming admin access)"
echo ""
echo "=== ADMIN TASKS AFTER REBOOT ==="
echo "1. SSH as admin: ssh admin@[ip-address]"
echo "2. Verify POS system works"
echo "3. Run: remove-default-user"
echo "4. Run: show-credentials (to view all passwords)"
echo ""
echo "=== SECURITY FEATURES ==="
echo "• POS user has NO sudo access (can't modify system)"
echo "• Admin user has full access for maintenance"
echo "• SSH enabled for remote administration"
echo "• Firewall configured (ports 22, 3000)"
echo "• Auto-updates disabled (manual control)"
echo ""
echo "=== TROUBLESHOOTING ==="
echo "If kiosk doesn't start automatically:"
echo "• Run: sudo systemctl status pos-system"
echo "• Run: /usr/local/bin/start-pos-kiosk"
echo "• Check logs: journalctl -u pos-system"
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
