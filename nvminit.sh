#!/bin/bash

# POS System Setup Script for Ubuntu 22.04 (Focal)
# Designed for Orange Pi 3B with MSNPos2 integration
# Usage: curl -sSL https://raw.githubusercontent.com/Molesafenetwork/msnpos2/main/nvminit.sh | bash

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

log "Starting POS System Setup..."

# Update system
log "Updating system packages..."
apt update && apt upgrade -y

# Install required dependencies
log "Installing dependencies..."
apt install -y \
    curl \
    wget \
    git \
    firefox \
    xfce4 \
    xfce4-terminal \
    lightdm \
    lightdm-gtk-greeter \
    x11-xserver-utils \
    xorg \
    unclutter \
    sudo \
    pwgen \
    xinit \
    xserver-xorg \
    x11-session-utils \
    autojump \
    build-essential \
    libssl-dev \
    xbindkeys

# Install NVM (Node Version Manager)
log "Installing NVM..."
sudo -u posuser bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash'

# Source NVM and install Node.js 18
log "Installing Node.js 18 via NVM..."
sudo -u posuser bash -c 'source ~/.bashrc && source ~/.nvm/nvm.sh && nvm install 18 && nvm use 18 && nvm alias default 18'

# Install Tailscale
log "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

# Create posuser
log "Creating posuser..."
if id "posuser" &>/dev/null; then
    warn "User posuser already exists, skipping creation"
else
    useradd -m -s /bin/bash posuser
    echo "posuser:posuser123" | chpasswd
    usermod -aG sudo posuser
    log "Created posuser with password: posuser123"
fi

# Create POS directory structure
log "Setting up POS directory structure..."
POS_HOME="/home/posuser/pos"
mkdir -p "$POS_HOME"
mkdir -p "$POS_HOME/logs"
mkdir -p "$POS_HOME/config"

# Download MSNPos2
log "Downloading MSNPos2 from GitHub..."
cd "$POS_HOME"
if [ -d "msnpos2" ]; then
    rm -rf msnpos2
fi
git clone https://github.com/Molesafenetwork/msnpos2.git
cd msnpos2

# Install npm dependencies
log "Installing Node.js dependencies..."
sudo -u posuser bash -c 'source ~/.bashrc && source ~/.nvm/nvm.sh && cd '"$POS_HOME"'/msnpos2 && npm install && npm install crypto-js'

# Create environment file
log "Creating environment configuration..."
cat > "$POS_HOME/config/.env" << 'EOF'
# POS System Configuration
NODE_ENV=production
PORT=3000
POS_MODE=kiosk
AUTO_START=true
EOF

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
export POS_HOME="$HOME/pos"
export POS_CONFIG="$POS_HOME/config"
export POS_LOGS="$POS_HOME/logs"
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
    local env_file="$POS_CONFIG/.env"
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
        cd "$POS_HOME/msnpos2"
        local key
        key=$(node -e "const CryptoJS = require('crypto-js'); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());")
        echo "Generated Crypto Key: $key"
        echo "$key" > "$POS_CONFIG/crypto.key"
        echo "Key saved to $POS_CONFIG/crypto.key"
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
    
    cd "$POS_HOME/msnpos2"
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
        ls -la "$POS_LOGS/"
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
    
    cd "$POS_HOME/msnpos2"
    git pull origin main
    npm install
    echo "POS system updated. Run 'restart-pos' to apply changes."
}

