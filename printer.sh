#!/bin/bash

# Canon Printer Setup Script for Orange Pi 3B Ubuntu Focal
# This script installs CUPS and Canon printer drivers

set -e  # Exit on any error

echo "=== Canon Printer Setup for Orange Pi 3B ==="
echo "This script will install CUPS and Canon printer drivers"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "Please don't run this script as root. Run as regular user."
   exit 1
fi

# Update package list
echo "Updating package list..."
sudo apt update

# Install CUPS and related packages
echo "Installing CUPS printing system..."
sudo apt install -y cups cups-client cups-bsd cups-filters

# Install additional printer drivers
echo "Installing printer drivers..."
sudo apt install -y printer-driver-gutenprint
sudo apt install -y hplip-gui  # Has some Canon support too
sudo apt install -y cups-pdf  # For PDF printing capability

# Install Canon-specific drivers if available
echo "Installing Canon printer drivers..."
sudo apt install -y printer-driver-c2esp || echo "C2ESP driver not available"
sudo apt install -y printer-driver-cjet || echo "Canon BJC driver not available"

# Try to install Canon IJ drivers from Ubuntu repos
sudo apt install -y cnijfilter-common || echo "Canon IJ filter not in repos"

# Enable and start CUPS service
echo "Enabling CUPS service..."
sudo systemctl enable cups
sudo systemctl start cups

# Add user to lpadmin group for printer management
echo "Adding user to lpadmin group..."
sudo usermod -a -G lpadmin $USER

# Configure CUPS to allow local network access (optional)
echo "Configuring CUPS..."
sudo sed -i 's/Listen localhost:631/Listen 631/' /etc/cups/cupsd.conf || true
sudo sed -i '/<Location \/>/,/<\/Location>/ s/Order allow,deny/Order deny,allow/' /etc/cups/cupsd.conf || true
sudo sed -i '/<Location \/>/,/<\/Location>/ s/Allow localhost/Allow all/' /etc/cups/cupsd.conf || true

# Restart CUPS to apply configuration
sudo systemctl restart cups

# Install additional drivers that work well with TS3400 series
echo "Installing additional drivers for TS3400 compatibility..."
sudo apt install -y system-config-printer || echo "system-config-printer not available"

# Check USB devices
echo ""
echo "Checking for USB devices..."
lsusb | grep -i canon || echo "No Canon devices found via USB"
echo "Looking specifically for TS3400..."
lsusb | grep -E "(04a9|Canon)" || echo "No Canon devices detected"

# Check if printer is detected
echo ""
echo "Checking for detected printers..."
lpstat -p 2>/dev/null || echo "No printers configured yet"

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Next steps:"
echo "1. Connect your Canon printer via USB cable"
echo "2. Open a web browser and go to http://localhost:631"
echo "3. Go to Administration > Add Printer"
echo "4. Your printer should appear in the local printers list"
echo "5. Follow the web interface to complete setup"
echo ""
echo "Alternative command line setup for TS3400:"
echo "- Run 'sudo lpadmin -p CanonTS3400 -E -v usb://Canon/TS3400%20series'"
echo "- Or try: 'sudo lpadmin -p CanonTS3400 -E -v usb://Canon/TS3420'"
echo ""
echo "Troubleshooting:"
echo "- Check 'lsusb' to see if printer is detected"
echo "- Check 'dmesg | tail' after plugging in printer"
echo "- Restart the system and try again if needed"
echo ""
echo "Note: You may need to log out and back in for group changes to take effect."
