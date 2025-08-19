#!/bin/bash

# Smart Hotkey and PDF Management Fixes for POS System
# Fixes: PDF inline display, multiple process spawning, smart toggles
# Usage: sudo curl -fsSL https://github.com/Molesafenetwork/nvminit.sh | sudo bash

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

log "Applying smart hotkey and PDF management fixes..."

# Create Firefox preferences to prevent inline PDF display
log "Configuring Firefox to prevent inline PDF display..."
mkdir -p /home/posuser/.mozilla/firefox
FIREFOX_PROFILE_DIR=""

# Find or create Firefox profile
if [ -f /home/posuser/.mozilla/firefox/profiles.ini ]; then
    FIREFOX_PROFILE_DIR=$(grep -E "^Path=" /home/posuser/.mozilla/firefox/profiles.ini | head -1 | cut -d'=' -f2)
    if [ -n "$FIREFOX_PROFILE_DIR" ]; then
        FIREFOX_PROFILE_DIR="/home/posuser/.mozilla/firefox/$FIREFOX_PROFILE_DIR"
    fi
fi

# Create default profile if none exists
if [ -z "$FIREFOX_PROFILE_DIR" ] || [ ! -d "$FIREFOX_PROFILE_DIR" ]; then
    log "Creating Firefox profile..."
    FIREFOX_PROFILE_DIR="/home/posuser/.mozilla/firefox/pos-profile"
    mkdir -p "$FIREFOX_PROFILE_DIR"
    
    cat > /home/posuser/.mozilla/firefox/profiles.ini << 'EOF'
[Profile0]
Name=POS Profile
IsRelative=1
Path=pos-profile
Default=1

[General]
StartWithLastProfile=1
EOF
fi

# Create user.js to configure Firefox behavior
cat > "$FIREFOX_PROFILE_DIR/user.js" << 'EOF'
// POS System Firefox Configuration
// Prevent PDFs from opening inline - force download instead

// Force PDF downloads instead of inline display
user_pref("browser.download.panel.shown", false);
user_pref("pdfjs.disabled", true);
user_pref("plugin.disable_full_page_plugin_for_types", "application/pdf");

// Download behavior
user_pref("browser.download.useDownloadDir", true);
user_pref("browser.download.folderList", 1);
user_pref("browser.download.manager.showWhenStarting", false);
user_pref("browser.download.manager.showAlertOnComplete", false);

// Disable various popups and prompts
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.rights.3.shown", true);

// Kiosk mode optimizations
user_pref("full-screen-api.enabled", true);
user_pref("browser.fullscreen.autohide", true);
user_pref("dom.disable_open_during_load", false);

// Security settings for kiosk
user_pref("browser.contentblocking.introCount", 20);
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
EOF

# Create enhanced smart toggle admin script
log "Creating smart admin toggle script..."
cat > /home/posuser/bin/toggle-terminal.sh << 'EOF'
#!/bin/bash

# Smart admin mode toggle - ensures only one mode at a time
export DISPLAY=:0

LOG_FILE="$HOME/.admin-toggle.log"

log_action() {
    echo "$(date): $1" >> "$LOG_FILE"
}

# Function to kill all admin terminals
kill_admin_terminals() {
    # Kill by window title
    wmctrl -c "POS Admin Mode" 2>/dev/null || true
    wmctrl -c "Emergency Admin Mode" 2>/dev/null || true
    
    # Kill xfce4-terminal processes (but not the main one if it's the only terminal)
    pkill -f "xfce4-terminal.*Admin" 2>/dev/null || true
    
    # More aggressive cleanup if needed
    local admin_pids=$(pgrep -f "POS Admin Mode\|Emergency Admin Mode" 2>/dev/null || true)
    if [ -n "$admin_pids" ]; then
        echo "$admin_pids" | xargs -r kill -TERM 2>/dev/null || true
        sleep 1
        echo "$admin_pids" | xargs -r kill -KILL 2>/dev/null || true
    fi
}

# Function to kill Firefox kiosk
kill_firefox_kiosk() {
    pkill -f "firefox.*--kiosk" 2>/dev/null || true
    pkill -f "firefox.*POSKiosk" 2>/dev/null || true
    pkill firefox 2>/dev/null || true
    pkill unclutter 2>/dev/null || true
}