backup-pos() {
    local backup_dir="$HOME/pos-backup-$(date +%Y%m%d-%H%M%S)"
    echo "Creating POS backup at: $backup_dir"
    mkdir -p "$backup_dir"
    cp -r "$POS_CONFIG" "$backup_dir/"
    cp -r "$POS_LOGS" "$backup_dir/"
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

# Create systemd service for POS auto-start
log "Creating POS systemd service..."
cat > /etc/systemd/system/pos-system.service << 'EOF'
[Unit]
Description=POS System Service
After=network.target

[Service]
Type=forking
User=posuser
WorkingDirectory=/home/posuser/pos/msnpos2
Environment=NVM_DIR=/home/posuser/.nvm
ExecStart=/bin/bash -c 'source ~/.bashrc && source ~/.nvm/nvm.sh && start-pos'
ExecStop=/bin/bash -c 'source ~/.bashrc && source ~/.nvm/nvm.sh && stop-pos'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create kiosk autostart service
log "Creating kiosk autostart service..."
cat > /etc/systemd/system/pos-kiosk.service << 'EOF'
[Unit]
Description=POS Kiosk Mode
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=posuser
Environment=DISPLAY=:0
ExecStartPre=/bin/sleep 10
ExecStart=/bin/bash -c 'source /home/posuser/.bashrc && start-kiosk'
ExecStop=/bin/bash -c 'source /home/posuser/.bashrc && stop-kiosk'
Restart=always
RestartSec=5

[Install]
WantedBy=graphical-session.target
EOF

# Configure auto-login for posuser
log "Configuring auto-login..."
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin posuser --noclear %I $TERM
EOF

# Configure LightDM for auto-login
log "Configuring LightDM for graphical auto-login..."
cat > /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
autologin-user=posuser
autologin-user-timeout=0
user-session=xfce
EOF

# Create XFCE autostart for posuser - KIOSK MODE ONLY
log "Creating XFCE autostart configuration for kiosk mode..."
mkdir -p /home/posuser/.config/autostart

# POS System startup
cat > /home/posuser/.config/autostart/pos-system.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=POS System
Exec=/bin/bash -c 'source ~/.bashrc && source ~/.nvm/nvm.sh && start-pos'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
EOF

# Kiosk mode startup (delayed to ensure POS is ready)
cat > /home/posuser/.config/autostart/pos-kiosk.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=POS Kiosk Mode
Exec=/bin/bash -c 'sleep 8 && source ~/.bashrc && start-kiosk'
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

# Create XFCE session configuration for kiosk mode
mkdir -p /home/posuser/.config/xfce4/xfconf/xfce-perchannel-xml
cat > /home/posuser/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="startup" type="empty">
    <property name="screensaver" type="empty">
      <property name="enabled" type="bool" value="false"/>
    </property>
  </property>
  <property name="general" type="empty">
    <property name="SaveOnExit" type="bool" value="false"/>
    <property name="SessionName" type="string" value="POS-Kiosk"/>
  </property>
  <property name="sessions" type="empty">
    <property name="Failsafe" type="empty">
      <property name="IsFailsafe" type="bool" value="true"/>
      <property name="Count" type="int" value="0"/>
    </property>
  </property>
</channel>
EOF

# Configure XFCE panel to be hidden by default (kiosk mode)
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

# Configure XFCE desktop to have no icons or right-click menu
mkdir -p /home/posuser/.config/xfce4/xfconf/xfce-perchannel-xml
cat > /home/posuser/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="0"/>
    <property name="use-custom-font-size" type="bool" value="false"/>
  </property>
  <property name="desktop-menu" type="empty">
    <property name="show" type="bool" value="false"/>
  </property>
</channel>
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

# Add xbindkeys to XFCE autostart
cat > /home/posuser/.config/autostart/xbindkeys.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Hotkeys
Exec=xbindkeys
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# Set proper permissions
log "Setting file permissions..."
chown -R posuser:posuser /home/posuser
chmod +x /home/posuser/.bashrc

# Enable services
log "Enabling systemd services..."
systemctl daemon-reload
systemctl enable pos-system.service
systemctl enable pos-kiosk.service

# Configure firewall (if UFW is installed)
if command -v ufw >/dev/null 2>&1; then
    log "Configuring firewall..."
    ufw allow 3000/tcp
    ufw allow ssh
fi

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

# Final system configuration
log "Performing final system configuration..."

# Disable screen blanking and configure XFCE for kiosk mode
cat > /home/posuser/.xsessionrc << 'EOF'
# Disable screen blanking and power management
xset s off
xset -dpms
xset s noblank

# Disable screensaver
xset s 0 0

# Start xbindkeys for admin hotkey
xbindkeys &

# Hide cursor initially (will be managed by kiosk mode)
unclutter -idle 1 -root &

# Set kiosk-friendly window manager settings
export XFCE_PANEL_MIGRATE_DEFAULT=1
EOF

# Generate initial crypto key
log "Generating initial crypto key..."
sudo -u posuser bash -c 'source ~/.bashrc && source ~/.nvm/nvm.sh && generate-key'

# Start services
log "Starting POS system..."
systemctl start pos-system.service

# Create setup completion marker
echo "$(date)" > /home/posuser/pos/config/.setup_complete

# Final instructions
log "Setup completed successfully!"
echo ""
echo "==============================================="
echo "POS System Setup Complete!"
echo "==============================================="
echo ""
echo "User Accounts:"
echo "  - posuser / posuser123 (auto-login enabled)"
echo "  - orangepi user still exists (use 'delete-orangepi-user' to remove)"
echo ""
echo "System will automatically:"
echo "  - Start POS system on boot"
echo "  - Launch in full kiosk mode (no desktop access)"
echo "  - Auto-login as posuser"
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
echo "Next steps:"
echo "1. Reboot the system: sudo reboot"
echo "2. System will auto-login and start in KIOSK MODE"
echo "3. POS accessible at: http://localhost:3000 (automatic)"
echo "4. Technicians: Use Ctrl+Alt+T for admin access"
echo "5. Configure Tailscale: sudo tailscale up (in admin mode)"
echo ""
echo "Logs location: /home/posuser/pos/logs/"
echo "Config location: /home/posuser/pos/config/"
echo ""
echo "==============================================="

# Prompt for reboot
read -p "Setup complete. Reboot now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Rebooting system..."
    reboot
else
    log "Please reboot manually to complete setup."
fi
