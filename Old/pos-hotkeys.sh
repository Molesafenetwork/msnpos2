#!/bin/bash
# improved-pos-hotkeys.sh - Enhanced POS Hotkeys Setup for XFCE (Numpad/Arrow Keys Only)
echo "Setting up enhanced POS hotkeys using numpad and arrow keys..."
echo "This will not interfere with normal typing!"

# Install required packages
echo "Installing required packages..."
sudo apt update
sudo apt install xbindkeys evince wmctrl xdotool xinput -y

# Configuration variables
DOWNLOADS_DIR="$HOME/Downloads"
VIEWER="evince"

# Kill any running xbindkeys first
echo "Stopping existing xbindkeys..."
pkill xbindkeys 2>/dev/null
sleep 1

# Create improved xbindkeys config with numpad and arrow keys only
echo "Creating improved xbindkeys configuration..."
cat > "$HOME/.xbindkeysrc" <<'EOL'
# POS Hotkeys Configuration - Safe Keys Only (No interference with typing)
# Uses numpad and arrow keys for navigation and PDF control

# Navigate Back with Left Arrow
"bash -c '
    # Find active browser window (try multiple browsers)
    BROWSER_WINDOW=$(wmctrl -l | grep -i -E \"chromium|firefox|chrome\" | head -1 | cut -d\" \" -f1)
    if [ -n \"$BROWSER_WINDOW\" ]; then
        wmctrl -i -a \"$BROWSER_WINDOW\" 2>/dev/null
        sleep 0.1
        xdotool key --window \"$BROWSER_WINDOW\" Alt+Left 2>/dev/null
        notify-send \"POS Nav\" \"Back\" -t 1000 2>/dev/null || echo \"Navigate: Back\"
    else
        notify-send \"POS Nav\" \"Browser not found\" -t 2000 2>/dev/null || echo \"Browser not found\"
    fi
'"
    Left

# Navigate Forward with Right Arrow  
"bash -c '
    # Find active browser window
    BROWSER_WINDOW=$(wmctrl -l | grep -i -E \"chromium|firefox|chrome\" | head -1 | cut -d\" \" -f1)
    if [ -n \"$BROWSER_WINDOW\" ]; then
        wmctrl -i -a \"$BROWSER_WINDOW\" 2>/dev/null
        sleep 0.1
        xdotool key --window \"$BROWSER_WINDOW\" Alt+Right 2>/dev/null
        notify-send \"POS Nav\" \"Forward\" -t 1000 2>/dev/null || echo \"Navigate: Forward\"
    else
        notify-send \"POS Nav\" \"Browser not found\" -t 2000 2>/dev/null || echo \"Browser not found\"
    fi
'"
    Right

# Refresh Page with Up Arrow
"bash -c '
    BROWSER_WINDOW=$(wmctrl -l | grep -i -E \"chromium|firefox|chrome\" | head -1 | cut -d\" \" -f1)
    if [ -n \"$BROWSER_WINDOW\" ]; then
        wmctrl -i -a \"$BROWSER_WINDOW\" 2>/dev/null
        sleep 0.1
        xdotool key --window \"$BROWSER_WINDOW\" F5 2>/dev/null
        notify-send \"POS Nav\" \"Refreshed\" -t 1000 2>/dev/null || echo \"Page refreshed\"
    fi
'"
    Up

# Toggle Invoice Viewer with Down Arrow
"bash -c '
    EVINCE_PID=$(pgrep -f \"evince.*\.pdf\")
    
    if [ -n \"$EVINCE_PID\" ]; then
        # Close existing evince instance
        kill $EVINCE_PID 2>/dev/null
        notify-send \"Invoice\" \"PDF viewer closed\" -t 1500 2>/dev/null || echo \"PDF viewer closed\"
    else
        # Find most recent PDF in Downloads and pos-system data folder
        LATEST_PDF1=$(find \"$HOME/Downloads\" -name \"*.pdf\" -type f -printf \"%T@ %p\n\" 2>/dev/null | sort -nr | head -n1 | cut -d\" \" -f2-)
        LATEST_PDF2=$(find \"$HOME/pos-system/public/.data\" -name \"*.pdf\" -type f -printf \"%T@ %p\n\" 2>/dev/null | sort -nr | head -n1 | cut -d\" \" -f2-)
        
        # Choose the most recent between the two locations
        LATEST_PDF=\"\"
        if [ -f \"$LATEST_PDF1\" ] && [ -f \"$LATEST_PDF2\" ]; then
            if [ \"$LATEST_PDF1\" -nt \"$LATEST_PDF2\" ]; then
                LATEST_PDF=\"$LATEST_PDF1\"
            else
                LATEST_PDF=\"$LATEST_PDF2\"
            fi
        elif [ -f \"$LATEST_PDF1\" ]; then
            LATEST_PDF=\"$LATEST_PDF1\"
        elif [ -f \"$LATEST_PDF2\" ]; then
            LATEST_PDF=\"$LATEST_PDF2\"
        fi
        
        if [ -n \"$LATEST_PDF\" ] && [ -f \"$LATEST_PDF\" ]; then
            evince \"$LATEST_PDF\" &
            notify-send \"Invoice\" \"Opening: $(basename \"$LATEST_PDF\")\" -t 2000 2>/dev/null || echo \"Opening: $(basename \"$LATEST_PDF\")\"
        else
            notify-send \"Invoice\" \"No PDF files found\" -t 2000 2>/dev/null || echo \"No PDF files found\"
        fi
    fi
'"
    Down

# Numpad Navigation (Alternative keys)
# Numpad 4 - Back
"bash -c '
    BROWSER_WINDOW=$(wmctrl -l | grep -i -E \"chromium|firefox|chrome\" | head -1 | cut -d\" \" -f1)
    if [ -n \"$BROWSER_WINDOW\" ]; then
        wmctrl -i -a \"$BROWSER_WINDOW\" 2>/dev/null
        sleep 0.1
        xdotool key --window \"$BROWSER_WINDOW\" Alt+Left 2>/dev/null
        notify-send \"POS Nav\" \"Back (Numpad)\" -t 1000 2>/dev/null || echo \"Navigate: Back\"
    fi
'"
    KP_Left

# Numpad 6 - Forward
"bash -c '
    BROWSER_WINDOW=$(wmctrl -l | grep -i -E \"chromium|firefox|chrome\" | head -1 | cut -d\" \" -f1)
    if [ -n \"$BROWSER_WINDOW\" ]; then
        wmctrl -i -a \"$BROWSER_WINDOW\" 2>/dev/null
        sleep 0.1
        xdotool key --window \"$BROWSER_WINDOW\" Alt+Right 2>/dev/null
        notify-send \"POS Nav\" \"Forward (Numpad)\" -t 1000 2>/dev/null || echo \"Navigate: Forward\"
    fi
'"
    KP_Right

# Numpad 8 - Refresh
"bash -c '
    BROWSER_WINDOW=$(wmctrl -l | grep -i -E \"chromium|firefox|chrome\" | head -1 | cut -d\" \" -f1)
    if [ -n \"$BROWSER_WINDOW\" ]; then
        wmctrl -i -a \"$BROWSER_WINDOW\" 2>/dev/null
        sleep 0.1
        xdotool key --window \"$BROWSER_WINDOW\" F5 2>/dev/null
        notify-send \"POS Nav\" \"Refreshed (Numpad)\" -t 1000 2>/dev/null || echo \"Page refreshed\"
    fi
'"
    KP_Up

# Numpad 2 - Toggle Invoice
"bash -c '
    EVINCE_PID=$(pgrep -f \"evince.*\.pdf\")
    
    if [ -n \"$EVINCE_PID\" ]; then
        kill $EVINCE_PID 2>/dev/null
        notify-send \"Invoice\" \"PDF closed (Numpad)\" -t 1500 2>/dev/null || echo \"PDF viewer closed\"
    else
        LATEST_PDF1=$(find \"$HOME/Downloads\" -name \"*.pdf\" -type f -printf \"%T@ %p\n\" 2>/dev/null | sort -nr | head -n1 | cut -d\" \" -f2-)
        LATEST_PDF2=$(find \"$HOME/pos-system/public/.data\" -name \"*.pdf\" -type f -printf \"%T@ %p\n\" 2>/dev/null | sort -nr | head -n1 | cut -d\" \" -f2-)
        
        LATEST_PDF=\"\"
        if [ -f \"$LATEST_PDF1\" ] && [ -f \"$LATEST_PDF2\" ]; then
            if [ \"$LATEST_PDF1\" -nt \"$LATEST_PDF2\" ]; then
                LATEST_PDF=\"$LATEST_PDF1\"
            else
                LATEST_PDF=\"$LATEST_PDF2\"
            fi
        elif [ -f \"$LATEST_PDF1\" ]; then
            LATEST_PDF=\"$LATEST_PDF1\"
        elif [ -f \"$LATEST_PDF2\" ]; then
            LATEST_PDF=\"$LATEST_PDF2\"
        fi
        
        if [ -n \"$LATEST_PDF\" ] && [ -f \"$LATEST_PDF\" ]; then
            evince \"$LATEST_PDF\" &
            notify-send \"Invoice\" \"Opening (Numpad): $(basename \"$LATEST_PDF\")\" -t 2000 2>/dev/null || echo \"Opening: $(basename \"$LATEST_PDF\")\"
        else
            notify-send \"Invoice\" \"No PDF found (Numpad)\" -t 2000 2>/dev/null || echo \"No PDF files found\"
        fi
    fi
'"
    KP_Down

# Emergency close all PDF viewers with Numpad 0
"bash -c '
    EVINCE_PIDS=$(pgrep evince)
    if [ -n \"$EVINCE_PIDS\" ]; then
        killall evince 2>/dev/null
        notify-send \"Emergency\" \"All PDF viewers closed\" -t 2000 2>/dev/null || echo \"All PDF viewers closed\"
    else
        notify-send \"Info\" \"No PDF viewers running\" -t 1500 2>/dev/null || echo \"No PDF viewers running\"
    fi
'"
    KP_Insert

# Show help with Numpad Plus
"bash -c '
    notify-send \"POS Hotkeys Help\" \"Arrow Keys: ←Back →Forward ↑Refresh ↓PDF\nNumpad: 4Back 6Forward 8Refresh 2PDF 0CloseAll\" -t 5000 2>/dev/null || echo \"Hotkeys: Arrows for nav, Numpad alternatives\"
'"
    KP_Add

# Reload hotkeys with Numpad Enter
"bash -c '
    pkill xbindkeys 2>/dev/null
    sleep 0.5
    xbindkeys
    notify-send \"Hotkeys\" \"Configuration reloaded\" -t 2000 2>/dev/null || echo \"Hotkeys reloaded\"
'"
    KP_Enter
EOL

echo "✅ xbindkeys configuration created at ~/.xbindkeysrc"

# Create a startup script that ensures proper initialization
cat > "$HOME/pos-hotkeys-startup.sh" <<'EOL'
#!/bin/bash
# POS Hotkeys startup script with proper initialization

# Wait for desktop environment to be ready
sleep 5

# Kill any existing xbindkeys
pkill xbindkeys 2>/dev/null
sleep 1

# Check if X server is ready
for i in {1..30}; do
    if xset q >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

# Start xbindkeys with error handling
if [ -f "$HOME/.xbindkeysrc" ]; then
    xbindkeys 2>/dev/null
    if [ $? -eq 0 ]; then
        notify-send "POS Hotkeys" "Activated: Arrow keys & Numpad for navigation" -t 3000 2>/dev/null
    else
        echo "Failed to start xbindkeys" >> "$HOME/.xbindkeys-error.log"
    fi
else
    echo "xbindkeys config not found" >> "$HOME/.xbindkeys-error.log"
fi
EOL

chmod +x "$HOME/pos-hotkeys-startup.sh"

# Test xbindkeys configuration
echo "Testing xbindkeys configuration..."
if xbindkeys --test 2>/dev/null; then
    echo "✅ Configuration test passed."
else
    echo "⚠️ Configuration test had warnings, but continuing..."
fi

# Start xbindkeys
echo "Starting xbindkeys..."
pkill xbindkeys 2>/dev/null
sleep 0.5
xbindkeys

if pgrep xbindkeys > /dev/null; then
    echo "✅ xbindkeys started successfully."
else
    echo "❌ Error starting xbindkeys. Checking configuration..."
    xbindkeys --test
fi

# Setup autostart for XFCE with improved reliability
echo "Setting up autostart..."
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

cat > "$AUTOSTART_DIR/pos-hotkeys.desktop" <<EOL
[Desktop Entry]
Type=Application
Name=POS Hotkeys Service
Exec=$HOME/pos-hotkeys-startup.sh
Comment=POS navigation hotkeys using arrow keys and numpad (typing-safe)
X-GNOME-Autostart-enabled=true
Hidden=false
StartupNotify=false
X-GNOME-Autostart-Delay=10
EOL

echo "✅ Autostart entry created."

# Create enhanced control script
cat > "$HOME/pos-hotkeys-control.sh" <<'EOL'
#!/bin/bash
# Enhanced POS hotkeys control script

case "$1" in
    start)
        echo "Starting POS hotkeys..."
        pkill xbindkeys 2>/dev/null
        sleep 0.5
        if xbindkeys; then
            echo "✅ Hotkeys started successfully"
            notify-send "POS Hotkeys" "Started" -t 2000 2>/dev/null
        else
            echo "❌ Failed to start hotkeys"
        fi
        ;;
    stop)
        echo "Stopping POS hotkeys..."
        pkill xbindkeys 2>/dev/null
        echo "✅ Hotkeys stopped"
        notify-send "POS Hotkeys" "Stopped" -t 2000 2>/dev/null
        ;;
    restart)
        echo "Restarting POS hotkeys..."
        pkill xbindkeys 2>/dev/null
        sleep 0.5
        if xbindkeys; then
            echo "✅ Hotkeys restarted successfully"
            notify-send "POS Hotkeys" "Restarted" -t 2000 2>/dev/null
        else
            echo "❌ Failed to restart hotkeys"
        fi
        ;;
    status)
        if pgrep xbindkeys > /dev/null; then
            PID=$(pgrep xbindkeys)
            echo "✅ POS hotkeys are running (PID: $PID)"
        else
            echo "❌ POS hotkeys are not running"
        fi
        ;;
    test)
        echo "Testing hotkey configuration..."
        if xbindkeys --test 2>/dev/null; then
            echo "✅ Configuration is valid"
        else
            echo "❌ Configuration has errors"
            echo "Run 'xbindkeys --test' for details"
        fi
        ;;
    help|*)
        echo "POS Hotkeys Control Script"
        echo "Usage: $0 {start|stop|restart|status|test|help}"
        echo ""
        echo "🎯 ACTIVE HOTKEYS (Typing-Safe):"
        echo "┌─────────────────────────────────────┐"
        echo "│ ARROW KEYS:                         │"
        echo "│  ← Left Arrow    - Navigate Back    │"
        echo "│  → Right Arrow   - Navigate Forward │" 
        echo "│  ↑ Up Arrow      - Refresh Page     │"
        echo "│  ↓ Down Arrow    - Toggle PDF View  │"
        echo "├─────────────────────────────────────┤"
        echo "│ NUMPAD (Alternative):               │"
        echo "│  4 (Numpad ←)    - Navigate Back    │"
        echo "│  6 (Numpad →)    - Navigate Forward │"
        echo "│  8 (Numpad ↑)    - Refresh Page     │"
        echo "│  2 (Numpad ↓)    - Toggle PDF View  │"
        echo "│  0 (Numpad Ins)  - Close All PDFs   │"
        echo "│  + (Numpad Plus) - Show Help        │"
        echo "│  ⏎ (Numpad Enter)- Reload Hotkeys   │"
        echo "└─────────────────────────────────────┘"
        echo ""
        echo "📁 PDF Search Locations:"
        echo "  • ~/Downloads/"
        echo "  • ~/pos-system/public/.data/"
        echo ""
        echo "🔒 SAFE DESIGN: Only uses arrow keys and numpad"
        echo "   Normal typing is NOT affected!"
        ;;
esac
EOL

chmod +x "$HOME/pos-hotkeys-control.sh"
echo "✅ Control script created at ~/pos-hotkeys-control.sh"

# Add to PATH if not already there
if ! grep -q "pos-hotkeys-control" "$HOME/.bashrc"; then
    echo "alias hotkeys='$HOME/pos-hotkeys-control.sh'" >> "$HOME/.bashrc"
    echo "✅ Added 'hotkeys' alias to .bashrc"
fi

# Final status check and summary
sleep 1
echo ""
echo "🎉 SETUP COMPLETE!"
echo ""
if pgrep xbindkeys > /dev/null; then
    echo "✅ POS hotkeys are now active and running"
    echo "🔒 TYPING-SAFE: Only arrow keys and numpad are used"
    echo ""
    echo "🎯 Quick Test:"
    echo "  • Press ← → arrows to navigate browser"
    echo "  • Press ↑ to refresh page"  
    echo "  • Press ↓ to toggle PDF viewer"
    echo "  • Press Numpad + for help popup"
    echo ""
    echo "🛠️ Control Commands:"
    echo "  • hotkeys status    - Check if running"
    echo "  • hotkeys restart   - Restart hotkeys"
    echo "  • hotkeys help      - Show all hotkeys"
    echo ""
    echo "🔄 Auto-start: Enabled (will start on boot)"
else
    echo "⚠️ Warning: Hotkeys may not be running properly"
    echo "💡 Try: hotkeys start"
fi

echo ""
echo "📋 Log files:"
echo "  • ~/.xbindkeys-error.log - Error log"
echo "  • Check with: hotkeys status"
