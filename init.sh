#!/bin/bash
# curl -sSL https://raw.githubusercontent.com/Molesafenetwork/msnpos2/main/init.sh | bash


# Variables
SCRIPT_URL="https://raw.githubusercontent.com/Molesafenetwork/msnpos2/main/nodestart.sh"
DESKTOP_SCRIPT="$HOME/Desktop/nodestart.sh"

echo "Downloading POS Startup Script to Desktop..."
mkdir -p "$HOME/Desktop"
curl -sSL "$SCRIPT_URL" -o "$DESKTOP_SCRIPT"

if [ ! -f "$DESKTOP_SCRIPT" ]; then
    echo "Download failed. Check your internet or URL."
    exit 1
fi

chmod +x "$DESKTOP_SCRIPT"
echo "Script saved to Desktop as nodestart.sh"

echo
echo "Launching script..."
bash "$DESKTOP_SCRIPT"