# Function to start kiosk mode
start_kiosk_mode() {
    log_action "Starting kiosk mode"
    
    # Hide panel
    xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -s 2 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/size -s 1 2>/dev/null || true
    
    # Wait for cleanup
    sleep 2
    
    # Start Firefox kiosk with PDF handling
    firefox \
        --kiosk \
        --new-instance \
        --no-remote \
        --class="POSKiosk" \
        --profile="/home/posuser/.mozilla/firefox/pos-profile" \
        "http://localhost:3000" &
    
    # Wait for Firefox to start
    sleep 3
    
    # Hide cursor
    unclutter -idle 1 -root &
    
    # Ensure Firefox is fullscreen
    wmctrl -r "POSKiosk" -b add,fullscreen 2>/dev/null || true
}

# Function to start admin mode
start_admin_mode() {
    log_action "Starting admin mode"
    
    # Show panel
    xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -s 0 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/size -s 28 2>/dev/null || true
    
    # Wait a moment
    sleep 1
    
    # Start single admin terminal
    xfce4-terminal \
        --title="POS Admin Mode - Press Ctrl+Alt+T to return to kiosk" \
        --fullscreen \
        --command="bash -c 'source ~/.bashrc; echo \"=== POS ADMIN MODE ===\"; echo \"Commands: pos-help | view-invoice | test-hotkeys\"; echo \"Toggle back: Ctrl+Alt+T\"; echo; bash'" &
}

# Check current state and toggle
if pgrep -f "firefox.*--kiosk" > /dev/null; then
    # Currently in kiosk mode - switch to admin
    log_action "Switching from kiosk to admin mode"
    
    kill_firefox_kiosk
    sleep 2
    start_admin_mode
    
elif wmctrl -l | grep -q "POS Admin Mode\|Emergency Admin Mode"; then
    # Currently in admin mode - switch to kiosk
    log_action "Switching from admin to kiosk mode"
    
    kill_admin_terminals
    sleep 1
    start_kiosk_mode
    
else
    # Unknown state - default to kiosk
    log_action "Unknown state - defaulting to kiosk mode"
    
    kill_admin_terminals
    kill_firefox_kiosk
    sleep 2
    start_kiosk_mode
fi
EOF

# Create smart PDF toggle script
cat > /home/posuser/bin/view-latest-invoice.sh << 'EOF'
#!/bin/bash

# Smart PDF invoice viewer - toggles between PDF view and kiosk
export DISPLAY=:0

LOG_FILE="$HOME/.pdf-toggle.log"
STATE_FILE="$HOME/.pdf-viewer-state"

log_action() {
    echo "$(date): $1" >> "$LOG_FILE"
}

# Function to kill all PDF viewers and file managers
kill_pdf_viewers() {
    # Kill evince (document viewer)
    pkill evince 2>/dev/null || true
    wmctrl -c "Document Viewer" 2>/dev/null || true
    wmctrl -c "evince" 2>/dev/null || true
    
    # Kill thunar (file manager) - but only ones we opened
    local thunar_pids=$(pgrep -f "thunar.*Downloads\|thunar.*invoices" 2>/dev/null || true)
    if [ -n "$thunar_pids" ]; then
        echo "$thunar_pids" | xargs -r kill -TERM 2>/dev/null || true
    fi
    
    # Wait for cleanup
    sleep 1
}

# Function to check if Firefox is showing a PDF instead of POS system
is_firefox_showing_pdf() {
    # Check if Firefox window title suggests it's showing a PDF
    local firefox_title=$(wmctrl -l | grep -i firefox | head -1 | cut -d' ' -f5- || echo "")
    if echo "$firefox_title" | grep -qi "\.pdf\|document"; then
        return 0
    else
        return 1
    fi
}

# Function to refresh Firefox back to POS system
refresh_firefox_to_pos() {
    log_action "Refreshing Firefox back to POS system"
    
    # Get Firefox window and send navigation commands
    local firefox_window=$(wmctrl -l | grep -i firefox | head -1 | awk '{print $1}')
    
    if [ -n "$firefox_window" ]; then
        # Focus Firefox window
        wmctrl -i -a "$firefox_window"
        sleep 1
        
        # Navigate back to POS system
        xdotool key --window "$firefox_window" ctrl+l
        sleep 0.5
        xdotool type --window "$firefox_window" "http://localhost:3000"
        sleep 0.5
        xdotool key --window "$firefox_window" Return
        
        # Ensure fullscreen
        sleep 2
        xdotool key --window "$firefox_window" F11 F11  # Double F11 to ensure fullscreen
    fi
}

