#!/bin/bash

# Smart PDF Toggle Enhancement for POS System
# Makes Alt+0 intelligently toggle between PDF viewer and kiosk mode
# Usage: sudo bash smart_pdf_toggle.sh

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

log "Enhancing PDF viewer with smart toggle functionality..."

# Create enhanced smart PDF toggle script
cat > /home/posuser/bin/smart-pdf-toggle.sh << 'EOF'
#!/bin/bash

# Smart PDF Toggle Script - Alt+0 hotkey handler
export DISPLAY=:0

# Log file for debugging
LOG_FILE="$HOME/.pdf-toggle.log"
STATE_FILE="$HOME/.pdf-viewer-state"

log_action() {
    echo "$(date): $1" >> "$LOG_FILE"
}

# Function to check what's currently active
get_current_state() {
    local pdf_viewer_active=false
    local kiosk_active=false
    
    # Check for PDF viewers (evince, thunar with PDF)
    if wmctrl -l | grep -qi "evince\|document viewer"; then
        pdf_viewer_active=true
    elif wmctrl -l | grep -qi "thunar.*\.pdf\|file manager.*\.pdf"; then
        pdf_viewer_active=true
    elif pgrep -f "evince.*\.pdf" > /dev/null; then
        pdf_viewer_active=true
    fi
    
    # Check for kiosk mode
    if pgrep -f "firefox.*--kiosk" > /dev/null; then
        kiosk_active=true
    fi
    
    if $pdf_viewer_active; then
        echo "pdf"
    elif $kiosk_active; then
        echo "kiosk"
    else
        echo "unknown"
    fi
}

# Function to close all PDF viewers
close_pdf_viewers() {
    log_action "Closing PDF viewers"
    
    # Close evince
    wmctrl -c "evince" 2>/dev/null || true
    wmctrl -c "Document Viewer" 2>/dev/null || true
    pkill evince 2>/dev/null || true
    
    # Close thunar if it has PDF open
    if wmctrl -l | grep -qi "thunar.*\.pdf"; then
        wmctrl -c "thunar" 2>/dev/null || true
    fi
    
    # Wait for processes to close
    sleep 1
    
    # Force kill if still running
    pkill -f "evince.*\.pdf" 2>/dev/null || true
}

# Function to ensure kiosk is running
ensure_kiosk() {
    log_action "Ensuring kiosk mode is active"
    
    if ! pgrep -f "firefox.*--kiosk" > /dev/null; then
        log_action "Starting kiosk mode"
        source ~/.bashrc
        
        # Hide panel
        xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -s 2 2>/dev/null || true
        xfconf-query -c xfce4-panel -p /panels/panel-1/size -s 1 2>/dev/null || true
        
        # Start Firefox kiosk
        firefox \
            --kiosk \
            --new-instance \
            --no-remote \
            --class="POSKiosk" \
            "http://localhost:3000" &
        
        # Hide cursor
        unclutter -idle 1 -root &
        
        # Wait for Firefox to start and ensure fullscreen
        sleep 3
        wmctrl -r "POSKiosk" -b add,fullscreen 2>/dev/null || true
    else
        log_action "Kiosk already running, bringing to front"
        wmctrl -a "POSKiosk" 2>/dev/null || wmctrl -a "firefox" 2>/dev/null || true
    fi
}

