#!/bin/bash
# Orange Pi 3B POS System Setup Script for Ubuntu Focal (20.04)
# FIXED VERSION - Addresses kiosk login redirect issues
# Compatible with RK3566 chipset and XFCE Desktop Environment
# Run with: curl -sSL https://raw.githubusercontent.com/Molesafenetwork/msnpos2/main/initfdesk20.sh | bash
set -e

echo "                MOLE - POS - ORANGEPI 3b MSN POS (FOCAL - FIXED KIOSK) - AUTO DISPLAY DETECTION                 "
echo "@@@@@@@@@@    @@@@@@   @@@  @@@"       
echo "@@@@@@@@@@@  @@@@@@@   @@@@ @@@"       
echo "@@! @@! @@!  !@@       @@!@!@@@"       
echo "!@! !@! !@!  !@!       !@!!@!@!"       
echo "@!! !!@ @!@  !!@@!!    @!@ !!@!"        
echo "!@!   ! !@!   !!@!!!   !@!  !!!"        
echo "!!:     !!:       !:!  !!:  !!!"        
echo ":!:     :!:      !:!   :!:  !:!"        
echo ":::     ::   :::: ::    ::   ::"      
echo " :      :    :: : :     ::    :"    

# Check Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "unknown")
echo "Detected Ubuntu version: $UBUNTU_VERSION (focal)"

# Update package lists only (no system upgrade)
echo "Refreshing package lists (no system upgrade)..."
sudo apt update
sudo dpkg --configure -a 

# Install essential packages for XFCE Desktop (focal compatible)
echo "Installing essential packages for XFCE..."
sudo apt install -y curl git unclutter sed nano \
    wmctrl xdotool lightdm x11-utils xfce4-session \
    systemd-timesyncd openssh-server build-essential ufw \
    xfce4-terminal xfce4-panel xfce4-settings xinit xorg \
    npm jq

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

echo "✅ Browser installation completed"

# Create POS user if it doesn't exist
if ! id "posuser" &>/dev/null; then
    echo "Creating POS user..."
    sudo useradd -m -s /bin/bash posuser
    echo "posuser:posuser123" | sudo chpasswd
    # Add posuser to necessary groups
    sudo usermod -a -G sudo,audio,video posuser
else
    echo "User 'posuser' already exists"
fi

# Clone or update POS repository
echo "Setting up POS application..."
if [ -d "/home/posuser/pos-system" ]; then
    echo "POS system directory exists, pulling latest changes..."
    cd /home/posuser/pos-system
    sudo -u posuser git pull || echo "Git pull failed, continuing..."
else
    echo "Cloning POS application..."
    cd /home/posuser
    sudo -u posuser git clone https://github.com/Molesafenetwork/msnpos2.git pos-system
fi

cd /home/posuser/pos-system

# Install NVM and Node.js for posuser
echo "Installing NVM and Node.js 18 for posuser..."
sudo -u posuser bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'

# Source NVM and install Node 18
sudo -u posuser bash -c '
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 18
nvm use 18
nvm alias default 18
'

# Add NVM to posuser's bashrc and profile
sudo -u posuser bash -c 'echo "export NVM_DIR=\$HOME/.nvm" >> ~/.bashrc'
sudo -u posuser bash -c 'echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"" >> ~/.bashrc'
sudo -u posuser bash -c 'echo "[ -s \"\$NVM_DIR/bash_completion\" ] && \. \"\$NVM_DIR/bash_completion\"" >> ~/.bashrc'

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

# Install Node.js dependencies using NVM's Node
echo "Installing Node.js dependencies..."
sudo -u posuser bash -c '
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
cd /home/posuser/pos-system
npm install || echo "Some dependencies may have failed, continuing..."
npm audit fix || echo "Audit fix completed with warnings"
'

# Set up .env file
ENV_PATH=".env"
cd /home/posuser/pos-system

# Generate crypto key
if [ -f "$ENV_PATH" ] && grep -q 'ENCRYPTION_KEY=' "$ENV_PATH" && ! grep -q 'ENCRYPTION_KEY=$' "$ENV_PATH"; then
    echo ".env file exists with encryption key, skipping key generation..."
