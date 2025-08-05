#!/bin/bash
# Complete Node.js/NPM Cleanup Script
# Run this BEFORE the main POS setup script

set -e

echo "=== Complete Node.js/NPM Cleanup ==="
echo "Automatically removing all Node.js and NPM installations..."

# Stop any running POS services
echo "Stopping POS services..."
sudo systemctl stop pos-system pos-kiosk 2>/dev/null || true
sudo systemctl disable pos-system pos-kiosk 2>/dev/null || true

# Kill any running Node.js processes
echo "Killing Node.js processes..."
sudo pkill -f node 2>/dev/null || true
sudo pkill -f npm 2>/dev/null || true
sudo pkill -f pm2 2>/dev/null || true

# Remove system Node.js and NPM
echo "Removing system Node.js and NPM..."
sudo apt remove --purge -y nodejs npm node-gyp 2>/dev/null || true
sudo apt autoremove -y
sudo apt autoclean

# Remove Node.js repositories
echo "Removing Node.js repositories..."
sudo rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null || true
sudo rm -f /usr/share/keyrings/nodesource.gpg 2>/dev/null || true

# Clean up global npm directories
echo "Cleaning global npm directories..."
sudo rm -rf /usr/local/lib/node_modules 2>/dev/null || true
sudo rm -rf /usr/local/bin/npm 2>/dev/null || true
sudo rm -rf /usr/local/bin/npx 2>/dev/null || true
sudo rm -rf /usr/local/bin/node 2>/dev/null || true
sudo rm -rf /usr/local/bin/pm2 2>/dev/null || true
sudo rm -rf /opt/nodejs 2>/dev/null || true

# Clean up user-specific directories
echo "Cleaning user npm/node directories..."
sudo rm -rf /home/*/node_modules 2>/dev/null || true
sudo rm -rf /home/*/.npm 2>/dev/null || true
sudo rm -rf /home/*/.node-gyp 2>/dev/null || true
sudo rm -rf /home/*/.nvm 2>/dev/null || true
sudo rm -rf /home/*/.pm2 2>/dev/null || true
sudo rm -rf /root/.npm 2>/dev/null || true
sudo rm -rf /root/.node-gyp 2>/dev/null || true
sudo rm -rf /root/.nvm 2>/dev/null || true

# Clean up posuser specific directories
if id "posuser" &>/dev/null; then
    echo "Cleaning posuser directories..."
    sudo rm -rf /home/posuser/node_modules 2>/dev/null || true
    sudo rm -rf /home/posuser/.npm 2>/dev/null || true
    sudo rm -rf /home/posuser/.node-gyp 2>/dev/null || true
    sudo rm -rf /home/posuser/.nvm 2>/dev/null || true
    sudo rm -rf /home/posuser/.pm2 2>/dev/null || true
    sudo rm -rf /home/posuser/pos-system/node_modules 2>/dev/null || true
    sudo rm -rf /home/posuser/pos-system/package-lock.json 2>/dev/null || true
fi

# Remove any leftover binaries
echo "Removing leftover binaries..."
sudo find /usr/local/bin -name "*node*" -delete 2>/dev/null || true
sudo find /usr/local/bin -name "*npm*" -delete 2>/dev/null || true
sudo find /usr/local/bin -name "*pm2*" -delete 2>/dev/null || true

# Clean up systemd services
echo "Cleaning systemd services..."
sudo rm -f /etc/systemd/system/pos-system.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/pos-kiosk.service 2>/dev/null || true
sudo systemctl daemon-reload

# Remove custom commands that might reference old Node.js
echo "Cleaning custom commands..."
sudo rm -f /usr/local/bin/generate-key 2>/dev/null || true
sudo rm -f /usr/local/bin/edit-env 2>/dev/null || true
sudo rm -f /usr/local/bin/setup-tailnet 2>/dev/null || true
sudo rm -f /usr/local/bin/check-env 2>/dev/null || true
sudo rm -f /usr/local/bin/pdf-storage 2>/dev/null || true
sudo rm -f /usr/local/bin/pos-logs 2>/dev/null || true
sudo rm -f /usr/local/bin/restart-pos 2>/dev/null || true
sudo rm -f /usr/local/bin/admin-mode 2>/dev/null || true
sudo rm -f /usr/local/bin/start-pos-kiosk 2>/dev/null || true

# Clean environment variables from shell configs
echo "Cleaning shell configurations..."
if [ -f /home/posuser/.bashrc ]; then
    sudo sed -i '/NVM_DIR/d' /home/posuser/.bashrc 2>/dev/null || true
    sudo sed -i '/nvm.sh/d' /home/posuser/.bashrc 2>/dev/null || true
fi

# Clean any snap Node.js installations
echo "Removing snap Node.js..."
sudo snap remove node 2>/dev/null || true

# Update package database
echo "Updating package database..."
sudo apt update

# Clear any cached packages
echo "Clearing package cache..."
sudo apt clean
sudo apt autoremove -y

echo ""
echo "=== CLEANUP COMPLETE ==="
echo "All Node.js and NPM installations have been removed."
echo "You can now run the main POS setup script safely."
echo ""
echo "Recommended next steps:"
echo "1. Reboot the system: sudo reboot"
echo "2. Run the main POS setup script"
echo ""
echo "If you want to verify the cleanup:"
echo "  which node    (should return nothing)"
echo "  which npm     (should return nothing)"
echo "  which pm2     (should return nothing)"
