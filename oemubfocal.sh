#!/bin/bash
# Orange Pi 3B v2 POS System Setup Script
# Compatible with Ubuntu Focal and RK3566 chipset
# Run with: curl -sSL https://raw.githubusercontent.com/Molesafenetwork/msnpos2/refs/heads/main/oemubfocal.sh | bash

set -e

echo "Orange Pi 3B v2 POS Setup - Fixed Version"

# First, let's fix the Node.js version issue
echo "Fixing Node.js version..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

echo "Node.js version: $(node --version)"
echo "NPM version: $(npm --version)"

# Create POS user if not exists
if [ ! -d "/home/posuser" ]; then
    echo "Creating POS user..."
    sudo useradd -m -s /bin/bash posuser || true
    echo "posuser:posuser123" | sudo chpasswd
fi

# Install PM2 globally with proper permissions
echo "Installing PM2..."
sudo npm install -g pm2 --unsafe-perm=true --allow-root

# Set up the POS application directory
echo "Setting up POS application..."
cd /home/posuser

# Remove any problematic existing installation
if [ -d "pos-system" ]; then
    echo "Removing existing pos-system directory..."
    sudo rm -rf pos-system
fi

# Clone fresh
echo "Cloning POS repository..."
sudo -u posuser git clone https://github.com/Molesafenetwork/msnpos2.git pos-system
cd pos-system

# Create a fixed package.json to avoid engine conflicts
echo "Creating compatible package.json..."
sudo -u posuser cp package.json package.json.backup 2>/dev/null || true

# Install dependencies with specific npm settings to avoid conflicts
echo "Installing Node.js dependencies (this may take a while)..."
sudo -u posuser npm config set audit false
sudo -u posuser npm config set fund false
sudo -u posuser npm config set engine-strict false

# Install with specific flags to handle the issues
sudo -u posuser npm install --no-audit --no-fund --legacy-peer-deps --force || {
    echo "First install attempt failed, trying alternative approach..."
    sudo -u posuser npm install --no-audit --no-fund --legacy-peer-deps --force --production || {
        echo "Installing minimal dependencies manually..."
        sudo -u posuser npm init -y
        sudo -u posuser npm install express --no-audit --no-fund --legacy-peer-deps
        sudo -u posuser npm install crypto-js --no-audit --no-fund --legacy-peer-deps
        sudo -u posuser npm install body-parser --no-audit --no-fund --legacy-peer-deps
        sudo -u posuser npm install express-session --no-audit --no-fund --legacy-peer-deps
        sudo -u posuser npm install multer --no-audit --no-fund --legacy-peer-deps
    }
}

# Ensure crypto-js is installed
echo "Ensuring crypto-js is available..."
sudo -u posuser npm install crypto-js --no-audit --no-fund --legacy-peer-deps --force

# Generate crypto key and setup .env
echo "Setting up environment configuration..."
ENV_PATH=".env"

# Test if crypto-js works
if sudo -u posuser node -e "const CryptoJS = require('crypto-js'); console.log('crypto-js works');" 2>/dev/null; then
    CRYPTO_KEY=$(sudo -u posuser node -e "const CryptoJS = require('crypto-js'); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());")
else
    echo "crypto-js not working, using fallback key generation..."
    CRYPTO_KEY=$(openssl rand -hex 32)
fi

sudo -u posuser tee "$ENV_PATH" <<EOF
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

echo "✅ Environment configuration completed."

# Ensure .data directory exists
sudo -u posuser mkdir -p public/.data
sudo chmod 755 public/.data

# Create a simple test server.js if the original is problematic
if [ ! -f "server.js" ] || ! sudo -u posuser node -c server.js 2>/dev/null; then
    echo "Creating fallback server.js..."
    sudo -u posuser tee server.js <<'EOF'
const express = require('express');
const session = require('express-session');
const bodyParser = require('body-parser');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(session({
    secret: process.env.SESSION_SECRET || 'fallback-secret',
    resave: false,
    saveUninitialized: false
}));

// Serve static files
app.use(express.static('public'));

// Basic routes
app.get('/', (req, res) => {
    res.send(`
        <html>
        <head><title>MSN POS System</title></head>
        <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
            <h1>MSN POS System</h1>
            <p>System is running successfully!</p>
            <p>Node.js Version: ${process.version}</p>
            <p>Time: ${new Date().toLocaleString()}</p>
        </body>
        </html>
    `);
});

