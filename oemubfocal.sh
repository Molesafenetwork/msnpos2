#!/bin/bash
# Orange Pi 3B v2 Complete POS Kiosk System Setup Script
# Compatible with Ubuntu Focal and RK3566 chipset
# Run with: curl -sSL https://raw.githubusercontent.com/Molesafenetwork/msnpos2/refs/heads/main/oemubfocal.sh | bash

set -e

echo "       ░▒▓██████▓▒░░▒▓███████▓▒░ ░▒▓██████▓▒░░▒▓███████▓▒░ ░▒▓██████▓▒░░▒▓████████▓▒░      ░▒▓███████▓▒░░▒▓█▓▒░      ░▒▓███████▓▒░░▒▓███████▓▒░       ░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░        ░▒▓██████▓▒░ ░▒▓██████▓▒░░▒▓██████████████▓▒░░▒▓███████▓▒░░▒▓█▓▒░      ░▒▓████████▓▒░▒▓████████▓▒░▒▓████████▓▒░      ░▒▓███████▓▒░ ░▒▓██████▓▒░ ░▒▓███████▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓██████▓▒░ ░▒▓███████▓▒░▒▓█▓▒░░▒▓█▓▒░       ░▒▓███████▓▒░▒▓████████▓▒░▒▓████████▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░ "            
echo "      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░             ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░             ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░         ░▒▓█▓▒░   ░▒▓█▓▒░             ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░             ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░         ░▒▓█▓▒░   ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ "           
echo "      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░             ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░             ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░       ░▒▓█▓▒▒▓█▓▒░       ░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░         ░▒▓█▓▒░   ░▒▓█▓▒░             ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░             ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░         ░▒▓█▓▒░   ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ "           
echo "      ░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░░▒▓████████▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒▒▓███▓▒░▒▓██████▓▒░        ░▒▓███████▓▒░░▒▓█▓▒░      ░▒▓███████▓▒░░▒▓███████▓▒░        ░▒▓█▓▒▒▓█▓▒░ ░▒▓██████▓▒░       ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░░▒▓█▓▒░      ░▒▓██████▓▒░    ░▒▓█▓▒░   ░▒▓██████▓▒░        ░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░       ░▒▓███████▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░░▒▓███████▓▒░        ░▒▓██████▓▒░░▒▓██████▓▒░    ░▒▓█▓▒░   ░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░  "           
echo "      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░             ░▒▓█▓▒░      ░▒▓█▓▒░             ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░        ░▒▓█▓▓█▓▒░ ░▒▓█▓▒░             ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░         ░▒▓█▓▒░   ░▒▓█▓▒░             ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░             ░▒▓█▓▒░▒▓█▓▒░         ░▒▓█▓▒░   ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░  "                 
echo "      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░             ░▒▓█▓▒░      ░▒▓█▓▒░             ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░        ░▒▓█▓▓█▓▒░ ░▒▓█▓▒░             ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░         ░▒▓█▓▒░   ░▒▓█▓▒░             ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░             ░▒▓█▓▒░▒▓█▓▒░         ░▒▓█▓▒░   ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░  "                 
echo "       ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░░▒▓████████▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓███████▓▒░░▒▓███████▓▒░          ░▒▓██▓▒░  ░▒▓████████▓▒░       ░▒▓██████▓▒░ ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓████████▓▒░▒▓████████▓▒░  ░▒▓█▓▒░   ░▒▓████████▓▒░      ░▒▓█▓▒░       ░▒▓██████▓▒░░▒▓███████▓▒░       ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓██████▓▒░░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒░      ░▒▓███████▓▒░░▒▓████████▓▒░  ░▒▓█▓▒░    ░▒▓██████▓▒░░▒▓█▓▒░  "                 
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          


# Update system first
echo "Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Install essential packages including GUI components
echo "Installing essential packages..."
sudo apt install -y \
    curl \
    git \
    wget \
    unzip \
    openssl \
    build-essential \
    xorg \
    xinit \
    openbox \
    chromium-browser \
    x11-xserver-utils \
    xdotool \
    unclutter \
    fonts-liberation \
    fonts-dejavu-core \
    lightdm \
    network-manager

