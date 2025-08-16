#!/bin/bash

# Hotkey and PDF Viewer Fixes for POS System
# Run this script to fix hotkey issues and add PDF invoice viewer
# Usage: sudo bash hotkeyfixes.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
fi

log "Fixing hotkeys and adding PDF invoice viewer..."

# Install additional packages needed for PDF handling and better hotkey support
log "Installing PDF and hotkey support packages..."
apt update
apt install -y \
    evince \
    thunar \
    thunar-archive-plugin \
    thunar-media-tags-plugin \
    xdotool \
    wmctrl \
    cups \
    cups-pdf \
    printer-driver-all \
    system-config-printer \
    at-spi2-core \
    gvfs \
    gvfs-backends \
    xfce4-notifyd

# Create enhanced hotkey script that works better with kiosk mode
log "Creating enhanced hotkey scripts..."
mkdir -p /home/posuser/bin

# Enhanced admin toggle script that uses xdotool for better window management
cat > /home/posuser/bin/toggle-terminal.sh << 'EOF'
#!/bin/bash

# Enhanced admin mode toggle that works with kiosk Firefox
export DISPLAY=:0

# Function to check if Firefox is in kiosk mode
is_kiosk_active() {
    if pgrep -f "firefox.*--kiosk" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check if admin terminal is open
is_admin_active() {
    if wmctrl -l | grep -q "POS Admin Mode"; then
        return 0
    else
        return 1
    fi
}

if is_kiosk_active && ! is_admin_active; then
    # Currently in kiosk mode, enter admin mode
    echo "$(date): Entering admin mode" >> ~/.hotkey.log
    
    # Kill Firefox kiosk
    pkill -f "firefox.*--kiosk" || true
    pkill unclutter || true
    
    # Show XFCE panel
    xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -s 0 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/size -s 28 2>/dev/null || true
    
    # Wait a moment for Firefox to close
    sleep 1
    
    # Open fullscreen admin terminal
    xfce4-terminal \
        --title="POS Admin Mode - Press Ctrl+Alt+T to return to kiosk" \
        --fullscreen \
        --command="bash -c 'source ~/.bashrc; echo \"=== POS ADMIN MODE ===\"; echo \"Type pos-help for commands\"; echo \"Press Ctrl+Alt+T to return to kiosk mode\"; echo; bash'" &
    
elif is_admin_active; then
    # Currently in admin mode, return to kiosk
    echo "$(date): Returning to kiosk mode" >> ~/.hotkey.log
    
    # Close admin terminal
    wmctrl -c "POS Admin Mode" || pkill xfce4-terminal || true
    
    # Hide panel
    xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -s 2 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/size -s 1 2>/dev/null || true
    
    # Wait for terminal to close
    sleep 1
    
    # Start Firefox kiosk mode
    source ~/.bashrc
    firefox --kiosk --new-instance --no-remote "http://localhost:3000" &
    
    # Hide cursor
    unclutter -idle 1 -root &
    
else
    # Fallback: just toggle whatever is running
    echo "$(date): Fallback toggle" >> ~/.hotkey.log
    if pgrep firefox > /dev/null; then
        pkill firefox
        xfce4-terminal --fullscreen --title="POS Admin Mode" &
    else
        pkill xfce4-terminal || true
        source ~/.bashrc
        firefox --kiosk --new-instance --no-remote "http://localhost:3000" &
        unclutter -idle 1 -root &
    fi
fi
EOF

# PDF invoice viewer script
cat > /home/posuser/bin/view-latest-invoice.sh << 'EOF'
#!/bin/bash

# View latest downloaded PDF (client invoice)
export DISPLAY=:0

log_action() {
    echo "$(date): $1" >> ~/.invoice-viewer.log
}

log_action "Invoice viewer hotkey triggered"

# Common download locations to search
DOWNLOAD_DIRS=(
    "$HOME/Downloads"
    "$HOME/Desktop"
    "/tmp"
    "$HOME/pos-system/invoices"
    "$HOME/Documents"
)

# Create invoices directory if it doesn't exist
mkdir -p "$HOME/pos-system/invoices"

# Function to find the most recent PDF
find_latest_pdf() {
    local latest_pdf=""
    local latest_time=0
    
    for dir in "${DOWNLOAD_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            # Find PDFs modified in the last 24 hours, sorted by modification time
            while IFS= read -r -d '' file; do
                if [ -f "$file" ]; then
                    file_time=$(stat -c %Y "$file" 2>/dev/null || echo 0)
                    if [ "$file_time" -gt "$latest_time" ]; then
                        latest_time=$file_time
                        latest_pdf="$file"
                    fi
                fi
            done < <(find "$dir" -maxdepth 2 -name "*.pdf" -type f -mtime -1 -print0 2>/dev/null)
        fi
    done
    
    echo "$latest_pdf"
}

# Find the latest PDF
LATEST_PDF=$(find_latest_pdf)

if [ -z "$LATEST_PDF" ] || [ ! -f "$LATEST_PDF" ]; then
    log_action "No recent PDF found, opening file manager"
    
    # No recent PDF found, open file manager to Downloads
    thunar "$HOME/Downloads" &
    THUNAR_PID=$!
    
    # Bring file manager to front
    sleep 1
    wmctrl -a "thunar" || true
    
else
    log_action "Opening PDF: $LATEST_PDF"
    
    # Open the PDF with evince (document viewer)
    evince "$LATEST_PDF" &
    EVINCE_PID=$!
    
    # Bring PDF viewer to front
    sleep 1
    wmctrl -a "evince" || wmctrl -a "Document Viewer" || true
fi

# Function to monitor for window close and return to kiosk
monitor_viewer() {
    # Wait for either evince or thunar to close
    if [ -n "${EVINCE_PID:-}" ]; then
        while kill -0 $EVINCE_PID 2>/dev/null; do
            sleep 1
        done
    elif [ -n "${THUNAR_PID:-}" ]; then
        while kill -0 $THUNAR_PID 2>/dev/null; do
            sleep 1
        done
    fi
    
    log_action "Viewer closed, ensuring kiosk mode"
    
    # Make sure we return to kiosk mode
    if ! pgrep -f "firefox.*--kiosk" > /dev/null; then
        source ~/.bashrc
        sleep 1
        firefox --kiosk --new-instance --no-remote "http://localhost:3000" &
        unclutter -idle 1 -root &
    fi
}

# Start background monitoring
monitor_viewer &
EOF

# PDF printing helper script
cat > /home/posuser/bin/quick-print-pdf.sh << 'EOF'
#!/bin/bash

# Quick print the currently viewed PDF
export DISPLAY=:0

# Get the active window
ACTIVE_WINDOW=$(xdotool getactivewindow)
WINDOW_NAME=$(xdotool getwindowname $ACTIVE_WINDOW)

echo "$(date): Quick print requested for: $WINDOW_NAME" >> ~/.print.log

# If it's evince (document viewer), send print command
if echo "$WINDOW_NAME" | grep -qi "evince\|document viewer"; then
    # Send Ctrl+P to print
    xdotool key --window $ACTIVE_WINDOW ctrl+p
elif echo "$WINDOW_NAME" | grep -qi "thunar"; then
    # If it's file manager, try to print selected file
    xdotool key --window $ACTIVE_WINDOW F2  # Rename/Properties
else
    # Fallback - try generic print command
    xdotool key --window $ACTIVE_WINDOW ctrl+p
fi
EOF

# Make all scripts executable
chmod +x /home/posuser/bin/toggle-terminal.sh
chmod +x /home/posuser/bin/view-latest-invoice.sh
chmod +x /home/posuser/bin/quick-print-pdf.sh

# Create enhanced xbindkeys configuration with better hotkey handling
log "Creating enhanced hotkey configuration..."
cat > /home/posuser/.xbindkeysrc << 'EOF'
# Enhanced POS System Hotkeys Configuration

# Admin mode toggle with Ctrl+Alt+T (works even in kiosk mode)
"bash /home/posuser/bin/toggle-terminal.sh"
    control+alt + t

# View latest PDF invoice with Alt+KP_0 (Alt + Numpad 0)
"bash /home/posuser/bin/view-latest-invoice.sh"
    alt + KP_0

# Alternative: Alt+0 (regular number key)
"bash /home/posuser/bin/view-latest-invoice.sh"
    alt + 0

# Quick print PDF with Ctrl+Alt+P
"bash /home/posuser/bin/quick-print-pdf.sh"
    control+alt + p

# Emergency escape from kiosk with Ctrl+Alt+E (technician emergency access)
"pkill firefox; xfce4-terminal --fullscreen --title='Emergency Admin Mode' &"
    control+alt + e

# Hide/show cursor with Ctrl+Alt+H
"pkill unclutter; unclutter -idle 1 -root &"
    control+alt + h

# Reload hotkeys with Ctrl+Alt+R
"killall xbindkeys; xbindkeys &"
    control+alt + r

# Disable problematic shortcuts in kiosk mode
"echo 'Disabled in kiosk mode'"
    alt + Tab

"echo 'Disabled in kiosk mode'"
    alt + F4

"echo 'Disabled in kiosk mode'" 
    control+alt + Delete

"echo 'Disabled in kiosk mode'"
    control + w

"echo 'Disabled in kiosk mode'"
    control + q

"echo 'Disabled in kiosk mode'"
    F11
EOF

# Add PDF handling functions to .bashrc
log "Adding PDF handling functions to .bashrc..."
cat >> /home/posuser/.bashrc << 'EOF'

# =============================================================================
# PDF INVOICE HANDLING FUNCTIONS
# =============================================================================

# View latest downloaded PDF invoice
view-invoice() {
    bash /home/posuser/bin/view-latest-invoice.sh
}

# Print current PDF
print-pdf() {
    bash /home/posuser/bin/quick-print-pdf.sh
}

# Open invoice directory
open-invoices() {
    export DISPLAY=:0
    thunar "$HOME/pos-system/invoices" &
}

# List recent PDFs
list-invoices() {
    echo "Recent PDF files (last 24 hours):"
    echo "================================="
    
    local dirs=("$HOME/Downloads" "$HOME/Desktop" "$HOME/pos-system/invoices" "$HOME/Documents")
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo ""
            echo "In $dir:"
            find "$dir" -name "*.pdf" -type f -mtime -1 -printf "%T@ %Tc %p\n" 2>/dev/null | sort -nr | head -5 | cut -d' ' -f2-
        fi
    done
}

# Enhanced kiosk mode that properly captures hotkeys
start-kiosk() {
    echo "Starting Firefox in enhanced kiosk mode..."
    export DISPLAY=:0
    
    # Kill any existing Firefox instances
    pkill firefox 2>/dev/null || true
    pkill unclutter 2>/dev/null || true
    sleep 2
    
    # Hide XFCE panel completely in kiosk mode
    xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -s 2 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/size -s 1 2>/dev/null || true
    
    # Ensure hotkeys are running
    killall xbindkeys 2>/dev/null || true
    sleep 1
    xbindkeys &
    
    # Start Firefox in kiosk mode with specific window class for better control
    firefox \
        --kiosk \
        --new-instance \
        --no-remote \
        --class="POSKiosk" \
        "http://localhost:3000" &
    
    # Wait for Firefox to start
    sleep 3
    
    # Hide cursor after inactivity
    unclutter -idle 1 -root &
    
    # Use wmctrl to ensure Firefox is truly fullscreen
    sleep 2
    wmctrl -r "POSKiosk" -b add,fullscreen 2>/dev/null || true
    
    echo "Enhanced kiosk mode started with hotkey support"
    echo "Hotkeys available:"
    echo "  Ctrl+Alt+T - Admin mode toggle"
    echo "  Alt+0 or Alt+Numpad0 - View latest invoice"
    echo "  Ctrl+Alt+P - Quick print"
    echo "  Ctrl+Alt+E - Emergency admin access"
}

# Test hotkeys function
test-hotkeys() {
    echo "Testing hotkey system..."
    echo "Current xbindkeys process:"
    pgrep -fl xbindkeys || echo "xbindkeys not running"
    
    echo ""
    echo "Hotkey configuration:"
    if [ -f ~/.xbindkeysrc ]; then
        echo "Configuration file exists"
        grep -c "bash" ~/.xbindkeysrc && echo "Custom commands configured"
    else
        echo "No hotkey configuration found!"
    fi
    
    echo ""
    echo "Testing hotkey scripts:"
    for script in toggle-terminal.sh view-latest-invoice.sh quick-print-pdf.sh; do
        if [ -x "$HOME/bin/$script" ]; then
            echo "✓ $script is executable"
        else
            echo "✗ $script missing or not executable"
        fi
    done
    
    echo ""
    echo "Restarting xbindkeys..."
    killall xbindkeys 2>/dev/null || true
    sleep 1
    xbindkeys &
    echo "Hotkeys reloaded"
}

# Add to help
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
    echo "  start-kiosk         - Start Firefox kiosk mode (enhanced)"
    echo "  stop-kiosk          - Stop kiosk mode"
    echo "  restart-kiosk       - Restart kiosk mode"
    echo ""
    echo "PDF Invoice Handling:"
    echo "  view-invoice        - View latest downloaded PDF"
    echo "  print-pdf           - Print current PDF"
    echo "  open-invoices       - Open invoices folder"
    echo "  list-invoices       - List recent PDF files"
    echo ""
    echo "Hotkey Management:"
    echo "  test-hotkeys        - Test and reload hotkey system"
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
    echo "Enhanced Hotkeys (work in kiosk mode):"
    echo "  Ctrl+Alt+T          - Toggle admin mode"
    echo "  Alt+0 or Alt+Num0   - View latest PDF invoice"
    echo "  Ctrl+Alt+P          - Quick print current document"
    echo "  Ctrl+Alt+E          - Emergency admin access"
    echo "  Ctrl+Alt+R          - Reload hotkeys"
    echo "  Ctrl+Alt+H          - Toggle cursor visibility"
}
EOF