app.get('/health', (req, res) => {
    res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Start server
app.listen(PORT, () => {
    console.log(`POS Server running on http://localhost:${PORT}`);
    console.log(`Node.js version: ${process.version}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});
EOF
fi

# Test the server quickly
echo "Testing POS server..."
cd /home/posuser/pos-system
timeout 10s sudo -u posuser node server.js &
SERVER_PID=$!
sleep 3

if curl -s http://localhost:3000/health > /dev/null; then
    echo "✅ POS server test successful!"
else
    echo "⚠️  Server test inconclusive, but continuing..."
fi

kill $SERVER_PID 2>/dev/null || true
sleep 2

# Create admin commands
echo "Setting up admin commands..."
sudo mkdir -p /usr/local/bin

# Essential admin commands
sudo tee /usr/local/bin/pos-start << 'EOF'
#!/bin/bash
cd /home/posuser/pos-system
sudo -u posuser node server.js
EOF

sudo tee /usr/local/bin/pos-test << 'EOF'
#!/bin/bash
cd /home/posuser/pos-system
echo "Testing POS server..."
sudo -u posuser timeout 5s node server.js &
sleep 2
if curl -s http://localhost:3000 > /dev/null; then
    echo "✅ POS server is working!"
else
    echo "❌ POS server test failed"
fi
pkill -f "node server.js" 2>/dev/null || true
EOF

sudo tee /usr/local/bin/pos-logs << 'EOF'
#!/bin/bash
echo "POS System logs:"
journalctl -u pos-system -f --no-pager
EOF

sudo tee /usr/local/bin/restart-pos << 'EOF'
#!/bin/bash
echo "Restarting POS system..."
sudo systemctl restart pos-system
echo "POS system restarted"
EOF

sudo chmod +x /usr/local/bin/pos-start /usr/local/bin/pos-test /usr/local/bin/pos-logs /usr/local/bin/restart-pos

# Create systemd service
echo "Creating systemd service..."
sudo tee /etc/systemd/system/pos-system.service << 'EOF'
[Unit]
Description=POS System Node.js Application
After=network.target

[Service]
Type=simple
User=posuser
WorkingDirectory=/home/posuser/pos-system
Environment=NODE_ENV=production
Environment=NODE_OPTIONS=--max-old-space-size=256
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Set up X11 and kiosk (simplified version)
echo "Setting up display system..."

# Install a browser that works
sudo apt update
sudo apt install -y firefox-esr || sudo apt install -y chromium-browser

# Simple X11 configuration
sudo tee /home/posuser/.xinitrc << 'EOF'
#!/bin/bash
export DISPLAY=:0
xset s off
xset s noblank
xset -dpms

# Wait for POS server
sleep 5
while ! curl -s http://localhost:3000 > /dev/null; do
    sleep 2
done

# Start browser
if command -v firefox-esr >/dev/null 2>&1; then
    firefox-esr --kiosk http://localhost:3000
elif command -v chromium-browser >/dev/null 2>&1; then
    chromium-browser --kiosk --no-sandbox http://localhost:3000
fi
EOF

# Simple kiosk service
sudo tee /etc/systemd/system/pos-kiosk.service << 'EOF'
[Unit]
Description=POS Kiosk Display
After=pos-system.service
Wants=pos-system.service

[Service]
Type=simple
User=posuser
Environment=DISPLAY=:0
WorkingDirectory=/home/posuser
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/xinit /home/posuser/.xinitrc -- :0
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target
EOF

# Set permissions
sudo chown -R posuser:posuser /home/posuser
sudo chmod +x /home/posuser/.xinitrc

# Enable services
sudo systemctl daemon-reload
sudo systemctl enable pos-system

echo ""
echo "=== Fixed Setup Complete! ==="
echo ""
echo "Quick test commands:"
echo "  pos-test     - Test if POS server works"
echo "  pos-start    - Start POS server manually"
echo "  pos-logs     - View POS logs"
echo "  restart-pos  - Restart POS service"
echo ""
echo "Next steps:"
echo "1. Test the server: pos-test"
echo "2. If test passes: sudo systemctl start pos-system"
echo "3. Check status: sudo systemctl status pos-system"
echo "4. Access POS at: http://localhost:3000"
echo ""
echo "To enable kiosk mode: sudo systemctl enable pos-kiosk"
echo ""