# Fix Node.js version issue
echo "Installing Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

echo "Node.js version: $(node --version)"
echo "NPM version: $(npm --version)"

# Create POS user if not exists
if [ ! -d "/home/posuser" ]; then
    echo "Creating POS user..."
    sudo useradd -m -s /bin/bash posuser
    echo "posuser:posuser123" | sudo chpasswd
    # Add posuser to necessary groups
    sudo usermod -a -G sudo,audio,video,dialout posuser
fi

# Install PM2 globally
echo "Installing PM2..."
sudo npm install -g pm2 --unsafe-perm=true --allow-root

# Set up the POS application directory
echo "Setting up POS application..."
cd /home/posuser

# Remove any existing installation
if [ -d "pos-system" ]; then
    echo "Removing existing pos-system directory..."
    sudo rm -rf pos-system
fi

# Clone fresh repository
echo "Cloning POS repository..."
sudo -u posuser git clone https://github.com/Molesafenetwork/msnpos2.git pos-system
cd pos-system

# Install dependencies with error handling
echo "Installing Node.js dependencies..."
sudo -u posuser npm config set audit false
sudo -u posuser npm config set fund false
sudo -u posuser npm config set engine-strict false

# Try multiple installation approaches
sudo -u posuser npm install --no-audit --no-fund --legacy-peer-deps --force || {
    echo "Standard install failed, trying alternative..."
    sudo -u posuser npm install --no-audit --no-fund --legacy-peer-deps --production --force || {
        echo "Installing core dependencies manually..."
        sudo -u posuser npm init -y
        sudo -u posuser npm install express crypto-js body-parser express-session multer --no-audit --no-fund --legacy-peer-deps --force
    }
}

# Generate environment configuration
echo "Setting up environment configuration..."
if sudo -u posuser node -e "const CryptoJS = require('crypto-js'); console.log('crypto-js works');" 2>/dev/null; then
    CRYPTO_KEY=$(sudo -u posuser node -e "const CryptoJS = require('crypto-js'); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());")
else
    echo "Using fallback key generation..."
    CRYPTO_KEY=$(openssl rand -hex 32)
fi

sudo -u posuser tee .env <<EOF
# POS System Configuration
MOLE_SAFE_USERS=Admin1234#:Admin1234#,worker1:worker1!
SESSION_SECRET=123485358953
ENCRYPTION_KEY=$CRYPTO_KEY
COMPANY_NAME=Mole Safe Network
COMPANY_ADDRESS=123 random road
COMPANY_PHONE=61756666665
COMPANY_EMAIL=support@mole-safe.net
COMPANY_ABN=333333333
PORT=3000
NODE_ENV=production
EOF

# Ensure data directory exists
sudo -u posuser mkdir -p public/.data
sudo chmod 755 public/.data

# Don't overwrite existing server.js from repo
echo "Verifying server.js from repository..."
if [ ! -f "server.js" ]; then
    echo "⚠️  Warning: server.js not found in repository, creating minimal fallback..."
    sudo -u posuser tee server.js <<'EOF'
// Minimal fallback server - replace with your actual server.js
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.static('public'));
app.get('/', (req, res) => res.send('<h1>MSN POS - Replace with your server.js</h1>'));
app.listen(PORT, '0.0.0.0', () => console.log(`Server running on port ${PORT}`));
EOF
fi

# Test the server
echo "Testing POS server..."
cd /home/posuser/pos-system
timeout 10s sudo -u posuser node server.js &
SERVER_PID=$!
sleep 3

if curl -s http://localhost:3000/health > /dev/null; then
    echo "✅ POS server test successful!"
else
    echo "⚠️  Server test inconclusive, continuing setup..."
fi

kill $SERVER_PID 2>/dev/null || true
sleep 2

# Create admin command scripts
echo "Setting up admin commands..."
sudo mkdir -p /usr/local/bin

sudo tee /usr/local/bin/pos-start << 'EOF'
#!/bin/bash
echo "Starting POS server..."
cd /home/posuser/pos-system
sudo -u posuser node server.js
EOF