# Function to find and open latest PDF
open_latest_pdf() {
    log_action "Looking for latest PDF to open"
    
    # Search directories for PDFs
    local DOWNLOAD_DIRS=(
        "$HOME/Downloads"
        "$HOME/Desktop"
        "$HOME/pos-system/invoices"
        "$HOME/Documents"
        "/tmp"
    )
    
    local latest_pdf=""
    local latest_time=0
    
    # Find the most recent PDF
    for dir in "${DOWNLOAD_DIRS[@]}"; do
        if [ -d "$dir" ]; then
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
    
    if [ -n "$latest_pdf" ] && [ -f "$latest_pdf" ]; then
        log_action "Opening PDF: $latest_pdf"
        
        # Store the PDF path for reference
        echo "$latest_pdf" > "$STATE_FILE"
        
        # Open with evince
        evince "$latest_pdf" &
        
        # Wait for evince to start and bring to front
        sleep 2
        wmctrl -a "evince" 2>/dev/null || wmctrl -a "Document Viewer" 2>/dev/null || true
        
        return 0
    else
        log_action "No recent PDF found, opening file manager"
        
        # No recent PDF, open file manager
        thunar "$HOME/Downloads" &
        
        # Wait and bring to front
        sleep 2
        wmctrl -a "thunar" 2>/dev/null || wmctrl -a "File Manager" 2>/dev/null || true
        
        echo "file_manager" > "$STATE_FILE"
        return 1
    fi
}

# Main toggle logic
main() {
    log_action "Smart PDF toggle activated"
    
    local current_state=$(get_current_state)
    log_action "Current state detected: $current_state"
    
    case "$current_state" in
        "pdf")
            # PDF is open, close it and return to kiosk
            log_action "PDF viewer open - closing and returning to kiosk"
            close_pdf_viewers
            sleep 1
            ensure_kiosk
            echo "kiosk" > "$STATE_FILE"
            ;;
        "kiosk")
            # Kiosk is active, open PDF
            log_action "Kiosk active - opening PDF viewer"
            if open_latest_pdf; then
                echo "pdf" > "$STATE_FILE"
            else
                echo "file_manager" > "$STATE_FILE"
            fi
            ;;
        "unknown")
            # Unknown state, try to determine what to do
            log_action "Unknown state - checking last action"
            
            # Check state file for last action
            if [ -f "$STATE_FILE" ]; then
                local last_state=$(cat "$STATE_FILE" 2>/dev/null || echo "")
                log_action "Last state was: $last_state"
                
                case "$last_state" in
                    "pdf"|"file_manager")
                        # Last was PDF-related, go to kiosk
                        ensure_kiosk
                        echo "kiosk" > "$STATE_FILE"
                        ;;
                    *)
                        # Default to opening PDF
                        if open_latest_pdf; then
                            echo "pdf" > "$STATE_FILE"
                        else
                            echo "file_manager" > "$STATE_FILE"
                        fi
                        ;;
                esac
            else
                # No state file, default to opening PDF
                if open_latest_pdf; then
                    echo "pdf" > "$STATE_FILE"
                else
                    echo "file_manager" > "$STATE_FILE"
                fi
            fi
            ;;
    esac
    
    log_action "Toggle action completed"
}

# Run main function
main "$@"
EOF

# Create enhanced kiosk startup that doesn't auto-open PDFs
cat > /home/posuser/bin/start-enhanced-kiosk.sh << 'EOF'
#!/bin/bash

# Enhanced kiosk startup without auto-PDF opening
export DISPLAY=:0

log_action() {
    echo "$(date): $1" >> ~/.kiosk-startup.log
}

log_action "Starting enhanced kiosk mode"

# Kill any existing instances
pkill firefox 2>/dev/null || true
pkill unclutter 2>/dev/null || true
pkill evince 2>/dev/null || true

# Close any open PDF viewers or file managers from previous session
wmctrl -c "evince" 2>/dev/null || true
wmctrl -c "Document Viewer" 2>/dev/null || true
wmctrl -c "thunar" 2>/dev/null || true

sleep 2

# Hide XFCE panel
xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -s 2 2>/dev/null || true
xfconf-query -c xfce4-panel -p /panels/panel-1/size -s 1 2>/dev/null || true

# Ensure hotkeys are running
killall xbindkeys 2>/dev/null || true
sleep 1
xbindkeys &

# Start Firefox kiosk mode
firefox \
    --kiosk \
    --new-instance \
    --no-remote \
    --class="POSKiosk" \
    "http://localhost:3000" &

# Wait for Firefox to start
sleep 3

# Hide cursor
unclutter -idle 1 -root &