# Function to find the most recent PDF
find_latest_pdf() {
    local latest_pdf=""
    local latest_time=0
    
    local dirs=("$HOME/Downloads" "$HOME/Desktop" "$HOME/pos-system/invoices" "$HOME/Documents")
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r -d '' file; do
                if [ -f "$file" ]; then
                    local file_time=$(stat -c %Y "$file" 2>/dev/null || echo 0)
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

# Function to open PDF viewer
open_pdf_viewer() {
    local pdf_file="$1"
    
    if [ -n "$pdf_file" ] && [ -f "$pdf_file" ]; then
        log_action "Opening PDF: $pdf_file"
        
        # Open PDF with evince
        evince "$pdf_file" &
        
        # Store state
        echo "pdf_open" > "$STATE_FILE"
        echo "$pdf_file" >> "$STATE_FILE"
        
        # Wait and bring to front
        sleep 2
        wmctrl -a "evince" || wmctrl -a "Document Viewer" || true
        
    else
        log_action "No PDF found, opening file manager"
        
        # Kill any existing file managers we opened
        kill_pdf_viewers
        
        # Open Downloads folder
        thunar "$HOME/Downloads" &
        
        # Store state
        echo "file_manager_open" > "$STATE_FILE"
        
        # Wait and bring to front
        sleep 1
        wmctrl -a "thunar" || true
    fi
}

# Main logic - smart toggle
log_action "PDF toggle hotkey activated"

# Check if Firefox is showing a PDF instead of POS
if is_firefox_showing_pdf; then
    log_action "Firefox showing PDF - returning to POS system"
    refresh_firefox_to_pos
    rm -f "$STATE_FILE"
    exit 0
fi

# Check current state
if [ -f "$STATE_FILE" ]; then
    local current_state=$(head -1 "$STATE_FILE" 2>/dev/null || echo "")
    
    case "$current_state" in
        "pdf_open")
            # PDF is open - close it and return to kiosk
            log_action "Closing PDF viewer"
            kill_pdf_viewers
            rm -f "$STATE_FILE"
            
            # Make sure we're back in kiosk mode
            if ! pgrep -f "firefox.*--kiosk" > /dev/null; then
                source ~/.bashrc
                start-kiosk
            fi
            ;;
            
        "file_manager_open")
            # File manager is open - close it
            log_action "Closing file manager"
            kill_pdf_viewers  
            rm -f "$STATE_FILE"
            ;;
            
        *)
            # Unknown state - open PDF viewer
            rm -f "$STATE_FILE"
            local latest_pdf=$(find_latest_pdf)
            open_pdf_viewer "$latest_pdf"
            ;;
    esac
    
else
    # No state file - open PDF viewer
    local latest_pdf=$(find_latest_pdf)
    open_pdf_viewer "$latest_pdf"
fi
EOF

# Create process cleanup utility
cat > /home/posuser/bin/cleanup-processes.sh << 'EOF'
#!/bin/bash

# Process cleanup utility to prevent resource waste
export DISPLAY=:0

log_action() {
    echo "$(date): $1" >> "$HOME/.process-cleanup.log"
}

log_action "Running process cleanup"

# Kill duplicate Firefox instances (keep only kiosk)
firefox_count=$(pgrep firefox | wc -l)
if [ "$firefox_count" -gt 1 ]; then
    log_action "Found $firefox_count Firefox processes, cleaning up"
    
    # Kill non-kiosk Firefox instances first
    pkill -f "firefox" -v -f "--kiosk" 2>/dev/null || true
    sleep 2
    
    # If still multiple, kill all and restart kiosk
    firefox_count=$(pgrep firefox | wc -l)
    if [ "$firefox_count" -gt 1 ]; then
        pkill firefox 2>/dev/null || true
        sleep 3
        source ~/.bashrc
        start-kiosk &
    fi
fi