# Create desktop file for invoice viewer
log "Creating desktop integration for PDF handling..."
cat > /home/posuser/.local/share/applications/pos-invoice-viewer.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=POS Invoice Viewer
Comment=View latest client invoice PDF
Exec=/home/posuser/bin/view-latest-invoice.sh
Icon=document-viewer
Categories=Office;Viewer;
NoDisplay=false
EOF

# Update the kiosk autostart to use enhanced version
cat > /home/posuser/.config/autostart/pos-kiosk.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=POS Enhanced Kiosk Mode
Exec=/bin/bash -c 'sleep 15 && source ~/.bashrc && start-kiosk'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
EOF

# Restart xbindkeys autostart to ensure it loads after XFCE
cat > /home/posuser/.config/autostart/xbindkeys.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=POS Enhanced Hotkeys
Exec=/bin/bash -c 'sleep 5 && killall xbindkeys 2>/dev/null || true; sleep 1; xbindkeys'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
EOF

# Create a hotkey test desktop file for easy access
cat > /home/posuser/Desktop/Test-Hotkeys.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Test POS Hotkeys
Exec=xfce4-terminal -e "bash -c 'source ~/.bashrc; test-hotkeys; echo; echo Press Enter to close; read'"
Icon=preferences-desktop-keyboard
Categories=System;Settings;
EOF
chmod +x /home/posuser/Desktop/Test-Hotkeys.desktop

