#!/bin/bash
# POS Hotkey Helper for XFCE + Chromium Kiosk
echo "installing requirements"
sudo apt install xdotool wmctrl inotify-tools evince xbindkeys

# CONFIG
DOWNLOADS_DIR="$HOME/Downloads"       # Where invoices are saved
VIEWER="evince"                        # PDF viewer
KIOSK_WINDOW="Chromium"                # Window title to target

# Function to send back/forward to Chromium
send_back() {
    xdotool search --name "$KIOSK_WINDOW" windowactivate --sync key "Alt+Left"
}
send_forward() {
    xdotool search --name "$KIOSK_WINDOW" windowactivate --sync key "Alt+Right"
}

# Function to show most recent invoice
show_invoice() {
    latest_file=$(ls -t "$DOWNLOADS_DIR" | head -n 1)
    if [ -z "$latest_file" ]; then
        echo "No invoice found."
        return
    fi
    "$VIEWER" "$DOWNLOADS_DIR/$latest_file" &
    VIEWER_PID=$!
}

# Function to close invoice
close_invoice() {
    if [ -n "$VIEWER_PID" ]; then
        kill "$VIEWER_PID" 2>/dev/null
        VIEWER_PID=""
    else
        pkill -x "$VIEWER"
    fi
}

# Launch xbindkeys config
cat > "$HOME/.xbindkeysrc" <<EOL
# Back: Left Arrow
"bash -c 'send_back'"
   Left

# Forward: Right Arrow
"bash -c 'send_forward'"
   Right

# Back: Z key
"bash -c 'send_back'"
   z

# Forward: X key
"bash -c 'send_forward'"
   x

# Show/Hide Invoice: I key
"bash -c 'if [ -z "\$VIEWER_PID" ]; then show_invoice; else close_invoice; fi'"
   i

# Close Invoice: Esc key
"bash -c 'close_invoice'"
   Escape
EOL

# Start xbindkeys in background
xbindkeys
echo "Hotkey listener started."
