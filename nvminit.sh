#!/bin/bash

# POS System Setup Script for Ubuntu 22.04 (Focal) - FIXED VERSION
# Designed for Orange Pi 3B with MSNPos2 integration
# Usage: sudo curl -fsSL https://raw.githubusercontent.com/Molesafenetwork/msnpos2/main/nvminit.sh | sudo bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
fi

# Verify Ubuntu 22.04
if ! grep -q "22.04" /etc/os-release; then
    warn "This script is designed for Ubuntu 22.04. Proceeding anyway..."
fi

log "Starting POS System Setup (Fixed Version)..."

# Update system
log "Updating system packages..."
apt update && apt upgrade -y

# Install required dependencies with proper XFCE environment
log "Installing dependencies..."
apt install -y \
    curl \
    wget \
    git \
    firefox \
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    xfce4-session \
    xfce4-settings \
    lightdm \
    lightdm-gtk-greeter \
    lightdm-gtk-greeter-settings \
    x11-xserver-utils \
    xorg \
    xinit \
    xserver-xorg \
    x11-session-utils \
    unclutter \
    sudo \
    pwgen \
    autojump \
    build-essential \
    libssl-dev \
    xbindkeys \
    dbus-x11 \
    at-spi2-core \
    desktop-file-utils \
    shared-mime-info

# Ensure systemd services are properly configured
systemctl enable lightdm
systemctl set-default graphical.target

# Create posuser with proper shell and groups
log "Creating posuser..."
if id "posuser" &>/dev/null; then
    warn "User posuser already exists, skipping creation"
else
    useradd -m -s /bin/bash posuser
    echo "posuser:posuser123" | chpasswd
    usermod -aG sudo,audio,video,plugdev,netdev,bluetooth posuser
    log "Created posuser with password: posuser123"
fi

# Create proper home directory structure first
log "Setting up user directories..."
mkdir -p /home/posuser/{Desktop,Documents,Downloads,Pictures,Music,Videos}
mkdir -p /home/posuser/.config/{xfce4,autostart}
mkdir -p /home/posuser/.local/share/applications

# Install NVM (Node Version Manager) as posuser
log "Installing NVM..."
sudo -u posuser bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash'

# Source NVM and install Node.js 18
log "Installing Node.js 18 via NVM..."
sudo -u posuser bash -c 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && nvm install 18 && nvm use 18 && nvm alias default 18'

# Install Tailscale
log "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

# Create POS directory structure
log "Setting up POS directory structure..."
POS_HOME="/home/posuser"
mkdir -p "$POS_HOME/pos-system"
mkdir -p "$POS_HOME/pos-system/logs"
mkdir -p "$POS_HOME/pos-system/config"

# Set proper ownership first
chown -R posuser:posuser "$POS_HOME/pos-system"

# Download MSNPos2
log "Downloading MSNPos2 from GitHub..."
cd "$POS_HOME/pos-system"
if [ -d "msnpos2" ]; then
    rm -rf msnpos2
fi
sudo -u posuser git clone https://github.com/Molesafenetwork/msnpos2.git msnpos2

# Ensure proper ownership after clone
chown -R posuser:posuser "$POS_HOME/pos-system"

# Install npm dependencies
log "Installing Node.js dependencies..."
cd "$POS_HOME/pos-system/msnpos2"
sudo -u posuser bash -c 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && npm install'

# Create environment file in the msnpos2 directory
log "Creating environment configuration..."
cat > "$POS_HOME/pos-system/msnpos2/.env" << 'EOF'
# change these default values during manual install (if using oemssdprod.sh this will be easier to change the setup scripts also setup admin commands which may be needed)
MOLE_SAFE_USERS=admin:Admin1234,worker1:worker1
SESSION_SECRET=123485358953
ENCRYPTION_KEY=$CRYPTO_KEY
COMPANY_NAME=Mole Safe Network
COMPANY_ADDRESS=123 random road
COMPANY_PHONE=61756666665
COMPANY_EMAIL=support@mole-safe.net
COMPANY_ABN=333333333
EOF

# Set proper ownership of .env file
chown posuser:posuser "$POS_HOME/pos-system/msnpos2/.env"

# Create comprehensive .bashrc for posuser
log "Creating custom .bashrc for posuser..."
cat > /home/posuser/.bashrc << 'EOF'
# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History settings
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000

