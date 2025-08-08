#!/bin/bash
# improved-pos-hotkeys.sh - Enhanced POS Hotkeys Setup & Autostart for XFCE
echo "Setting up enhanced hotkeys: Q (back), W (forward), R (toggle invoice viewer)"
echo "Installing required packages..."

# Install required packages
# sudo apt update
sudo apt install xdotool wmctrl xbindkeys evince -y

# Configuration variables
DOWNLOADS_DIR="$HOME/Downloads"
VIEWER="evince"
KIOSK_WINDOW="Chromium"

# Kill any running xbindkeys first to avoid duplicates
echo "Stopping existing xbindkeys..."
pkill xbindkeys 2>/dev/null
sleep 1

# Create or overwrite xbindkeys config file
echo "Creating xbindkeys configuration..."
cat > "$HOME/.xbindkeysrc" <<'EOL'
# Navigate Back in Chromium with Q key
"bash -c '
    if xdotool search --name \"Chromium\" windowactivate --sync 2>/dev/null; then
        xdotool key Alt+Left
    else
        notify-send \"Hotkey\" \"Chromium window not found\" 2>/dev/null || echo \"Chromium window not found\"
    fi
'"
    q

# Navigate Forward in Chromium with W key  
"bash -c '
    if xdotool search --name \"Chromium\" windowactivate --sync 2>/dev/null; then
        xdotool key Alt+Right
    else
        notify-send \"Hotkey\" \"Chromium window not found\" 2>/dev/null || echo \"Chromium window not found\"
    fi
'"
    w

# Toggle Invoice Viewer with R key
"bash -c '
    EVINCE_PID=$(pgrep -f \"evince.*\.pdf\")
    
    if [ -n \"$EVINCE_PID\" ]; then
        # Close existing evince instance
        kill $EVINCE_PID
        notify-send \"Invoice\" \"PDF viewer closed\" 2>/dev/null || echo \"PDF viewer closed\"
    else
        # Find most recent PDF in Downloads
        LATEST_PDF=$(find \"$HOME/Downloads\" -name \"*.pdf\" -type f -printf \"%T@ %p\n\" 2>/dev/null | sort -nr | head -n1 | cut -d\" \" -f2-)
        
        if [ -n \"$LATEST_PDF\" ] && [ -f \"$LATEST_PDF\" ]; then
            evince \"$LATEST_PDF\" &
            notify-send \"Invoice\" \"Opening: $(basename \"$LATEST_PDF\")\" 2>/dev/null || echo \"Opening: $(basename \"$LATEST_PDF\")\"
        else
            notify-send \"Invoice\" \"No PDF files found in Downloads\" 2>/dev/null || echo \"No PDF files found in Downloads\"
        fi
    fi
'"
    r

# Emergency close all PDF viewers with Escape key
"bash -c '
    EVINCE_PIDS=$(pgrep -f evince)
    if [ -n \"$EVINCE_PIDS\" ]; then
        killall evince 2>/dev/null
        notify-send \"Emergency\" \"All PDF viewers closed\" 2>/dev/null || echo \"All PDF viewers closed\"
    fi
'"
    Escape

# Reload hotkeys configuration with F5
"bash -c '
    pkill xbindkeys 2>/dev/null
    sleep 0.5
    xbindkeys
    notify-send \"Hotkeys\" \"Configuration reloaded\" 2>/dev/null || echo \"Hotkeys reloaded\"
'"
    F5
EOL

echo "xbindkeys configuration created at ~/.xbindkeysrc"

# Test xbindkeys configuration
echo "Testing xbindkeys configuration..."
if xbindkeys --test 2>/dev/null; then
    echo "Configuration test passed."
else
    echo "Warning: Configuration test failed, but continuing anyway..."
fi

# Start xbindkeys
echo "Starting xbindkeys..."
xbindkeys
if [ $? -eq 0 ]; then
    echo "xbindkeys started successfully."
else
    echo "Error starting xbindkeys. Please check the configuration."
    exit 1
fi

# Setup autostart for xbindkeys on login (XFCE)
echo "Setting up autostart..."
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

cat > "$AUTOSTART_DIR/xbindkeys.desktop" <<EOL
[Desktop Entry]
Type=Application
Name=Enhanced POS Hotkeys
Exec=bash -c 'sleep 3 && xbindkeys'
Comment=Start xbindkeys for enhanced POS hotkeys (Q=back, W=forward, R=toggle invoice)
X-GNOME-Autostart-enabled=true
Hidden=false
EOL

echo "Autostart entry created for xbindkeys."

# Create a helper script for manual control
cat > "$HOME/pos-hotkeys-control.sh" <<'EOL'
#!/bin/bash
# Helper script to control POS hotkeys

case "$1" in
    start)
        pkill xbindkeys 2>/dev/null
        sleep 0.5
        xbindkeys
        echo "Hotkeys started"
        ;;
    stop)
        pkill xbindkeys 2>/dev/null
        echo "Hotkeys stopped"
        ;;
    restart)
        pkill xbindkeys 2>/dev/null
        sleep 0.5
        xbindkeys
        echo "Hotkeys restarted"
        ;;
    status)
        if pgrep xbindkeys > /dev/null; then
            echo "Hotkeys are running (PID: $(pgrep xbindkeys))"
        else
            echo "Hotkeys are not running"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        echo "Hotkey bindings:"
        echo "  Q - Navigate back in Chromium"
        echo "  W - Navigate forward in Chromium" 
        echo "  R - Toggle latest PDF invoice viewer"
        echo "  Escape - Emergency close all PDF viewers"
        echo "  F5 - Reload hotkey configuration"
        ;;
esac
EOL

chmod +x "$HOME/pos-hotkeys-control.sh"
echo "Control script created at ~/pos-hotkeys-control.sh"

# Final status check
sleep 1
if pgrep xbindkeys > /dev/null; then
    echo ""
    echo "✅ Setup complete! Enhanced POS hotkeys are now active:"
    echo "   Q - Navigate back in Chromium"
    echo "   W - Navigate forward in Chromium"
    echo "   R - Toggle latest PDF invoice viewer"
    echo "   Escape - Emergency close all PDF viewers"
    echo "   F5 - Reload hotkey configuration"
    echo ""
    echo "Control script available: ~/pos-hotkeys-control.sh {start|stop|restart|status}"
    echo "Hotkeys will automatically start on system boot."
else
    echo "❌ Warning: xbindkeys may not be running properly."
    echo "Try running: ~/pos-hotkeys-control.sh start"
fi