# Kill duplicate terminals (keep max 1 admin terminal)
admin_terminal_count=$(pgrep -f "POS Admin Mode\|Emergency Admin Mode" | wc -l)
if [ "$admin_terminal_count" -gt 1 ]; then
    log_action "Found $admin_terminal_count admin terminals, keeping only 1"
    
    # Get PIDs and kill all but the first one
    local pids=($(pgrep -f "POS Admin Mode\|Emergency Admin Mode"))
    for ((i=1; i<${#pids[@]}; i++)); do
        kill "${pids[i]}" 2>/dev/null || true
    done
fi

# Kill duplicate thunar instances
thunar_count=$(pgrep thunar | wc -l)
if [ "$thunar_count" -gt 2 ]; then
    log_action "Found $thunar_count thunar processes, cleaning up"
    
    # Keep only the most recent 2 thunar processes
    local pids=($(pgrep thunar))
    local keep_count=2
    for ((i=0; i<$((${#pids[@]}-keep_count)); i++)); do
        kill "${pids[i]}" 2>/dev/null || true
    done
fi

# Kill duplicate evince instances
evince_count=$(pgrep evince | wc -l)
if [ "$evince_count" -gt 1 ]; then
    log_action "Found $evince_count evince processes, keeping only 1"
    
    # Keep only the most recent evince process
    local pids=($(pgrep evince))
    for ((i=0; i<$((${#pids[@]}-1)); i++)); do
        kill "${pids[i]}" 2>/dev/null || true
    done
fi

# Kill duplicate unclutter instances
unclutter_count=$(pgrep unclutter | wc -l)
if [ "$unclutter_count" -gt 1 ]; then
    log_action "Found $unclutter_count unclutter processes, keeping only 1"
    pkill unclutter 2>/dev/null || true
    sleep 1
    unclutter -idle 1 -root &
fi

log_action "Process cleanup completed"
EOF

# Make all scripts executable
chmod +x /home/posuser/bin/toggle-terminal.sh
chmod +x /home/posuser/bin/view-latest-invoice.sh
chmod +x /home/posuser/bin/cleanup-processes.sh

# Update xbindkeys configuration with smarter hotkeys
log "Updating xbindkeys configuration..."
cat > /home/posuser/.xbindkeysrc << 'EOF'
# Smart POS System Hotkeys - No Duplicates, Smart Toggles

# Smart admin toggle - Ctrl+Alt+T (single instance management)
"bash /home/posuser/bin/toggle-terminal.sh"
    control+alt + t

# Smart PDF toggle - Alt+0 and Alt+Numpad0 (toggles open/close)
"bash /home/posuser/bin/view-latest-invoice.sh"
    alt + KP_0

"bash /home/posuser/bin/view-latest-invoice.sh"
    alt + 0

# Process cleanup hotkey - Ctrl+Alt+C
"bash /home/posuser/bin/cleanup-processes.sh"
    control+alt + c

# Quick print PDF with Ctrl+Alt+P (only if PDF viewer is active)
"bash /home/posuser/bin/quick-print-pdf.sh"
    control+alt + p

# Emergency kiosk reset - Ctrl+Alt+K
"pkill firefox; pkill evince; pkill thunar; sleep 2; source ~/.bashrc; start-kiosk &"
    control+alt + k

# Reload hotkeys - Ctrl+Alt+R
"killall xbindkeys; sleep 1; xbindkeys &"
    control+alt + r

# Disabled shortcuts to prevent accidents
"echo 'Use Ctrl+Alt+T for admin access'"
    alt + Tab

"echo 'Use Ctrl+Alt+T for admin access'"
    alt + F4

"echo 'Use Ctrl+Alt+K to reset kiosk'"
    F11

"echo 'Disabled in kiosk mode'"
    control+alt + Delete
EOF

# Update .bashrc with enhanced kiosk function and process management
log "Updating .bashrc with smart process management..."
cat >> /home/posuser/.bashrc << 'EOF'

# =============================================================================
# ENHANCED KIOSK AND PROCESS MANAGEMENT
# =============================================================================

# Enhanced kiosk mode with PDF handling and process management
start-kiosk() {
    echo "Starting smart kiosk mode with PDF handling..."
    export DISPLAY=:0
    
    # Clean up any existing processes first
    bash /home/posuser/bin/cleanup-processes.sh
    
    # Kill any existing Firefox instances
    pkill firefox 2>/dev/null || true
    pkill unclutter 2>/dev/null || true
    sleep 3
    
    # Hide XFCE panel
    xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -s 2 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/size -s 1 2>/dev/null || true
    
    # Ensure hotkeys are running (single instance)
    killall xbindkeys 2>/dev/null || true
    sleep 1
    xbindkeys &
    
    # Start Firefox with PDF download configuration
    firefox \
        --kiosk \
        --new-instance \
        --no-remote \
        --class="POSKiosk" \
        --profile="/home/posuser/.mozilla/firefox/pos-profile" \
        "http://localhost:3000" &
    
    # Wait for Firefox to start
    sleep 4
    
    # Hide cursor
    unclutter -idle 1 -root &
    
    # Ensure fullscreen
    wmctrl -r "POSKiosk" -b add,fullscreen 2>/dev/null || true
    
    echo "Smart kiosk mode started!"
    echo "Features:"
    echo "  - PDFs will auto-download (not display inline)"
    echo "  - Alt+0: Smart PDF toggle (open/close latest invoice)"
    echo "  - Ctrl+Alt+T: Admin mode toggle"
    echo "  - Ctrl+Alt+K: Emergency kiosk reset"
    echo "  - Ctrl+Alt+C: Process cleanup"
}

# Process management functions
cleanup-processes() {
    bash /home/posuser/bin/cleanup-processes.sh
    echo "Process cleanup completed. Check ~/.process-cleanup.log for details."
}

# Enhanced PDF functions with state management
view-invoice() {
    echo "Using smart PDF toggle..."
    bash /home/posuser/bin/view-latest-invoice.sh
}

# System status with process counts
pos-status() {
    echo "=== POS System Status ==="
    status-pos
    
    echo ""
    echo "=== Process Status ==="
    echo "Firefox processes: $(pgrep firefox | wc -l)"
    echo "Admin terminals: $(pgrep -f 'POS Admin Mode' | wc -l)"
    echo "PDF viewers: $(pgrep evince | wc -l)"
    echo "File managers: $(pgrep thunar | wc -l)"
    echo "Hotkey daemon: $(pgrep xbindkeys | wc -l)"
    
    if [ -f ~/.pdf-viewer-state ]; then
        echo "PDF viewer state: $(cat ~/.pdf-viewer-state | head -1)"
    else
        echo "PDF viewer state: closed"
    fi
}

# Reset everything to clean state
reset-pos-system() {
    echo "Resetting POS system to clean state..."
    
    # Kill all our processes
    pkill firefox 2>/dev/null || true
    pkill evince 2>/dev/null || true
    pkill thunar 2>/dev/null || true
    pkill unclutter 2>/dev/null || true
    wmctrl -c "POS Admin Mode" 2>/dev/null || true
    
    # Clean state files
    rm -f ~/.pdf-viewer-state
    
    # Wait for cleanup
    sleep 3
    
    # Restart in kiosk mode
    start-kiosk
    
    echo "POS system reset completed!"
}

# Updated help with new functions
pos-help() {
    echo "=== MSN-OPEN-POS System Commands ==="
    echo "System Management:"
    echo "  start-pos           - Start the POS system"
    echo "  stop-pos            - Stop the POS system"
    echo "  restart-pos         - Restart the POS system"
    echo "  status-pos          - Check POS system status"
    echo "  pos-status          - Extended status with process counts"
    echo "  logs-pos            - View POS system logs"
    echo "  update-pos          - Update POS system from GitHub"
    echo "  backup-pos          - Create system backup"
    echo "  reset-pos-system    - Reset to clean state"
    echo ""
    echo "Configuration:"
    echo "  edit-env            - Edit environment configuration"
    echo "  generate-key        - Generate new crypto key"
    echo ""
    echo "Kiosk Mode (Enhanced):"
    echo "  start-kiosk         - Start smart kiosk mode"
    echo "  stop-kiosk          - Stop kiosk mode"
    echo "  restart-kiosk       - Restart kiosk mode"
    echo ""
    echo "PDF Invoice Handling (Smart):"
    echo "  view-invoice        - Smart PDF toggle (open/close latest)"
    echo "  print-pdf           - Print current PDF"
    echo "  open-invoices       - Open invoices folder"
    echo "  list-invoices       - List recent PDF files"
    echo ""
    echo "Process Management:"
    echo "  cleanup-processes   - Clean duplicate processes"
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
    echo "Smart Hotkeys (Single Instance Management):"
    echo "  Ctrl+Alt+T          - Toggle admin/kiosk (smart)"
    echo "  Alt+0 or Alt+Num0   - Toggle PDF viewer (smart)"
    echo "  Ctrl+Alt+P          - Quick print current document"
    echo "  Ctrl+Alt+K          - Emergency kiosk reset"
    echo "  Ctrl+Alt+C          - Process cleanup"
    echo "  Ctrl+Alt+R          - Reload hotkeys"
    echo ""
    echo "PDF Behavior:"
    echo "  - PDFs auto-download (no inline display)"
    echo "  - Alt+0 opens latest PDF in overlay viewer"
    echo "  - Alt+0 again closes PDF and returns to POS"
    echo "  - If Firefox shows PDF, Alt+0 returns to POS system"
}
EOF

# Create a startup process cleanup service
log "Creating startup process cleanup..."
cat > /etc/systemd/system/pos-cleanup.service << 'EOF'
[Unit]
Description=POS Process Cleanup Service
After=graphical-session.target

[Service]
Type=oneshot
User=posuser
Environment=DISPLAY=:0
ExecStart=/home/posuser/bin/cleanup-processes.sh
RemainAfterExit=yes

[Install]
WantedBy=graphical-session.target
EOF

# Enable cleanup service
systemctl daemon-reload
systemctl enable pos-cleanup.service

# Set proper ownership
chown -R posuser:posuser /home/posuser/.mozilla
chown -R posuser:posuser /home/posuser/bin
chown posuser:posuser /home/posuser/.xbindkeysrc

# Restart xbindkeys with new configuration
log "Restarting hotkey system..."
sudo -u posuser bash -c 'killall xbindkeys 2>/dev/null || true; sleep 2; DISPLAY=:0 xbindkeys &' || true

# Test the Firefox profile creation
log "Testing Firefox profile setup..."
sudo -u posuser firefox --headless --profile="/home/posuser/.mozilla/firefox/pos-profile" --new-instance "about:blank" &
FIREFOX_TEST_PID=$!
sleep 3
kill $FIREFOX_TEST_PID 2>/dev/null || true

log "Smart hotkey and PDF management fixes completed!"
echo ""
echo "==============================================="
echo "SMART HOTKEY & PDF FIXES APPLIED!"
echo "==============================================="
echo ""
echo "🔧 FIXED ISSUES:"
echo "=================="
echo "✅ Firefox no longer shows PDFs inline (forces download)"
echo "✅ Alt+0 is now a smart toggle (open PDF / close PDF)"
echo "✅ Ctrl+Alt+T prevents multiple terminals"
echo "✅ Process management prevents resource waste"
echo "✅ Smart state management for all viewers"
echo ""
echo "🎯 NEW SMART BEHAVIORS:"
echo "========================"
echo ""
echo "Alt+0 / Alt+Numpad0 Smart Toggle:"
echo "  - If no PDF open: Opens latest downloaded PDF"
echo "  - If PDF is open: Closes PDF, returns to kiosk"
echo "  - If Firefox shows PDF: Returns to POS system"
echo "  - If no recent PDF: Opens file manager"
echo ""
echo "Ctrl+Alt+T Smart Toggle:"
echo "  - Only one admin terminal at a time"
echo "  - Clean switching between kiosk and admin"
echo "  - Automatic process cleanup"
echo ""
echo "🚀 NEW COMMANDS:"
echo "================"
echo "  pos-status          - Shows process counts"
echo "  cleanup-processes   - Clean duplicate processes"
echo "  reset-pos-system    - Reset everything to clean state"
echo ""
echo "⌨️ NEW HOTKEYS:"
echo "==============="
echo "  Ctrl+Alt+K          - Emergency kiosk reset"
echo "  Ctrl+Alt+C          - Process cleanup"
echo ""
echo "📄 PDF BEHAVIOR:"
echo "================"
echo "  - PDFs automatically download to ~/Downloads"
echo "  - No more inline PDF display in Firefox"
echo "  - Alt+0 always works to toggle PDF viewing"
echo "  - PDF viewer overlays kiosk mode"
echo "  - Automatic return to kiosk when closed"
echo ""
echo "🧪 TESTING:"
echo "==========="
echo "1. Download a PDF from POS system"
echo "2. Press Alt+0 to view it (should open in overlay)"
echo "3. Press Alt+0 again to close and return to kiosk"
echo "4. Press Ctrl+Alt+T to toggle admin mode"
echo "5. Run 'pos-status' to see process counts"
echo ""
echo "No reboot required - changes active immediately!"
echo "==============================================="
