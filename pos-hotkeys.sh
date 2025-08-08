#!/bin/bash
# remove-pos-hotkeys.sh - Remove POS Hotkeys and Restore Normal Key Function
echo "Removing POS hotkeys and restoring Z, X, and I to normal keyboard function..."

# Kill any running xbindkeys processes
echo "Stopping xbindkeys..."
pkill xbindkeys 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ xbindkeys processes stopped"
else
    echo "✓ No running xbindkeys processes found"
fi

# Wait a moment for processes to fully terminate
sleep 1

# Remove or backup the xbindkeys configuration file
if [ -f "$HOME/.xbindkeysrc" ]; then
    echo "Removing xbindkeys configuration..."
    # Create a backup first (optional)
    if [ ! -f "$HOME/.xbindkeysrc.backup" ]; then
        cp "$HOME/.xbindkeysrc" "$HOME/.xbindkeysrc.backup"
        echo "✓ Backup created at ~/.xbindkeysrc.backup"
    fi
    
    # Remove the active configuration
    rm "$HOME/.xbindkeysrc"
    echo "✓ xbindkeys configuration file removed"
else
    echo "✓ No xbindkeys configuration file found"
fi

# Remove autostart entry
AUTOSTART_FILE="$HOME/.config/autostart/xbindkeys.desktop"
if [ -f "$AUTOSTART_FILE" ]; then
    rm "$AUTOSTART_FILE"
    echo "✓ Autostart entry removed"
else
    echo "✓ No autostart entry found"
fi

# Close any running evince processes that might have been opened by the hotkeys
echo "Closing any PDF viewers opened by hotkeys..."
EVINCE_PIDS=$(pgrep -f evince)
if [ -n "$EVINCE_PIDS" ]; then
    killall evince 2>/dev/null
    echo "✓ PDF viewers closed"
else
    echo "✓ No PDF viewers running"
fi

# Remove control script if it exists (from the enhanced version)
if [ -f "$HOME/pos-hotkeys-control.sh" ]; then
    rm "$HOME/pos-hotkeys-control.sh"
    echo "✓ Control script removed"
fi

# Verify xbindkeys is not running
sleep 1
if pgrep xbindkeys > /dev/null; then
    echo "⚠ Warning: xbindkeys is still running. Attempting force kill..."
    pkill -9 xbindkeys 2>/dev/null
    sleep 1
    if pgrep xbindkeys > /dev/null; then
        echo "❌ Error: Could not stop xbindkeys. You may need to restart your session."
    else
        echo "✓ xbindkeys force stopped"
    fi
fi

# Test that keys are working normally
echo ""
echo "Testing key restoration..."
echo "Keys Z, X, and I should now work normally for typing."
echo ""

# Optional: Show what was removed
echo "Summary of changes reverted:"
echo "  - Z key: Restored to normal typing (was: Chromium back navigation)"
echo "  - X key: Restored to normal typing (was: Chromium forward navigation)"
echo "  - I key: Restored to normal typing (was: Toggle PDF invoice viewer)"
echo "  - Escape key: Restored to normal function (was: Close PDF viewer)"
echo ""

# Final verification
echo "Verification:"
if [ ! -f "$HOME/.xbindkeysrc" ]; then
    echo "✓ Configuration file removed"
else
    echo "❌ Configuration file still exists"
fi

if [ ! -f "$AUTOSTART_FILE" ]; then
    echo "✓ Autostart entry removed"
else
    echo "❌ Autostart entry still exists"
fi

if ! pgrep xbindkeys > /dev/null; then
    echo "✓ xbindkeys not running"
else
    echo "❌ xbindkeys still running"
fi

echo ""
echo "🎉 POS hotkeys removal complete!"
echo ""
echo "Your keyboard keys Z, X, and I are now restored to normal function."
echo "The hotkeys will not start automatically on next boot."
echo ""
echo "If you backed up your configuration, it's saved as ~/.xbindkeysrc.backup"
echo "You can restore hotkeys later by renaming it back to ~/.xbindkeysrc and running 'xbindkeys'"
