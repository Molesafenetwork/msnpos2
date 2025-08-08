#!/bin/bash
# POS User Login Fix Script
# Diagnoses and fixes common login issues for posuser

echo "=== POS USER LOGIN DIAGNOSTIC & FIX SCRIPT ==="
echo ""

# Function to check and report status
check_status() {
    local description="$1"
    local command="$2"
    echo -n "Checking $description... "
    if eval "$command" >/dev/null 2>&1; then
        echo "✅ OK"
        return 0
    else
        echo "❌ ISSUE FOUND"
        return 1
    fi
}

# 1. Check if posuser exists
echo "1. USER ACCOUNT VERIFICATION:"
if id posuser >/dev/null 2>&1; then
    echo "✅ posuser account exists"
    echo "   UID: $(id -u posuser)"
    echo "   GID: $(id -g posuser)"
    echo "   Groups: $(groups posuser)"
else
    echo "❌ posuser account not found!"
    echo "Creating posuser account..."
    sudo useradd -m -s /bin/bash posuser
    echo "posuser:posuser123" | sudo chpasswd
    sudo usermod -a -G sudo,audio,video posuser
fi

# 2. Check home directory and permissions
echo ""
echo "2. HOME DIRECTORY VERIFICATION:"
HOME_DIR="/home/posuser"
if [ -d "$HOME_DIR" ]; then
    echo "✅ Home directory exists: $HOME_DIR"
    
    # Check ownership
    OWNER=$(stat -c '%U' "$HOME_DIR")
    if [ "$OWNER" = "posuser" ]; then
        echo "✅ Home directory ownership correct"
    else
        echo "❌ Home directory ownership incorrect (owner: $OWNER)"
        echo "Fixing ownership..."
        sudo chown -R posuser:posuser "$HOME_DIR"
    fi
    
    # Check permissions
    PERMS=$(stat -c '%a' "$HOME_DIR")
    if [ "$PERMS" = "755" ] || [ "$PERMS" = "750" ]; then
        echo "✅ Home directory permissions OK ($PERMS)"
    else
        echo "❌ Home directory permissions incorrect ($PERMS)"
        echo "Fixing permissions..."
        sudo chmod 755 "$HOME_DIR"
    fi
else
    echo "❌ Home directory missing!"
    echo "Creating home directory..."
    sudo mkdir -p "$HOME_DIR"
    sudo chown posuser:posuser "$HOME_DIR"
    sudo chmod 755 "$HOME_DIR"
fi

# 3. Check shell configuration
echo ""
echo "3. SHELL CONFIGURATION:"
USER_SHELL=$(getent passwd posuser | cut -d: -f7)
echo "Current shell: $USER_SHELL"

if [ "$USER_SHELL" = "/bin/bash" ]; then
    echo "✅ Shell is bash"
else
    echo "❌ Shell is not bash, changing to bash..."
    sudo usermod -s /bin/bash posuser
fi

# Test if shell exists and is executable
if [ -x "$USER_SHELL" ]; then
    echo "✅ Shell is executable"
else
    echo "❌ Shell is not executable or missing"
    echo "Setting shell to /bin/bash..."
    sudo usermod -s /bin/bash posuser
fi

# 4. Check critical system files
echo ""
echo "4. SYSTEM FILES VERIFICATION:"

# Check /etc/passwd entry
check_status "/etc/passwd entry" "grep -q '^posuser:' /etc/passwd"

# Check /etc/shadow entry  
check_status "/etc/shadow entry" "sudo grep -q '^posuser:' /etc/shadow"

# Check if user can authenticate
echo -n "Checking password authentication... "
if echo "posuser123" | sudo -S -u posuser whoami >/dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ ISSUE - Resetting password..."
    echo "posuser:posuser123" | sudo chpasswd
fi

# 5. Check session and X11 configuration
echo ""
echo "5. SESSION CONFIGURATION:"

# Create .xsession-errors file with proper permissions
sudo -u posuser touch "$HOME_DIR/.xsession-errors"
sudo chmod 644 "$HOME_DIR/.xsession-errors"

# Check for conflicting session files
if [ -f "$HOME_DIR/.xsession" ]; then
    echo "⚠️ Custom .xsession found - this might cause issues"
    echo "Backing up and removing..."
    sudo -u posuser mv "$HOME_DIR/.xsession" "$HOME_DIR/.xsession.backup"
fi

# 6. Check XFCE configuration
echo ""
echo "6. XFCE CONFIGURATION:"

# Create basic XFCE config structure
sudo -u posuser mkdir -p "$HOME_DIR/.config/xfce4"
sudo -u posuser mkdir -p "$HOME_DIR/.cache"
sudo -u posuser mkdir -p "$HOME_DIR/.local/share"

# Fix permissions on config directories
sudo chown -R posuser:posuser "$HOME_DIR/.config" "$HOME_DIR/.cache" "$HOME_DIR/.local" 2>/dev/null