# Ensure fullscreen
wmctrl -r "POSKiosk" -b add,fullscreen 2>/dev/null || true

# Set initial state
echo "kiosk" > ~/.pdf-viewer-state

log_action "Enhanced kiosk mode started successfully"

echo "Enhanced kiosk mode active"
echo "Smart PDF toggle ready - Press Alt+0 to toggle PDF viewer"
EOF

# Update hotkey configuration with smart toggle
log "Updating hotkey configuration..."
cat > /home/posuser/.xbindkeysrc << 'EOF'
# Enhanced POS System Hotkeys Configuration with Smart PDF Toggle

# Admin mode toggle with Ctrl+Alt+T
"bash /home/posuser/bin/toggle-terminal.sh"
    control+alt + t

# Smart PDF toggle with Alt+KP_0 (Alt + Numpad 0)
"bash /home/posuser/bin/smart-pdf-toggle.sh"
    alt + KP_0

# Smart PDF toggle with Alt+0 (regular number key)
"bash /home/posuser/bin/smart-pdf-toggle.sh"
    alt + 0

# Quick print PDF with Ctrl+Alt+P
"bash /home/posuser/bin/quick-print-pdf.sh"
    control+alt + p

# Emergency escape from kiosk with Ctrl+Alt+E
"pkill firefox; pkill evince; xfce4-terminal --fullscreen --title='Emergency Admin Mode' &"
    control+alt + e

# Force close all viewers and return to kiosk with Ctrl+Alt+K
"pkill firefox; pkill evince; wmctrl -c thunar; sleep 2; bash /home/posuser/bin/start-enhanced-kiosk.sh &"
    control+alt + k

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

# Update .bashrc with enhanced functions
log "Updating .bashrc with smart toggle functions..."
cat >> /home/posuser/.bashrc << 'EOF'

# =============================================================================
# ENHANCED PDF HANDLING WITH SMART TOGGLE
# =============================================================================

# Smart PDF toggle function
pdf-toggle() {
    echo "Executing smart PDF toggle..."
    bash /home/posuser/bin/smart-pdf-toggle.sh
}

# Check current PDF viewer state
pdf-status() {
    local state_file="$HOME/.pdf-viewer-state"
    local log_file="$HOME/.pdf-toggle.log"
    
    echo "=== PDF Viewer Status ==="
    
    if [ -f "$state_file" ]; then
        echo "Current state: $(cat "$state_file")"
    else
        echo "No state file found"
    fi
    
    echo ""
    echo "Active processes:"
    pgrep -fl "evince|firefox.*kiosk|thunar" || echo "None found"
    
    echo ""
    echo "Active windows:"
    wmctrl -l | grep -i "evince\|firefox\|thunar\|document" || echo "None found"
    
    if [ -f "$log_file" ]; then
        echo ""
        echo "Recent activity (last 5 lines):"
        tail -5 "$log_file"
    fi
}

# Enhanced kiosk mode that doesn't auto-open PDFs
start-kiosk() {
    echo "Starting enhanced kiosk mode..."
    bash /home/posuser/bin/start-enhanced-kiosk.sh
}

# Force return to kiosk from any state
force-kiosk() {
    echo "Force returning to kiosk mode..."
    pkill firefox 2>/dev/null || true
    pkill evince 2>/dev/null || true
    wmctrl -c "thunar" 2>/dev/null || true
    wmctrl -c "Document Viewer" 2>/dev/null || true
    sleep 2
    start-kiosk
}

# Clear PDF viewer state
reset-pdf-state() {
    rm -f ~/.pdf-viewer-state
    rm -f ~/.pdf-toggle.log
    echo "PDF viewer state reset"
}