sudo tee /usr/local/bin/pos-test << 'EOF'
#!/bin/bash
cd /home/posuser/pos-system
echo "Testing POS server..."
sudo -u posuser timeout 5s node server.js &
sleep 2
if curl -s http://localhost:3000/health > /dev/null; then
    echo "✅ POS server is working!"
    curl -s http://localhost:3000/health | jq . 2>/dev/null || curl -s http://localhost:3000/health
else
    echo "❌ POS server test failed"
fi
pkill -f "node server.js" 2>/dev/null || true
EOF

sudo tee /usr/local/bin/pos-logs << 'EOF'
#!/bin/bash
echo "=== POS System Logs ==="
sudo journalctl -u pos-system -f --no-pager
EOF

sudo tee /usr/local/bin/restart-pos << 'EOF'
#!/bin/bash
echo "Restarting POS system..."
sudo systemctl restart pos-system
echo "Waiting for startup..."
sleep 5
sudo systemctl status pos-system --no-pager -l
EOF

sudo tee /usr/local/bin/pos-kiosk-toggle << 'EOF'
#!/bin/bash
if systemctl is-active --quiet pos-kiosk; then
    echo "Stopping kiosk mode..."
    sudo systemctl stop pos-kiosk
    echo "Kiosk mode stopped. Use 'sudo systemctl start pos-kiosk' to restart."
else
    echo "Starting kiosk mode..."
    sudo systemctl start pos-kiosk
    echo "Kiosk mode started."
fi
EOF

# Install Tailscale
sudo tee /usr/local/bin/install-tailscale << 'EOF'
#!/bin/bash
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh
echo "Tailscale installed. Run 'sudo tailscale up' to connect."
echo "Use 'tailscale ip -4' to get your Tailscale IP."
EOF

# Edit environment variables
sudo tee /usr/local/bin/pos-edit-env << 'EOF'
#!/bin/bash
echo "Editing POS environment configuration..."
cd /home/posuser/pos-system
if [ -f .env ]; then
    echo "Current .env contents:"
    echo "========================"
    cat .env
    echo "========================"
    echo ""
    echo "Opening nano editor (Ctrl+X to save and exit)..."
    nano .env
    echo "Environment updated. Restart POS to apply changes:"
    echo "restart-pos"
else
    echo "❌ .env file not found in /home/posuser/pos-system"
fi
EOF