# Check window size after each command
shopt -s checkwinsize

# Enable color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Enhanced prompt with colors
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# POS System Variables
export POS_HOME="$HOME/pos-system"
export POS_CONFIG="$POS_HOME/config"
export POS_LOGS="$POS_HOME/logs"
export POS_APP="$POS_HOME/msnpos2"
export PATH="$PATH:$POS_HOME/bin"

# Source NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Source autojump
if [ -f /usr/share/autojump/autojump.sh ]; then
    . /usr/share/autojump/autojump.sh
fi

# =============================================================================
# POS SYSTEM CUSTOM COMMANDS
# =============================================================================

# Edit environment configuration
edit-env() {
    local env_file="$POS_APP/.env"
    echo "Editing POS environment configuration..."
    if command -v nano >/dev/null 2>&1; then
        nano "$env_file"
    elif command -v vim >/dev/null 2>&1; then
        vim "$env_file"
    else
        echo "No suitable editor found. Installing nano..."
        sudo apt install -y nano
        nano "$env_file"
    fi
    echo "Environment configuration updated. Run 'restart-pos' to apply changes."
}

# Generate crypto key
generate-key() {
    echo "Generating new crypto key..."
    # Source NVM first
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    if command -v node >/dev/null 2>&1; then
        cd "$POS_APP"
        local key
        key=$(node -e "const CryptoJS = require('crypto-js'); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());")
        echo "Generated Crypto Key: $key"
        echo "$key" > "$POS_CONFIG/crypto.key"
        echo "Key saved to $POS_CONFIG/crypto.key"
        
        # Update .env file with the new key
        sed -i "s/ENCRYPTION_KEY=\$CRYPTO_KEY/ENCRYPTION_KEY=$key/" "$POS_APP/.env"
        echo "Updated .env file with new encryption key"
    else
        echo "Error: Node.js not found. Please ensure NVM and Node.js 18 are properly installed."
        return 1
    fi
}

# Start POS system
start-pos() {
    echo "Starting POS system..."
    local log_file="$POS_LOGS/pos-$(date +%Y%m%d).log"
    
    if pgrep -f "node.*server.js" > /dev/null; then
        echo "POS system is already running."
        return 0
    fi
    
    # Source NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    cd "$POS_APP"
    if [ -f ".env" ]; then
        source .env
    fi
    
    nohup node server.js >> "$log_file" 2>&1 &
    local pid=$!
    echo $pid > "$POS_CONFIG/pos.pid"
    echo "POS system started with PID: $pid"
    echo "Logs: $log_file"
}