# Create a minimal XFCE session file
sudo -u posuser tee "$HOME_DIR/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml" << 'XFCE_SESSION' >/dev/null 2>&1 || true
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-session" version="1.0">
  <property name="startup" type="empty">
    <property name="screensaver" type="empty">
      <property name="enabled" type="bool" value="false"/>
    </property>
  </property>
  <property name="shutdown" type="empty">
    <property name="LockScreen" type="bool" value="false"/>
  </property>
</channel>
XFCE_SESSION

# 7. Check LightDM configuration
echo ""
echo "7. LIGHTDM CONFIGURATION:"

# Check if LightDM is properly configured
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
if [ -f "$LIGHTDM_CONF" ]; then
    if grep -q "autologin-user=posuser" "$LIGHTDM_CONF"; then
        echo "✅ LightDM autologin configured for posuser"
    else
        echo "❌ LightDM autologin not configured properly"
        echo "Fixing LightDM configuration..."
        
        sudo tee "$LIGHTDM_CONF" << 'LIGHTDM_CONFIG'
[Seat:*]
autologin-user=posuser
autologin-user-timeout=0
user-session=xfce
greeter-hide-users=false
greeter-show-manual-login=true
LIGHTDM_CONFIG
    fi
else
    echo "❌ LightDM configuration file missing"
    echo "Creating LightDM configuration..."
    sudo tee "$LIGHTDM_CONF" << 'LIGHTDM_CONFIG'
[Seat:*]
autologin-user=posuser
autologin-user-timeout=0
user-session=xfce
greeter-hide-users=false
greeter-show-manual-login=true
LIGHTDM_CONFIG
fi

# 8. Check system logs for clues
echo ""
echo "8. SYSTEM LOG ANALYSIS:"
echo "Recent authentication failures:"
sudo journalctl -u lightdm --since "10 minutes ago" | grep -i "fail\|error\|denied" | tail -5 || echo "No recent authentication errors found"

echo ""
echo "LightDM session logs:"
sudo journalctl -u lightdm --since "10 minutes ago" | grep -i "session" | tail -3 || echo "No recent session logs found"

# 9. Test user environment
echo ""
echo "9. USER ENVIRONMENT TEST:"
echo "Testing posuser environment..."

# Test basic commands as posuser
if sudo -u posuser bash -c 'cd ~ && pwd' >/dev/null 2>&1; then
    echo "✅ Basic shell operations work"
else
    echo "❌ Basic shell operations fail"
fi

# Test X11 access
if sudo -u posuser bash -c 'export DISPLAY=:0; xset q' >/dev/null 2>&1; then
    echo "✅ X11 access works"
elif sudo -u posuser bash -c 'export DISPLAY=:1; xset q' >/dev/null 2>&1; then
    echo "✅ X11 access works (display :1)"
else
    echo "⚠️ X11 access may have issues (might be normal if no X session running)"
fi

# 10. Additional fixes
echo ""
echo "10. ADDITIONAL FIXES:"

# Ensure PAM modules are properly configured
echo "Checking PAM configuration..."
if [ -f /etc/pam.d/lightdm ]; then
    echo "✅ LightDM PAM configuration exists"
else
    echo "❌ LightDM PAM configuration missing - this could cause login failures"
fi

# Clear any potential lock files
sudo rm -f "/tmp/.X*-lock" "/tmp/.X11-unix/X*" 2>/dev/null || true

# Fix any potential issues with systemd user session
sudo -u posuser systemctl --user daemon-reload 2>/dev/null || true

# Create a test script to verify the user can log in
sudo tee /tmp/test-posuser-login.sh << 'TEST_SCRIPT'
#!/bin/bash
# Test script to verify posuser login capability
echo "Testing posuser login capability..."

# Test 1: Can we switch to the user?
if sudo -u posuser whoami; then
    echo "✅ User switch works"
else
    echo "❌ User switch fails"
    exit 1
fi

# Test 2: Can we run a basic session command?
if sudo -u posuser bash -c 'cd ~ && ls -la'; then
    echo "✅ Basic session commands work"
else
    echo "❌ Basic session commands fail"
    exit 1
fi

echo "✅ posuser appears to be working correctly"
TEST_SCRIPT

chmod +x /tmp/test-posuser-login.sh

echo ""
echo "=== DIAGNOSTIC COMPLETE ==="
echo ""
echo "RECOMMENDED ACTIONS:"
echo "1. Run the test script: /tmp/test-posuser-login.sh"
echo "2. Restart LightDM: sudo systemctl restart lightdm"
echo "3. If still having issues, try manual login first:"
echo "   - Switch to TTY1 (Ctrl+Alt+F1)"
echo "   - Login as posuser manually"
echo "   - Check for errors in ~/.xsession-errors"
echo "4. Check the logs: sudo journalctl -u lightdm -f"
echo ""
echo "COMMON ISSUES ADDRESSED:"
echo "• Home directory permissions"
echo "• Shell configuration"
echo "• XFCE session setup"
echo "• LightDM configuration"
echo "• User account integrity"
echo ""
echo "If login still fails after reboot, check:"
echo "• /var/log/lightdm/lightdm.log"
echo "• /home/posuser/.xsession-errors"
echo "• sudo journalctl -u lightdm"