# Set proper ownership
chown -R posuser:posuser /home/posuser/bin
chown -R posuser:posuser /home/posuser/.local
chown -R posuser:posuser /home/posuser/.config
chown posuser:posuser /home/posuser/.xbindkeysrc
chown posuser:posuser /home/posuser/Desktop/Test-Hotkeys.desktop

# Restart xbindkeys if it's running
log "Restarting hotkey daemon..."
sudo -u posuser bash -c 'killall xbindkeys 2>/dev/null || true; sleep 2; DISPLAY=:0 xbindkeys &' || true

log "Hotkey and PDF viewer fixes completed!"
echo ""
echo "==============================================="
echo "HOTKEY AND PDF VIEWER FIXES APPLIED!"
echo "==============================================="
echo ""
echo "NEW FUNCTIONALITY:"
echo "==================="
echo ""
echo "Enhanced Hotkeys (work even in Firefox kiosk mode):"
echo "  Ctrl+Alt+T          - Toggle between kiosk and admin mode"
echo "  Alt+0 or Alt+Num0   - View latest downloaded PDF invoice"  
echo "  Ctrl+Alt+P          - Quick print current document"
echo "  Ctrl+Alt+E          - Emergency admin access"
echo "  Ctrl+Alt+R          - Reload hotkey system"
echo "  Ctrl+Alt+H          - Toggle cursor hide/show"
echo ""
echo "PDF Invoice Features:"
echo "  - Automatically finds most recent PDF in Downloads"
echo "  - Opens with document viewer (evince) with print support"
echo "  - File manager fallback if no recent PDF found"
echo "  - Overlay mode - PDF viewer stays on top of kiosk"
echo "  - Auto-returns to kiosk when PDF viewer is closed"
echo "  - Print button available in document viewer"
echo ""
echo "New Commands Available:"
echo "  view-invoice        - View latest PDF"
echo "  print-pdf          - Print current document"  
echo "  open-invoices      - Open invoice folder"
echo "  list-invoices      - Show recent PDFs"
echo "  test-hotkeys       - Test hotkey system"
echo ""
echo "TESTING:"
echo "========="
echo "1. Test admin toggle: Press Ctrl+Alt+T"
echo "2. Test PDF viewer: Download a PDF, then press Alt+0"
echo "3. Test emergency access: Press Ctrl+Alt+E"
echo "4. Run 'test-hotkeys' command to verify setup"
echo ""
echo "TROUBLESHOOTING:"
echo "================"
echo "- If hotkeys don't work, run: test-hotkeys"
echo "- Check logs in ~/.hotkey.log and ~/.invoice-viewer.log"
echo "- Desktop shortcut available: Test-Hotkeys"
echo ""
echo "The system is now ready with enhanced hotkey support!"
echo "No reboot required - hotkeys active immediately."
echo "==============================================="