# Update help with new commands
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
    echo "  start-kiosk         - Start enhanced kiosk mode"
    echo "  stop-kiosk          - Stop kiosk mode"
    echo "  restart-kiosk       - Restart kiosk mode"
    echo "  force-kiosk         - Force return to kiosk from any state"
    echo ""
    echo "Smart PDF Handling:"
    echo "  pdf-toggle          - Smart toggle between PDF and kiosk"
    echo "  pdf-status          - Check current PDF viewer state"
    echo "  reset-pdf-state     - Reset PDF viewer state"
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
    echo "Smart Hotkeys:"
    echo "  Alt+0 or Alt+Num0   - SMART PDF TOGGLE"
    echo "                        (PDF open → close PDF, return to kiosk)"
    echo "                        (Kiosk active → open latest PDF)"
    echo "  Ctrl+Alt+T          - Toggle admin mode"
    echo "  Ctrl+Alt+P          - Quick print current document"
    echo "  Ctrl+Alt+E          - Emergency admin access"
    echo "  Ctrl+Alt+K          - Force return to kiosk mode"
    echo "  Ctrl+Alt+R          - Reload hotkeys"
    echo "  Ctrl+Alt+H          - Toggle cursor visibility"
}
EOF

# Update kiosk autostart to use enhanced version
cat > /home/posuser/.config/autostart/pos-kiosk.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=POS Enhanced Kiosk Mode
Exec=/bin/bash -c 'sleep 15 && bash /home/posuser/bin/start-enhanced-kiosk.sh'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
StartupNotify=false
EOF

# Make all scripts executable
chmod +x /home/posuser/bin/smart-pdf-toggle.sh
chmod +x /home/posuser/bin/start-enhanced-kiosk.sh

# Set proper ownership
chown -R posuser:posuser /home/posuser/bin
chown posuser:posuser /home/posuser/.xbindkeysrc
chown posuser:posuser /home/posuser/.config/autostart/pos-kiosk.desktop

# Restart xbindkeys with new configuration
log "Restarting hotkey daemon with smart toggle..."
sudo -u posuser bash -c 'killall xbindkeys 2>/dev/null || true; sleep 2; DISPLAY=:0 xbindkeys &' || true

log "Smart PDF toggle enhancement completed!"
echo ""
echo "==============================================="
echo "SMART PDF TOGGLE ENHANCEMENT APPLIED!"
echo "==============================================="
echo ""
echo "🧠 SMART TOGGLE BEHAVIOR:"
echo "========================="
echo ""
echo "Alt+0 or Alt+Numpad0 now intelligently toggles:"
echo ""
echo "📄 When PDF is open:"
echo "   → Closes PDF viewer"
echo "   → Returns to kiosk mode automatically"
echo ""
echo "🖥️  When kiosk is active:"
echo "   → Opens most recent PDF in overlay mode"
echo "   → PDF viewer appears on top of kiosk"
echo ""
echo "📁 When no recent PDF found:"
echo "   → Opens file manager to Downloads folder"
echo "   → Alt+0 again will close file manager → return to kiosk"
echo ""
echo "🔄 STATE MANAGEMENT:"
echo "==================="
echo "The system now tracks state in ~/.pdf-viewer-state"
echo "It remembers what you were doing and toggles accordingly"
echo ""
echo "🆕 NEW COMMANDS:"
echo "==============="
echo "  pdf-toggle          - Manual smart toggle"
echo "  pdf-status          - Check current state"
echo "  force-kiosk         - Force return to kiosk from anywhere"
echo "  reset-pdf-state     - Reset state if things get confused"
echo ""
echo "🎯 ENHANCED HOTKEYS:"
echo "==================="
echo "  Alt+0/NumPad0       - Smart PDF toggle (main feature)"
echo "  Ctrl+Alt+K          - Force return to kiosk"
echo "  Ctrl+Alt+T          - Admin mode toggle"
echo "  Ctrl+Alt+E          - Emergency admin access"
echo ""
echo "🔧 NO AUTO-OPEN:"
echo "================="
echo "PDFs will NO LONGER auto-open on download"
echo "You control when to view them with Alt+0"
echo ""
echo "Ready to test! Press Alt+0 to try the smart toggle."
echo "==============================================="