else
    echo "Generating encryption key..."
    CRYPTO_KEY=$(sudo -u posuser bash -c '
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    cd /home/posuser/pos-system
    node -e "const CryptoJS = require(\"crypto-js\"); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());" 2>/dev/null || echo "fallback_key_$(date +%s)"
    ')
    
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
    fi
fi

# Ensure .data directory exists
sudo -u posuser mkdir -p public/.data
sudo chmod 755 public/.data

# Create custom commands directory
sudo mkdir -p /usr/local/bin

# Create detect-display utility with improved compatibility
sudo tee /usr/local/bin/detect-display << 'EOF'
#!/bin/bash
# Auto-detect available display for maximum compatibility

check_display() {
    local display=$1
    if command -v xset >/dev/null 2>&1; then
        if timeout 2 sh -c "DISPLAY=$display xset q >/dev/null 2>&1"; then
            return 0
        fi
    fi
    
    if command -v xdpyinfo >/dev/null 2>&1; then
        if timeout 2 sh -c "DISPLAY=$display xdpyinfo >/dev/null 2>&1"; then
            return 0
        fi
    fi
    
    if [ -S "/tmp/.X11-unix/X${display#:}" ]; then
        return 0
    fi
    
    return 1
}

get_session_display() {
    if [ ! -z "$DISPLAY" ] && check_display "$DISPLAY"; then
        echo "$DISPLAY"
        return 0
    fi
    
    if [ ! -z "$XDG_VTNR" ]; then
        local tty_display=":$((XDG_VTNR - 1))"
        if check_display "$tty_display"; then
            echo "$tty_display"
            return 0
        fi
    fi
    
    return 1
}

if SESSION_DISPLAY=$(get_session_display); then
    echo "$SESSION_DISPLAY"
    exit 0
fi

DISPLAYS=(":0" ":1" ":10" ":11" ":2" ":3")
for display in "${DISPLAYS[@]}"; do
    if check_display "$display"; then
        echo "$display"
        exit 0
    fi
done

if pgrep -f "lightdm.*X" >/dev/null; then
    LIGHTDM_DISPLAY=$(ps aux | grep -E "lightdm.*X\s+:[0-9]+" | grep -oE ":[0-9]+" | head -1)
    if [ ! -z "$LIGHTDM_DISPLAY" ]; then
        echo "$LIGHTDM_DISPLAY"
        exit 0
    fi
fi

echo ":0"
EOF

sudo chmod +x /usr/local/bin/detect-display

# FIXED: Create start-pos-kiosk command with better error handling and session management
sudo tee /usr/local/bin/start-pos-kiosk << 'EOF'
#!/bin/bash
# Fixed POS Kiosk Startup with proper session handling

LOG_FILE="/var/log/pos-kiosk.log"
echo "$(date): Starting POS kiosk..." >> "$LOG_FILE"

# Kill any existing browser processes that might interfere
pkill -f "chromium.*localhost:3000" 2>/dev/null || true
pkill -f "firefox.*localhost:3000" 2>/dev/null || true

# Wait for POS server to be ready with better checking
echo "$(date): Waiting for POS server..." >> "$LOG_FILE"
SERVER_READY=false
for i in {1..60}; do
    if curl -s --connect-timeout 2 http://localhost:3000 > /dev/null 2>&1; then
        SERVER_READY=true
        echo "$(date): POS server is ready after $i seconds" >> "$LOG_FILE"
        break
    fi
    sleep 2
done

if [ "$SERVER_READY" = false ]; then
    echo "$(date): ERROR: POS server failed to start after 120 seconds" >> "$LOG_FILE"
    exit 1
fi

# Auto-detect available display
DETECTED_DISPLAY=$(detect-display)
export DISPLAY=$DETECTED_DISPLAY

echo "$(date): Using detected display: $DETECTED_DISPLAY" >> "$LOG_FILE"

# Wait for X server to be ready
echo "$(date): Waiting for X server on $DETECTED_DISPLAY..." >> "$LOG_FILE"
X_READY=false
for i in {1..30}; do
    if DISPLAY=$DETECTED_DISPLAY xset q >/dev/null 2>&1; then
        X_READY=true
        echo "$(date): X server ready on $DETECTED_DISPLAY after $i seconds" >> "$LOG_FILE"
        break
    fi
    sleep 1
done

if [ "$X_READY" = false ]; then
    echo "$(date): ERROR: X server not ready on $DETECTED_DISPLAY" >> "$LOG_FILE"
    exit 1
fi

# Hide cursor
unclutter -idle 1 -display $DETECTED_DISPLAY &

# Disable screensaver/power management
xset -display $DETECTED_DISPLAY s off
xset -display $DETECTED_DISPLAY -dpms
xset -display $DETECTED_DISPLAY s noblank

# Determine which browser to use
BROWSER_CMD=""
BROWSER_ARGS=""

if command -v chromium-browser >/dev/null 2>&1; then
    BROWSER_CMD="chromium-browser"
    BROWSER_ARGS="--kiosk --no-first-run --disable-restore-session-state --disable-infobars --disable-translate --disable-dev-shm-usage --no-sandbox --disk-cache-dir=/tmp --start-maximized --window-position=0,0 --user-data-dir=/tmp/chromium-kiosk-$$"
elif command -v chromium >/dev/null 2>&1; then
    BROWSER_CMD="chromium"
    BROWSER_ARGS="--kiosk --no-first-run --disable-restore-session-state --disable-infobars --disable-translate --disable-dev-shm-usage --no-sandbox --disk-cache-dir=/tmp --start-maximized --window-position=0,0 --user-data-dir=/tmp/chromium-kiosk-$$"
elif command -v firefox >/dev/null 2>&1; then
    BROWSER_CMD="firefox"
    BROWSER_ARGS="--kiosk --private-window"
else
    echo "$(date): ERROR: No suitable browser found" >> "$LOG_FILE"
    exit 1
fi

echo "$(date): Starting browser: $BROWSER_CMD" >> "$LOG_FILE"

# Start browser with proper environment and error handling
export DISPLAY=$DETECTED_DISPLAY
$BROWSER_CMD $BROWSER_ARGS http://localhost:3000 >> "$LOG_FILE" 2>&1 &
BROWSER_PID=$!

echo "$(date): Browser started with PID $BROWSER_PID" >> "$LOG_FILE"

# Wait a bit to ensure browser started
sleep 5

# Check if browser is still running
if kill -0 $BROWSER_PID 2>/dev/null; then
    echo "$(date): Browser successfully started and running" >> "$LOG_FILE"
else
    echo "$(date): ERROR: Browser failed to start or crashed immediately" >> "$LOG_FILE"
    exit 1
fi

# Keep the script running to maintain the session
wait $BROWSER_PID
echo "$(date): Browser process ended" >> "$LOG_FILE"
EOF

# Create admin-mode command
sudo tee /usr/local/bin/admin-mode << 'EOF'
#!/bin/bash
PID=$(pgrep -f "kiosk.*localhost:3000")
if [ ! -z "$PID" ]; then
    echo "Switching to admin mode..."
    kill $PID
    
    DETECTED_DISPLAY=$(detect-display)
    export DISPLAY="$DETECTED_DISPLAY"
    
    echo "Using display: $DISPLAY for admin terminal"
    DISPLAY="$DISPLAY" xfce4-terminal --fullscreen &
else
    echo "Starting POS kiosk mode..."
    /usr/local/bin/start-pos-kiosk &
fi
EOF

# Create other utility commands
sudo tee /usr/local/bin/restart-pos << 'EOF'
#!/bin/bash
echo "Restarting POS system and kiosk..."
sudo systemctl restart pos-system pos-kiosk
echo "POS system restarted"
EOF

sudo tee /usr/local/bin/pos-logs << 'EOF'
#!/bin/bash
echo "POS System logs (press Ctrl+C to exit):"
echo "=== Application Logs ==="
journalctl -u pos-system -f --no-pager &
APP_PID=$!
echo "=== Kiosk Logs ==="
tail -f /var/log/pos-kiosk.log &
KIOSK_PID=$!
wait
EOF

# Make commands executable
sudo chmod +x /usr/local/bin/*

# FIXED: Create systemd service with proper Node.js path from NVM
sudo tee /etc/systemd/system/pos-system.service << 'EOF'
[Unit]
Description=POS System Node.js Application
After=network.target

[Service]
Type=simple
User=posuser
WorkingDirectory=/home/posuser/pos-system
Environment=NODE_ENV=production
Environment=NVM_DIR=/home/posuser/.nvm
ExecStart=/bin/bash -c 'source /home/posuser/.nvm/nvm.sh && node server.js'
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# FIXED: Updated kiosk service with better timing and dependencies
sudo tee /etc/systemd/system/pos-kiosk.service << 'EOF'
[Unit]
Description=POS Kiosk Display (Auto-Detect)
After=pos-system.service lightdm.service graphical.target
Wants=pos-system.service
Requires=graphical.target

[Service]
Type=simple
User=posuser
Group=posuser
Environment=XDG_RUNTIME_DIR=/run/user/1001
WorkingDirectory=/home/posuser
ExecStartPre=/bin/sleep 30
ExecStart=/usr/local/bin/start-pos-kiosk
Restart=always
RestartSec=15
RestartPreventExitStatus=0
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
EOF

# Create improved XFCE autostart
sudo mkdir -p /home/posuser/.config/autostart
sudo tee /home/posuser/.config/autostart/pos-kiosk.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=POS Kiosk
Comment=Start POS system in kiosk mode with auto display detection
Exec=/usr/local/bin/start-pos-kiosk
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
EOF

# Create improved bashrc for posuser
sudo tee /home/posuser/.bashrc << 'EOF'
# NVM Configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Custom POS Terminal Commands
alias edit-env='nano /home/posuser/pos-system/.env && sudo systemctl restart pos-system'
alias restart-pos='sudo systemctl restart pos-system pos-kiosk'
alias pos-logs='journalctl -u pos-system -f'
alias check-env='cat /home/posuser/pos-system/.env'
alias pdf-storage='ls -la /home/posuser/pos-system/public/.data/'
alias admin-mode='/usr/local/bin/admin-mode'
alias kiosk-mode='/usr/local/bin/start-pos-kiosk'

# Terminal customization
PS1='\[\033[01;32m\]POS-FOCAL-FIXED\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

echo "=== POS Admin Terminal (Ubuntu Focal - FIXED VERSION) ==="
echo "Available commands:"
echo "  edit-env      - Edit environment variables"
echo "  restart-pos   - Restart POS services"
echo "  pos-logs      - View POS application logs"
echo "  check-env     - View current .env settings"
echo "  pdf-storage   - Check PDF storage directory"
echo "  admin-mode    - Toggle between kiosk and admin mode"
echo "  kiosk-mode    - Start POS kiosk mode"
echo ""
echo "Hotkey: Ctrl+Alt+T to toggle admin mode"
echo "Node.js: $(node --version 2>/dev/null || echo 'Not loaded')"
echo "Current Display: $(detect-display 2>/dev/null || echo 'Auto-Detect')"
echo "=========================="
EOF

# Set proper permissions
sudo chown -R posuser:posuser /home/posuser

# Configure LightDM for focal
sudo cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup 2>/dev/null || true
sudo tee /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
autologin-user=posuser
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-gtk-greeter
greeter-hide-users=false
allow-user-switching=true
allow-guest=false
EOF

# Create log file with proper permissions
sudo mkdir -p /var/log
sudo touch /var/log/pos-kiosk.log
sudo chown posuser:posuser /var/log/pos-kiosk.log

# Enable services
sudo systemctl daemon-reload
sudo systemctl enable pos-system
sudo systemctl enable lightdm

# Configure firewall
sudo ufw allow 3000/tcp
sudo ufw allow ssh
echo "y" | sudo ufw enable

echo ""
echo "=== FOCAL POS SETUP COMPLETE (FIXED VERSION) ==="
echo ""
echo "FIXES APPLIED:"
echo "• Fixed Node.js path resolution in systemd service"
echo "• Improved server readiness checking in kiosk script"
echo "• Better error logging and handling"
echo "• Proper browser session management"
echo "• Enhanced display detection and X server waiting"
echo "• Using NVM-installed Node.js instead of system Node.js"
echo ""
echo "IMPORTANT: Reboot the system to start POS kiosk mode"
echo "sudo reboot"
echo ""
echo "DEBUGGING:"
echo "• Check logs: sudo journalctl -u pos-system -f"
echo "• Check kiosk logs: tail -f /var/log/pos-kiosk.log"
echo "• Manual test: sudo -u posuser bash -c 'cd /home/posuser/pos-system && source ~/.nvm/nvm.sh && node server.js'"
echo ""
echo "System ready for reboot!"