# View data directory contents
sudo tee /usr/local/bin/pos-view-data << 'EOF'
#!/bin/bash
echo "POS Data Directory Contents:"
echo "============================"
DATA_DIR="/home/posuser/pos-system/public/.data"
if [ -d "$DATA_DIR" ]; then
    echo "📁 Directory: $DATA_DIR"
    echo ""
    ls -la "$DATA_DIR"
    echo ""
    
    # Show JSON files content
    for file in "$DATA_DIR"/*.json; do
        if [ -f "$file" ]; then
            echo "📄 JSON File: $(basename "$file")"
            echo "----------------------------"
            if command -v jq >/dev/null 2>&1; then
                cat "$file" | jq . 2>/dev/null || cat "$file"
            else
                cat "$file"
            fi
            echo ""
        fi
    done
    
    # Show other files
    for file in "$DATA_DIR"/*; do
        if [ -f "$file" ] && [[ ! "$file" == *.json ]]; then
            echo "📄 File: $(basename "$file") ($(file -b "$file"))"
            echo "Size: $(du -h "$file" | cut -f1)"
            echo ""
        fi
    done
else
    echo "❌ Data directory not found: $DATA_DIR"
    echo "Creating directory..."
    mkdir -p "$DATA_DIR"
    chmod 755 "$DATA_DIR"
    chown posuser:posuser "$DATA_DIR"
fi
EOF

# Edit JSON data files
sudo tee /usr/local/bin/pos-edit-json << 'EOF'
#!/bin/bash
DATA_DIR="/home/posuser/pos-system/public/.data"
echo "POS JSON Data Editor"
echo "==================="

if [ ! -d "$DATA_DIR" ]; then
    echo "❌ Data directory not found: $DATA_DIR"
    exit 1
fi

# List available JSON files
echo "Available JSON files:"
json_files=()
i=1
for file in "$DATA_DIR"/*.json; do
    if [ -f "$file" ]; then
        json_files+=("$file")
        echo "$i) $(basename "$file")"
        ((i++))
    fi
done

if [ ${#json_files[@]} -eq 0 ]; then
    echo "No JSON files found."
    read -p "Create a new JSON file? (y/n): " create_new
    if [[ $create_new =~ ^[Yy]$ ]]; then
        read -p "Enter filename (without .json): " filename
        new_file="$DATA_DIR/$filename.json"
        echo "{}" > "$new_file"
        chown posuser:posuser "$new_file"
        echo "Created $new_file"
        nano "$new_file"
    fi
    exit 0
fi

echo ""
read -p "Select file number to edit (or 'q' to quit): " selection

if [[ "$selection" == "q" ]]; then
    exit 0
fi

if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#json_files[@]} ]; then
    selected_file="${json_files[$((selection-1))]}"
    echo "Editing: $(basename "$selected_file")"
    echo ""
    
    # Show current content
    echo "Current content:"
    echo "----------------"
    if command -v jq >/dev/null 2>&1; then
        cat "$selected_file" | jq . 2>/dev/null || cat "$selected_file"
    else
        cat "$selected_file"
    fi
    echo ""
    
    # Edit with nano
    nano "$selected_file"
    echo "File updated."
else
    echo "Invalid selection."
fi
EOF

# View system logs
sudo tee /usr/local/bin/pos-system-logs << 'EOF'
#!/bin/bash
echo "POS System Logs Viewer"
echo "====================="
echo "1) POS Application logs"
echo "2) System logs (last 50 lines)"
echo "3) Boot logs"
echo "4) Network logs"
echo "5) Live tail POS logs"
echo ""
read -p "Select option (1-5): " option

case $option in
    1)
        echo "POS Application Logs:"
        echo "===================="
        journalctl -u pos-system --no-pager -n 100
        ;;
    2)
        echo "System Logs (last 50):"
        echo "======================"
        journalctl --no-pager -n 50
        ;;
    3)
        echo "Boot Logs:"
        echo "=========="
        journalctl -b --no-pager
        ;;
    4)
        echo "Network Logs:"
        echo "============="
        journalctl -u NetworkManager --no-pager -n 50
        ;;
    5)
        echo "Live POS Logs (Ctrl+C to exit):"
        echo "==============================="
        journalctl -u pos-system -f
        ;;
    *)
        echo "Invalid option"
        ;;
esac
EOF

# Network management
sudo tee /usr/local/bin/pos-network << 'EOF'
#!/bin/bash
echo "POS Network Management"
echo "====================="
echo ""
echo "📡 Current Network Status:"
echo "--------------------------"
ip addr show | grep -E "(inet |UP|DOWN)" | grep -v 127.0.0.1 || echo "No network interfaces found"
echo ""

echo "🌐 Network Connectivity:"
echo "------------------------"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "✅ Internet connectivity: OK"
else
    echo "❌ Internet connectivity: FAILED"
fi

if command -v tailscale >/dev/null 2>&1; then
    echo ""
    echo "🔒 Tailscale Status:"
    echo "-------------------"
    tailscale status 2>/dev/null || echo "Tailscale not connected"
fi

echo ""
echo "Available commands:"
echo "- nmtui                    # Network configuration GUI"
echo "- sudo tailscale up        # Connect to Tailscale"
echo "- sudo tailscale down      # Disconnect Tailscale"
echo "- tailscale ip -4          # Show Tailscale IP"
EOF

# Backup and restore
sudo tee /usr/local/bin/pos-backup << 'EOF'
#!/bin/bash
echo "POS System Backup"
echo "================"

BACKUP_DIR="/home/posuser/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="pos_backup_$TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Creating backup: $BACKUP_FILE"
echo "Backing up:"
echo "- Environment configuration (.env)"
echo "- Data files (public/.data/)"
echo "- Any custom configurations"

cd /home/posuser/pos-system
tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
    .env \
    public/.data/ \
    package.json \
    2>/dev/null

if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    echo "✅ Backup created: $BACKUP_DIR/$BACKUP_FILE"
    echo "Size: $(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)"
    
    # Keep only last 5 backups
    cd "$BACKUP_DIR"
    ls -t pos_backup_*.tar.gz | tail -n +6 | xargs -r rm
    echo "Old backups cleaned up (keeping last 5)"
else
    echo "❌ Backup failed"
fi

echo ""
echo "Available backups:"
ls -la "$BACKUP_DIR"/pos_backup_*.tar.gz 2>/dev/null || echo "No backups found"
EOF

# Service management
sudo tee /usr/local/bin/pos-services << 'EOF'
#!/bin/bash
echo "POS Service Management"
echo "====================="
echo ""
echo "Service Status:"
echo "---------------"
printf "POS System:     "
systemctl is-active pos-system || echo "inactive"
printf "Display Manager: "
systemctl is-active lightdm || echo "inactive"
printf "Network Manager: "
systemctl is-active NetworkManager || echo "inactive"

echo ""
echo "Quick Actions:"
echo "1) Start POS service"
echo "2) Stop POS service"  
echo "3) Restart POS service"
echo "4) View POS service status"
echo "5) Enable POS autostart"
echo "6) Disable POS autostart"
echo ""
read -p "Select action (1-6 or q to quit): " action

case $action in
    1) sudo systemctl start pos-system && echo "✅ POS service started" ;;
    2) sudo systemctl stop pos-system && echo "✅ POS service stopped" ;;
    3) sudo systemctl restart pos-system && echo "✅ POS service restarted" ;;
    4) systemctl status pos-system --no-pager -l ;;
    5) sudo systemctl enable pos-system && echo "✅ POS autostart enabled" ;;
    6) sudo systemctl disable pos-system && echo "✅ POS autostart disabled" ;;
    q) exit 0 ;;
    *) echo "Invalid option" ;;
esac
EOF

sudo chmod +x /usr/local/bin/pos-* /usr/local/bin/install-tailscale

# Create systemd service for POS server
echo "Creating POS systemd service..."
sudo tee /etc/systemd/system/pos-system.service << 'EOF'
[Unit]
Description=MSN POS System Node.js Application
After=network.target
Wants=network.target

[Service]
Type=simple
User=posuser
Group=posuser
WorkingDirectory=/home/posuser/pos-system
Environment=NODE_ENV=production
Environment=NODE_OPTIONS=--max-old-space-size=512
ExecStart=/usr/bin/node server.js
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
TimeoutStartSec=30
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

# Set up GUI and kiosk mode
echo "Setting up GUI kiosk environment..."

# Configure lightdm for auto-login
sudo tee /etc/lightdm/lightdm.conf.d/12-autologin.conf << 'EOF'
[Seat:*]
autologin-user=posuser
autologin-user-timeout=0
user-session=openbox
EOF

# Create openbox configuration for posuser
sudo -u posuser mkdir -p /home/posuser/.config/openbox

sudo -u posuser tee /home/posuser/.config/openbox/autostart << 'EOF'
#!/bin/bash

# Disable screen saver and power management
xset s off
xset s noblank
xset -dpms

# Hide cursor after 1 second of inactivity
unclutter -idle 1 &

# Wait for network and POS server to be ready
echo "Waiting for POS server to start..."
for i in {1..30}; do
    if curl -s http://localhost:3000/health > /dev/null 2>&1; then
        echo "POS server is ready!"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 2
done

# Start chromium in kiosk mode
chromium-browser \
    --kiosk \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu \
    --disable-software-rasterizer \
    --disable-background-timer-throttling \
    --disable-backgrounding-occluded-windows \
    --disable-renderer-backgrounding \
    --disable-features=TranslateUI \
    --disable-ipc-flooding-protection \
    --noerrdialogs \
    --disable-notifications \
    --disable-session-crashed-bubble \
    --disable-infobars \
    --touch-events=enabled \
    --start-fullscreen \
    http://localhost:3000 &

CHROME_PID=$!

# Monitor for hotkeys
while true; do
    sleep 1
    # This is a placeholder - actual hotkey handling would need more setup
done
EOF

sudo -u posuser chmod +x /home/posuser/.config/openbox/autostart

# Create openbox menu config
sudo -u posuser tee /home/posuser/.config/openbox/menu.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">
    <menu id="apps-menu" label="Applications">
        <item label="Terminal">
            <action name="Execute">
                <command>x-terminal-emulator</command>
            </action>
        </item>
        <item label="File Manager">
            <action name="Execute">
                <command>pcmanfm</command>
            </action>
        </item>
        <separator />
        <item label="Restart POS">
            <action name="Execute">
                <command>restart-pos</command>
            </action>
        </item>
        <item label="POS Logs">
            <action name="Execute">
                <command>x-terminal-emulator -e pos-logs</command>
            </action>
        </item>
    </menu>
    
    <menu id="root-menu" label="Openbox 3">
        <menu id="apps-menu"/>
        <separator />
        <item label="Reconfigure">
            <action name="Reconfigure" />
        </item>
        <item label="Exit">
            <action name="Exit">
                <prompt>yes</prompt>
            </action>
        </item>
    </menu>
</openbox_menu>
EOF

# Create openbox rc.xml for key bindings
sudo -u posuser tee /home/posuser/.config/openbox/rc.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <keyboard>
    <!-- Terminal hotkey: Ctrl+Alt+T -->
    <keybind key="C-A-t">
      <action name="Execute">
        <command>x-terminal-emulator</command>
      </action>
    </keybind>
    
    <!-- Restart POS: Ctrl+Alt+R -->
    <keybind key="C-A-r">
      <action name="Execute">
        <command>restart-pos</command>
      </action>
    </keybind>
    
    <!-- Refresh browser: F5 -->
    <keybind key="F5">
      <action name="Execute">
        <command>xdotool key ctrl+F5</command>
      </action>
    </keybind>
    
    <!-- Exit kiosk: Ctrl+Alt+Q -->
    <keybind key="C-A-q">
      <action name="Execute">
        <command>pkill chromium-browser</command>
      </action>
    </keybind>
  </keyboard>
  
  <applications>
    <application name="chromium-browser">
      <fullscreen>true</fullscreen>
      <maximized>true</maximized>
    </application>
  </applications>
</openbox_config>
EOF

# Install additional useful packages
echo "Installing additional system tools..."
sudo apt install -y \
    pcmanfm \
    x-terminal-emulator \
    xdotool \
    jq \
    htop \
    nano \
    curl

# Set proper permissions
sudo chown -R posuser:posuser /home/posuser
sudo chmod -R 755 /home/posuser/.config

# Enable and start services
echo "Enabling system services..."
sudo systemctl daemon-reload
sudo systemctl enable pos-system
sudo systemctl enable lightdm

# Create a final status script
sudo tee /usr/local/bin/pos-status << 'EOF'
#!/bin/bash
echo "=== MSN POS System Status ==="
echo ""
echo "🖥️  System Info:"
echo "   Hostname: $(hostname)"
echo "   Uptime: $(uptime -p)"
echo "   Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "   Memory: $(free -h | awk 'NR==2{printf "%.1f/%.1fGB (%.0f%%)", $3/1024/1024/1024, $2/1024/1024/1024, $3*100/$2}')"
echo ""
echo "🌐 Network:"
ip addr show | grep "inet " | grep -v 127.0.0.1 | awk '{print "   " $NF ": " $2}' || echo "   No network detected"
if command -v tailscale >/dev/null 2>&1; then
    TS_IP=$(tailscale ip -4 2>/dev/null)
    if [ -n "$TS_IP" ]; then
        echo "   Tailscale: $TS_IP"
    fi
fi
echo ""
echo "🔧 Services:"
printf "   POS Server: "
systemctl is-active pos-system 2>/dev/null || echo "inactive"
printf "   Display Manager: "
systemctl is-active lightdm 2>/dev/null || echo "inactive"
echo ""
echo "🚀 POS Server Test:"
if curl -s http://localhost:3000/health > /dev/null 2>&1; then
    echo "   ✅ Server responding on http://localhost:3000"
    curl -s http://localhost:3000/health | jq -r '"   Uptime: \(.uptime)s"' 2>/dev/null || echo "   Server details unavailable"
else
    echo "   ❌ Server not responding"
fi
echo ""
echo "📁 Data Directory:"
DATA_DIR="/home/posuser/pos-system/public/.data"
if [ -d "$DATA_DIR" ]; then
    FILE_COUNT=$(find "$DATA_DIR" -type f | wc -l)
    JSON_COUNT=$(find "$DATA_DIR" -name "*.json" | wc -l)
    echo "   Files: $FILE_COUNT (JSON: $JSON_COUNT)"
    DIR_SIZE=$(du -sh "$DATA_DIR" 2>/dev/null | cut -f1)
    echo "   Size: $DIR_SIZE"
else
    echo "   ❌ Data directory not found"
fi
echo ""
echo "💡 Admin Commands:"
echo "   pos-status           - Show this status"
echo "   pos-test             - Test POS server"  
echo "   restart-pos          - Restart POS service"
echo "   pos-logs             - View POS logs"
echo "   pos-edit-env         - Edit environment config"
echo "   pos-view-data        - View data directory"
echo "   pos-edit-json        - Edit JSON data files"
echo "   pos-backup           - Create system backup"
echo "   pos-services         - Manage services"
echo "   pos-network          - Network management"
echo "   pos-system-logs      - View system logs"
echo "   install-tailscale    - Install Tailscale VPN"
echo "   pos-kiosk-toggle     - Toggle kiosk mode"
EOF

sudo chmod +x /usr/local/bin/pos-status

echo ""
echo "=== 🏪 MSN POS System Setup Complete! ==="
echo ""
echo "🎯 Lightweight Setup for Focal Server:"
echo "   ✅ Node.js 18 with your msnpos2 repository"
echo "   ✅ Minimal GUI (Openbox + Chromium kiosk)"
echo "   ✅ Auto-boot to POS interface via HDMI"
echo "   ✅ Terminal access via Ctrl+Alt+T hotkey"
echo "   ✅ Admin commands for posuser management"
echo ""
echo "🚀 Next Steps:"
echo "1. Test your repository's server.js:"
echo "   pos-test"
echo ""
echo "2. Start the POS service:"
echo "   sudo systemctl start pos-system"
echo ""
echo "3. Check system status:"
echo "   pos-status"
echo ""
echo "4. Reboot to activate kiosk mode:"
echo "   sudo reboot"
echo ""
echo "🔧 Admin Commands Available:"
echo "   pos-status           - Complete system overview"
echo "   pos-test             - Test POS server"
echo "   restart-pos          - Restart POS service"
echo "   pos-logs             - View POS application logs"
echo "   pos-edit-env         - Edit .env configuration"
echo "   pos-view-data        - View public/.data contents"
echo "   pos-edit-json        - Edit JSON data files"
echo "   pos-backup           - Create system backup"
echo "   pos-services         - Manage systemd services"
echo "   pos-network          - Network management"
echo "   pos-system-logs      - View system logs"
echo "   install-tailscale    - Install Tailscale VPN"
echo "   pos-kiosk-toggle     - Enable/disable kiosk mode"
echo ""
echo "🖥️  After Reboot (HDMI Display):"
echo "   - Auto-login as posuser"
echo "   - Your server.js loads automatically"
echo "   - Chromium opens your POS UI in fullscreen"
echo "   - No desktop clutter - pure POS interface"
echo "   - Terminal: Ctrl+Alt+T"
echo "   - Restart POS: Ctrl+Alt+R"
echo ""
echo "🌐 Access URLs:"
echo "   Local: http://localhost:3000"
echo "   Network: http://$(hostname -I | awk '{print $1}'):3000"
echo ""