# Stop POS system
stop-pos() {
    echo "Stopping POS system..."
    local pid_file="$POS_CONFIG/pos.pid"
    
    if [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            echo "POS system stopped (PID: $pid)"
            rm -f "$pid_file"
        else
            echo "POS system not running (stale PID file removed)"
            rm -f "$pid_file"
        fi
    else
        # Fallback: kill by process name
        if pgrep -f "node.*server.js" > /dev/null; then
            pkill -f "node.*server.js"
            echo "POS system stopped (killed by process name)"
        else
            echo "POS system is not running."
        fi
    fi
}

# Restart POS system
restart-pos() {
    echo "Restarting POS system..."
    stop-pos
    sleep 2
    start-pos
}

# Check POS system status
status-pos() {
    echo "Checking POS system status..."
    local pid_file="$POS_CONFIG/pos.pid"
    
    if [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo "POS system is running (PID: $pid)"
            echo "Memory usage: $(ps -o pid,rss,command -p "$pid" | tail -n1)"
        else
            echo "POS system is not running (stale PID file)"
            rm -f "$pid_file"
        fi
    else
        if pgrep -f "node.*server.js" > /dev/null; then
            echo "POS system is running (no PID file, manual start detected)"
        else
            echo "POS system is not running."
        fi
    fi
    
    # Check if Firefox kiosk is running
    if pgrep firefox > /dev/null; then
        echo "Firefox kiosk mode is active"
    else
        echo "Firefox kiosk mode is not running"
    fi
}

# View POS logs
logs-pos() {
    local log_file="$POS_LOGS/pos-$(date +%Y%m%d).log"
    if [ -f "$log_file" ]; then
        echo "Showing today's POS logs (press Ctrl+C to exit):"
        tail -f "$log_file"
    else
        echo "No log file found for today: $log_file"
        echo "Available logs:"
        ls -la "$POS_LOGS/" 2>/dev/null || echo "No logs directory found"
    fi
}

# Tailscale management
install-tailscale() {
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sudo sh
    echo "Tailscale installed. Run 'sudo tailscale up' to connect."
}

tailscale-up() {
    echo "Starting Tailscale..."
    sudo tailscale up "$@"
}

tailscale-status() {
    echo "Tailscale status:"
    sudo tailscale status
}

tailscale-ip() {
    echo "Tailscale IP:"
    sudo tailscale ip -4
}

# User management
change-posuser-password() {
    echo "Changing posuser password..."
    sudo passwd posuser
}

change-orangepi-password() {
    echo "Changing orangepi user password..."
    if id "orangepi" &>/dev/null; then
        sudo passwd orangepi
    else
        echo "User 'orangepi' does not exist."
    fi
}

delete-orangepi-user() {
    echo "WARNING: This will permanently delete the orangepi user account!"
    read -p "Are you sure? Type 'DELETE' to confirm: " confirm
    if [ "$confirm" = "DELETE" ]; then
        if id "orangepi" &>/dev/null; then
            sudo userdel -r orangepi 2>/dev/null || sudo userdel orangepi
            echo "User 'orangepi' has been deleted."
        else
            echo "User 'orangepi' does not exist."
        fi
    else
        echo "Cancelled."
    fi
}

# Kiosk mode management
start-kiosk() {
    echo "Starting Firefox in kiosk mode..."
    export DISPLAY=:0
    
    # Kill any existing Firefox instances
    pkill firefox 2>/dev/null || true
    sleep 2
    
    # Hide XFCE panel completely in kiosk mode
    xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -s 2 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/size -s 1 2>/dev/null || true
    
    # Start Firefox in full kiosk mode
    firefox --kiosk --new-instance --no-remote "http://localhost:3000" &
    
    # Hide cursor after 1 second of inactivity
    unclutter -idle 1 -root &
    
    # Disable all keyboard shortcuts except our admin hotkey
    xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/default/Alt_L" -s "" 2>/dev/null || true
    xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/default/Super_L" -s "" 2>/dev/null || true
}

stop-kiosk() {
    echo "Stopping kiosk mode (entering admin mode)..."
    pkill firefox 2>/dev/null || true
    pkill unclutter 2>/dev/null || true
    
    # Show XFCE panel in admin mode
    xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -s 0 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/size -s 28 2>/dev/null || true
    
    # Re-enable keyboard shortcuts
    xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/default/Alt_L" -s "popup_menu" 2>/dev/null || true
}

restart-kiosk() {
    echo "Returning to kiosk mode..."
    stop-kiosk
    sleep 2
    start-kiosk
}

# Admin mode toggle
enter-admin-mode() {
    echo "Entering admin mode..."
    stop-kiosk
    
    # Open admin terminal
    DISPLAY=:0 xfce4-terminal --title="POS Admin Mode" --fullscreen &
    
    echo "Admin mode activated. Type 'exit-admin-mode' to return to kiosk."
}

exit-admin-mode() {
    echo "Exiting admin mode, returning to kiosk..."
    pkill xfce4-terminal 2>/dev/null || true
    sleep 1
    start-kiosk
}

# Update POS system
update-pos() {
    echo "Updating POS system..."
    # Source NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    cd "$POS_APP"
    git pull origin main
    npm install
    echo "POS system updated. Run 'restart-pos' to apply changes."
}

backup-pos() {
    local backup_dir="$HOME/pos-backup-$(date +%Y%m%d-%H%M%S)"
    echo "Creating POS backup at: $backup_dir"
    mkdir -p "$backup_dir"
    cp -r "$POS_CONFIG" "$backup_dir/" 2>/dev/null || true
    cp -r "$POS_LOGS" "$backup_dir/" 2>/dev/null || true
    cp "$POS_APP/.env" "$backup_dir/" 2>/dev/null || true
    echo "Backup created successfully."
}

# System information
pos-info() {
    echo "=== POS System Information ==="
    echo "System: $(uname -a)"
    
    # Source NVM for Node.js info
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    if command -v node >/dev/null 2>&1; then
        echo "Node.js: $(node --version)"
        echo "NPM: $(npm --version)"
        echo "NVM: $(nvm --version)"
    else
        echo "Node.js: Not found or NVM not sourced"
    fi
    
    echo "POS Home: $POS_HOME"
    echo "POS App: $POS_APP"
    echo "Config Dir: $POS_CONFIG"
    echo "Logs Dir: $POS_LOGS"
    echo "Uptime: $(uptime)"
    echo "Memory: $(free -h | grep Mem)"
    echo "Disk Usage: $(df -h / | tail -n1)"
    if command -v tailscale >/dev/null 2>&1; then
        echo "Tailscale: $(tailscale version)"
    fi
    status-pos
}

# Help function
pos-help() {
    echo "=== POS System Commands ==="
    echo "System Management:"
    echo "  start-pos           - Start the POS system"
    echo "  stop-pos            - Stop the POS system"
    echo "  restart-pos         - Restart the POS system"
    echo "  status-pos          - Check POS system status"
    echo "  logs-pos            - View POS system logs"
    echo "  update-pos          - Update POS system from GitHub"
    echo "  backup-pos          - Create system backup"
    echo ""
    echo "Configuration:"
    echo "  edit-env            - Edit environment configuration"
    echo "  generate-key        - Generate new crypto key"
    echo ""
    echo "Kiosk Mode:"
    echo "  start-kiosk         - Start Firefox kiosk mode"
    echo "  stop-kiosk          - Stop kiosk mode"
    echo "  restart-kiosk       - Restart kiosk mode"
    echo ""
    echo "Tailscale:"
    echo "  install-tailscale   - Install Tailscale"
    echo "  tailscale-up        - Start Tailscale connection"
    echo "  tailscale-status    - Show Tailscale status"
    echo "  tailscale-ip        - Show Tailscale IP"
    echo ""
    echo "User Management:"
    echo "  change-posuser-password    - Change posuser password"
    echo "  change-orangepi-password   - Change orangepi password"
    echo "  delete-orangepi-user       - Delete orangepi user"
    echo ""
    echo "Information:"
    echo "  pos-info            - Show system information"
    echo "  pos-help            - Show this help"
    echo ""
    echo "Hotkeys:"
    echo "  Alt+Ctrl+T          - Toggle between terminal and kiosk"
}

# Welcome message
echo "=== POS System Ready ==="
echo "Type 'pos-help' for available commands"
echo "System will start in kiosk mode on boot"
echo "Use Alt+Ctrl+T to toggle between terminal and kiosk mode"
EOF

# Create proper XFCE configuration BEFORE creating autostart files
log "Setting up proper XFCE environment..."

# Create minimal XFCE session configuration
mkdir -p /home/posuser/.config/xfce4/xfconf/xfce-perchannel-xml

# XFCE Session configuration (fixed)
cat > /home/posuser/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="general" type="empty">
    <property name="FailsafeSessionName" type="string" value="Failsafe"/>
    <property name="SessionName" type="string" value="Default"/>
    <property name="SaveOnExit" type="bool" value="false"/>
  </property>
  <property name="sessions" type="empty">
    <property name="Failsafe" type="empty">
      <property name="IsFailsafe" type="bool" value="true"/>
      <property name="Count" type="int" value="5"/>
      <property name="Client0_Command" type="array">
        <value type="string" value="xfwm4"/>
      </property>
      <property name="Client0_PerScreen" type="bool" value="false"/>
      <property name="Client1_Command" type="array">
        <value type="string" value="xfce4-panel"/>
      </property>
      <property name="Client1_PerScreen" type="bool" value="false"/>
      <property name="Client2_Command" type="array">
        <value type="string" value="xfdesktop"/>
      </property>
      <property name="Client2_PerScreen" type="bool" value="false"/>
      <property name="Client3_Command" type="array">
        <value type="string" value="xfce4-session"/>
      </property>
      <property name="Client3_PerScreen" type="bool" value="false"/>
      <property name="Client4_Command" type="array">
        <value type="string" value="Thunar"/>
        <value type="string" value="--daemon"/>
      </property>
      <property name="Client4_PerScreen" type="bool" value="false"/>
    </property>
  </property>
  <property name="startup" type="empty">
    <property name="screensaver" type="empty">
      <property name="enabled" type="bool" value="false"/>
    </property>
  </property>
</channel>
EOF

# Window Manager settings
cat > /home/posuser/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="workspace_count" type="int" value="1"/>
    <property name="borderless_maximize" type="bool" value="true"/>
    <property name="focus_mode" type="string" value="click"/>
    <property name="placement_mode" type="string" value="center"/>
  </property>
</channel>
EOF

# Desktop settings - minimal configuration
cat > /home/posuser/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value=""/>
        </property>
      </property>
    </property>
  </property>
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="0"/>
  </property>
  <property name="desktop-menu" type="empty">
    <property name="show" type="bool" value="false"/>
  </property>
</channel>
EOF

# Panel configuration (hidden by default for kiosk)
mkdir -p /home/posuser/.config/xfce4/panel
cat > /home/posuser/.config/xfce4/panel/panels.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<panels>
  <panel>
    <properties>
      <property name="autohide-behavior" type="uint" value="2"/>
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="size" type="uint" value="1"/>
      <property name="length" type="uint" value="1"/>
      <property name="background-style" type="uint" value="0"/>
      <property name="background-alpha" type="uint" value="0"/>
    </properties>
  </panel>
</panels>
EOF

# Create systemd service for POS auto-start (FIXED)
log "Creating POS systemd service..."
cat > /etc/systemd/system/pos-system.service << 'EOF'
[Unit]
Description=POS System Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=posuser
Group=posuser
WorkingDirectory=/home/posuser/pos-system/msnpos2
Environment="NVM_DIR=/home/posuser/.nvm"
Environment="PATH=/home/posuser/.nvm/versions/node/v18.20.4/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStartPre=/bin/bash -c 'source /home/posuser/.nvm/nvm.sh && nvm use 18'
ExecStart=/bin/bash -c 'source /home/posuser/.nvm/nvm.sh && node server.js'
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
KillMode=mixed
KillSignal=SIGINT
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

# Configure auto-login for posuser (FIXED)
log "Configuring console auto-login..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin posuser --noclear %I $TERM
Type=idle
EOF

# Configure LightDM for graphical auto-login (FIXED)
log "Configuring LightDM for graphical auto-login..."
cat > /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
autologin-user=posuser
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-gtk-greeter
greeter-hide-users=false
greeter-allow-guest=false
greeter-show-manual-login=true
greeter-show-remote-login=true
EOF

# Create a proper .xsessionrc for display configuration
cat > /home/posuser/.xsessionrc << 'EOF'
#!/bin/bash
# Disable screen blanking and power management
xset s off
xset -dpms
xset s noblank
xset s 0 0

# Start session bus
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval `dbus-launch --sh-syntax`
fi

# Ensure proper PATH
export PATH="$HOME/.nvm/versions/node/v18.20.4/bin:$PATH"

# Source NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
EOF

# Create XFCE autostart files (DELAYED start to prevent conflicts)
log "Creating XFCE autostart configuration..."
mkdir -p /home/posuser/.config/autostart

# POS System startup (delayed)
cat > /home/posuser/.config/autostart/pos-system.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=POS System
Exec=/bin/bash -c 'sleep 5 && source ~/.bashrc && source ~/.nvm/nvm.sh && start-pos'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
EOF

# Kiosk mode startup (more delayed to ensure POS is ready)
cat > /home/posuser/.config/autostart/pos-kiosk.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=POS Kiosk Mode
Exec=/bin/bash -c 'sleep 15 && source ~/.bashrc && start-kiosk'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
EOF

# Hotkeys startup
cat > /home/posuser/.config/autostart/xbindkeys.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=POS Hotkeys
Exec=xbindkeys
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
EOF

# Create hotkey script for terminal toggle
log "Creating hotkey script..."
mkdir -p /home/posuser/bin
cat > /home/posuser/bin/toggle-terminal.sh << 'EOF'
#!/bin/bash

# Admin mode toggle - Ctrl+Alt+T switches between kiosk and admin mode
if pgrep firefox > /dev/null; then
    # Currently in kiosk mode, enter admin mode
    source ~/.bashrc
    enter-admin-mode
else
    # Currently in admin mode, return to kiosk
    source ~/.bashrc
    exit-admin-mode
fi
EOF
chmod +x /home/posuser/bin/toggle-terminal.sh

# Install and configure hotkey daemon
log "Installing hotkey support..."
cat > /home/posuser/.xbindkeysrc << 'EOF'
# Admin mode toggle with Ctrl+Alt+T (for technicians only)
"bash /home/posuser/bin/toggle-terminal.sh"
    control+alt + t

# Disable other common shortcuts in kiosk mode
# Disable Alt+Tab
"echo 'Admin access required'"
    alt + Tab

# Disable Alt+F4
"echo 'Admin access required'"
    alt + F4

# Disable Ctrl+Alt+Del
"echo 'Admin access required'"
    control+alt + Delete
EOF

# Create proper .profile to ensure environment is loaded
log "Creating .profile for posuser..."
cat > /home/posuser/.profile << 'EOF'
# ~/.profile: executed by the command interpreter for login shells.

# Source .bashrc if it exists
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# Set PATH for user bin
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# Source NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
EOF

# Fix session handling by creating proper session script
log "Creating session startup script..."
cat > /home/posuser/.xprofile << 'EOF'
#!/bin/bash
# .xprofile - executed at the beginning of X session

# Start D-Bus user session if not already running
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
fi

# Source bashrc and profile
source ~/.profile
source ~/.bashrc 2>/dev/null || true

# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Set background to solid black
xsetroot -solid black 2>/dev/null || true

# Start essential services
xbindkeys &

# Log session start
echo "$(date): XFCE session started for posuser" >> ~/.xsession-errors
EOF
chmod +x /home/posuser/.xprofile

# Set proper permissions for all user files
log "Setting file permissions..."
chown -R posuser:posuser /home/posuser
chmod +x /home/posuser/.bashrc
chmod +x /home/posuser/.profile
chmod +x /home/posuser/.xprofile
chmod +x /home/posuser/.xsessionrc

# Create completion script
log "Creating bash completion..."
cat > /etc/bash_completion.d/pos-commands << 'EOF'
#!/bin/bash

_pos_commands() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    opts="start-pos stop-pos restart-pos status-pos logs-pos update-pos backup-pos
          edit-env generate-key start-kiosk stop-kiosk restart-kiosk
          install-tailscale tailscale-up tailscale-status tailscale-ip
          change-posuser-password change-orangepi-password delete-orangepi-user
          pos-info pos-help"
    
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
}

# Register completion for all POS commands
for cmd in start-pos stop-pos restart-pos status-pos logs-pos update-pos backup-pos edit-env generate-key start-kiosk stop-kiosk restart-kiosk install-tailscale tailscale-up tailscale-status tailscale-ip change-posuser-password change-orangepi-password delete-orangepi-user pos-info pos-help; do
    complete -F _pos_commands $cmd
done
EOF

# Enable services (FIXED ORDER)
log "Enabling systemd services..."
systemctl daemon-reload

# Ensure graphical target is default
systemctl set-default graphical.target

# Enable LightDM
systemctl enable lightdm.service

# Enable POS system service
systemctl enable pos-system.service

# Configure firewall (if UFW is installed)
if command -v ufw >/dev/null 2>&1; then
    log "Configuring firewall..."
    ufw allow 3000/tcp
    ufw allow ssh
fi

# Generate initial crypto key (FIXED)
log "Generating initial crypto key..."
sudo -u posuser bash -c '
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    cd /home/posuser/pos-system/msnpos2
    if command -v node >/dev/null 2>&1; then
        node -e "const CryptoJS = require(\"crypto-js\"); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());" > /home/posuser/pos-system/config/crypto.key 2>/dev/null || echo "Will generate key after first start"
    fi
' || warn "Crypto key will be generated on first start"

# Update .env with generated key if successful
if [ -f "/home/posuser/pos-system/config/crypto.key" ]; then
    CRYPTO_KEY=$(cat /home/posuser/pos-system/config/crypto.key)
    sed -i "s/ENCRYPTION_KEY=\$CRYPTO_KEY/ENCRYPTION_KEY=$CRYPTO_KEY/" /home/posuser/pos-system/msnpos2/.env
    log "Crypto key generated and configured"
fi

# Test posuser login capability
log "Testing posuser session setup..."
sudo -u posuser bash -c '
    export HOME=/home/posuser
    cd /home/posuser
    source .profile
    source .bashrc
    echo "User environment test completed"
' || warn "User environment may need manual verification"

# Create a desktop entry for easier testing
log "Creating desktop shortcut for testing..."
cat > /home/posuser/Desktop/POS-Admin.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=POS Admin Terminal
Exec=xfce4-terminal -e "bash -c 'source ~/.bashrc; pos-help; bash'"
Icon=utilities-terminal
Categories=System;
EOF
chmod +x /home/posuser/Desktop/POS-Admin.desktop
chown posuser:posuser /home/posuser/Desktop/POS-Admin.desktop

# Create setup completion marker
echo "$(date)" > /home/posuser/pos-system/config/.setup_complete
chown posuser:posuser /home/posuser/pos-system/config/.setup_complete

# Start POS system service now for testing
log "Starting POS system service for testing..."
systemctl start pos-system.service || warn "POS service failed to start - will retry on reboot"

# Create a manual session recovery script
log "Creating session recovery script..."
cat > /home/posuser/fix-session.sh << 'EOF'
#!/bin/bash
# Session recovery script - run if login fails

echo "Fixing XFCE session for posuser..."

# Ensure proper ownership
sudo chown -R posuser:posuser /home/posuser

# Restart display manager
sudo systemctl restart lightdm

echo "Session recovery attempted. Try logging in again."
EOF
chmod +x /home/posuser/fix-session.sh

# Final instructions
log "Setup completed successfully!"
echo ""
echo "==============================================="
echo "POS System Setup Complete (FIXED VERSION)!"
echo "==============================================="
echo ""
echo "User Accounts:"
echo "  - posuser / posuser123 (auto-login enabled)"
echo "  - orangepi user still exists (use 'delete-orangepi-user' to remove)"
echo ""
echo "FIXED ISSUES:"
echo "  - Proper XFCE session configuration"
echo "  - Fixed LightDM auto-login"
echo "  - Corrected systemd service dependencies"
echo "  - Added proper session startup scripts"
echo "  - Fixed permissions and environment loading"
echo ""
echo "Directory Structure:"
echo "  - POS Home: /home/posuser/pos-system/"
echo "  - POS App: /home/posuser/pos-system/msnpos2/"
echo "  - Config: /home/posuser/pos-system/config/"
echo "  - Logs: /home/posuser/pos-system/logs/"
echo "  - Environment: /home/posuser/pos-system/msnpos2/.env"
echo ""
echo "System will automatically:"
echo "  - Start POS system on boot"
echo "  - Launch in full kiosk mode (no desktop access)"
echo "  - Auto-login as posuser to graphical session"
echo "  - Hide all desktop elements and shortcuts"
echo ""
echo "Available commands (run 'pos-help' for full list):"
echo "  - start-pos, stop-pos, restart-pos"
echo "  - edit-env, generate-key" 
echo "  - enter-admin-mode, exit-admin-mode"
echo "  - install-tailscale, tailscale-up"
echo ""
echo "Hotkeys:"
echo "  - Ctrl+Alt+T: Admin mode for technicians only"
echo ""
echo "Troubleshooting:"
echo "  - If login fails, switch to tty (Ctrl+Alt+F2) and run:"
echo "    sudo /home/posuser/fix-session.sh"
echo "  - Check logs with: journalctl -u lightdm -f"
echo "  - Test session with: sudo -u posuser startxfce4"
echo ""
echo "Next steps:"
echo "1. Reboot the system: sudo reboot"
echo "2. System should auto-login to XFCE desktop"
echo "3. Kiosk mode should start automatically after 15 seconds"
echo "4. POS accessible at: http://localhost:3000 (automatic)"
echo "5. Technicians: Use Ctrl+Alt+T for admin access"
echo "6. Configure Tailscale: sudo tailscale up (in admin mode)"
echo ""
echo "Logs location: /home/posuser/pos-system/logs/"
echo "Config location: /home/posuser/pos-system/config/"
echo "Environment file: /home/posuser/pos-system/msnpos2/.env"
echo ""
echo "==============================================="

# Prompt for reboot
read -p "Setup complete. Reboot now to test the fixed configuration? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Rebooting system..."
    reboot
else
    log "Please reboot manually to test the fixed setup."
    echo ""
    echo "To test manually before reboot:"
    echo "  sudo systemctl restart lightdm"
    echo "  sudo -u posuser startxfce4  # (from VTY if needed)"
fi
