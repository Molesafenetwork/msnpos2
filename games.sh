#!/bin/bash

# Linux Games Auto-Installer for XFCE Desktop
# Downloads free games and creates desktop shortcuts

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create directories
GAMES_DIR="$HOME/Games"
DESKTOP_DIR="$HOME/Desktop"
APPLICATIONS_DIR="$HOME/.local/share/applications"

echo -e "${BLUE}=== Linux Games Installer ===${NC}"
echo "Installing games to: $GAMES_DIR"

# Create directories if they don't exist
mkdir -p "$GAMES_DIR"
mkdir -p "$DESKTOP_DIR"
mkdir -p "$APPLICATIONS_DIR"

# Function to create desktop shortcut
create_desktop_shortcut() {
    local name="$1"
    local exec_path="$2"
    local icon_path="$3"
    local comment="$4"
    
    cat > "$DESKTOP_DIR/$name.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=$comment
Exec=$exec_path
Icon=$icon_path
Terminal=false
Categories=Game;
EOF

    cat > "$APPLICATIONS_DIR/$name.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=$comment
Exec=$exec_path
Icon=$icon_path
Terminal=false
Categories=Game;
EOF

    chmod +x "$DESKTOP_DIR/$name.desktop"
    chmod +x "$APPLICATIONS_DIR/$name.desktop"
}

# Function to check if package exists and install
install_package() {
    local package_name="$1"
    local display_name="$2"
    
    if apt-cache search "^${package_name}$" | grep -q "^${package_name}"; then
        echo -e "${GREEN}Installing $display_name via apt...${NC}"
        sudo apt install -y "$package_name"
        return 0
    else
        echo -e "${YELLOW}Package $package_name not found in repositories${NC}"
        return 1
    fi
}

# Function to download and extract
download_and_extract() {
    local url="$1"
    local filename="$2"
    local extract_dir="$3"
    
    echo -e "${YELLOW}Downloading $filename...${NC}"
    cd "$GAMES_DIR"
    
    if [ ! -f "$filename" ]; then
        wget -O "$filename" "$url" || curl -L -o "$filename" "$url" || {
            echo -e "${RED}Failed to download $filename${NC}"
            return 1
        }
    fi
    
    if [ ! -d "$extract_dir" ]; then
        case "$filename" in
            *.tar.gz|*.tgz)
                tar -xzf "$filename"
                ;;
            *.tar.xz)
                tar -xJf "$filename"
                ;;
            *.zip)
                unzip -q "$filename"
                ;;
            *.tar.bz2)
                tar -xjf "$filename"
                ;;
            *.AppImage)
                chmod +x "$filename"
                mkdir -p "$extract_dir"
                mv "$filename" "$extract_dir/"
                ;;
        esac
    fi
}

echo -e "${GREEN}Starting game installations...${NC}"

# Update package lists first
echo -e "${BLUE}Updating package lists...${NC}"
sudo apt update

# 1. SuperTux (Mario-like platformer) - Try multiple package names
echo -e "${BLUE}Installing SuperTux...${NC}"
if install_package "supertux2" "SuperTux2"; then
    create_desktop_shortcut "SuperTux2" "supertux2" "supertux" "Run and jump platformer game"
elif install_package "supertux" "SuperTux"; then
    create_desktop_shortcut "SuperTux" "supertux" "supertux" "Run and jump platformer game"
else
    # Download SuperTux manually
    echo -e "${YELLOW}Downloading SuperTux manually...${NC}"
    SUPERTUX_URL="https://github.com/SuperTux/supertux/releases/download/v0.6.3/SuperTux-v0.6.3-Linux.tar.gz"
    download_and_extract "$SUPERTUX_URL" "supertux.tar.gz" "SuperTux-v0.6.3-Linux"
    
    if [ -d "$GAMES_DIR/SuperTux-v0.6.3-Linux" ]; then
        chmod +x "$GAMES_DIR/SuperTux-v0.6.3-Linux/supertux2"
        create_desktop_shortcut "SuperTux2" "$GAMES_DIR/SuperTux-v0.6.3-Linux/supertux2" "$GAMES_DIR/SuperTux-v0.6.3-Linux/data/images/engine/icons/supertux-256x256.png" "Run and jump platformer game"
    fi
fi

# 2. Battle for Wesnoth (Turn-based strategy RPG)
echo -e "${BLUE}Installing Battle for Wesnoth...${NC}"
if install_package "wesnoth" "Battle for Wesnoth"; then
    create_desktop_shortcut "Wesnoth" "wesnoth" "wesnoth-icon" "Fantasy turn-based strategy game"
fi

# 3. FreedroidRPG (Sci-fi RPG)
echo -e "${BLUE}Installing FreedroidRPG...${NC}"
if install_package "freedroidrpg" "FreedroidRPG"; then
    create_desktop_shortcut "FreedroidRPG" "freedroidrpg" "freedroidrpg" "Sci-fi role playing game"
fi

# 4. OpenTTD (Transport simulation)
echo -e "${BLUE}Installing OpenTTD...${NC}"
if install_package "openttd" "OpenTTD"; then
    create_desktop_shortcut "OpenTTD" "openttd" "openttd" "Transport simulation game"
else
    # Download OpenTTD manually
    echo -e "${YELLOW}Downloading OpenTTD manually...${NC}"
    OPENTTD_URL="https://cdn.openttd.org/openttd-releases/13.4/openttd-13.4-linux-generic-amd64.tar.xz"
    download_and_extract "$OPENTTD_URL" "openttd.tar.xz" "openttd-13.4-linux-generic-amd64"
    
    if [ -d "$GAMES_DIR/openttd-13.4-linux-generic-amd64" ]; then
        chmod +x "$GAMES_DIR/openttd-13.4-linux-generic-amd64/openttd"
        create_desktop_shortcut "OpenTTD" "$GAMES_DIR/openttd-13.4-linux-generic-amd64/openttd" "$GAMES_DIR/openttd-13.4-linux-generic-amd64/media/openttd.64.png" "Transport simulation game"
    fi
fi

# 5. Download SuperTuxKart (Racing game)
echo -e "${BLUE}Installing SuperTuxKart...${NC}"
STK_VERSION="1.4"
STK_URL="https://github.com/supertuxkart/stk-code/releases/download/$STK_VERSION/SuperTuxKart-$STK_VERSION-linux-64bit.tar.xz"
download_and_extract "$STK_URL" "supertuxkart.tar.xz" "SuperTuxKart-$STK_VERSION-linux-64bit"

if [ -d "$GAMES_DIR/SuperTuxKart-$STK_VERSION-linux-64bit" ]; then
    chmod +x "$GAMES_DIR/SuperTuxKart-$STK_VERSION-linux-64bit/bin/supertuxkart"
    create_desktop_shortcut "SuperTuxKart" "$GAMES_DIR/SuperTuxKart-$STK_VERSION-linux-64bit/bin/supertuxkart" "$GAMES_DIR/SuperTuxKart-$STK_VERSION-linux-64bit/data/supertuxkart_512.png" "3D kart racing game"
fi

# 6. VDrift (Driving simulation)
echo -e "${BLUE}Installing VDrift...${NC}"
if install_package "vdrift" "VDrift"; then
    create_desktop_shortcut "VDrift" "vdrift" "vdrift" "Realistic driving simulation"
fi

# 7. ScummVM (Point and click adventures)
echo -e "${BLUE}Installing ScummVM...${NC}"
if install_package "scummvm" "ScummVM"; then
    create_desktop_shortcut "ScummVM" "scummvm" "scummvm" "Classic adventure game engine"
fi

# 8. 0 A.D. (Real-time strategy)
echo -e "${BLUE}Installing 0 A.D....${NC}"
if install_package "0ad" "0 A.D."; then
    create_desktop_shortcut "0 A.D." "0ad" "0ad" "Historical real-time strategy game"
fi

# 9. Minetest (Minecraft-like)
echo -e "${BLUE}Installing Minetest...${NC}"
if install_package "minetest" "Minetest"; then
    create_desktop_shortcut "Minetest" "minetest" "minetest" "Open source voxel game engine"
fi

# 10. Endless Sky (Space trading RPG)
echo -e "${BLUE}Installing Endless Sky...${NC}"
if install_package "endless-sky" "Endless Sky"; then
    create_desktop_shortcut "Endless Sky" "endless-sky" "endless-sky" "Space exploration and trading game"
fi

# 11. Add some additional games via direct download
echo -e "${BLUE}Installing additional games...${NC}"

# Alien Arena (First-person shooter)
echo -e "${BLUE}Installing Alien Arena...${NC}"
ALIEN_URL="https://github.com/alienarena/alienarena/releases/download/7_71_6/alienarena-7.71.6-x86_64.AppImage"
cd "$GAMES_DIR"
if [ ! -f "alienarena.AppImage" ]; then
    wget -O "alienarena.AppImage" "$ALIEN_URL" || curl -L -o "alienarena.AppImage" "$ALIEN_URL"
    if [ -f "alienarena.AppImage" ]; then
        chmod +x "alienarena.AppImage"
        create_desktop_shortcut "Alien Arena" "$GAMES_DIR/alienarena.AppImage" "application-x-executable" "Sci-fi first-person shooter"
    fi
fi

# Warzone 2100 (Real-time strategy)
if install_package "warzone2100" "Warzone 2100"; then
    create_desktop_shortcut "Warzone 2100" "warzone2100" "warzone2100" "3D real-time strategy game"
fi

# Set permissions for desktop shortcuts
echo -e "${YELLOW}Setting up desktop shortcuts...${NC}"
chmod +x "$DESKTOP_DIR"/*.desktop 2>/dev/null || true

# Create README file
echo -e "${YELLOW}Creating README file...${NC}"
cat > "$DESKTOP_DIR/GAMES_README.txt" << 'EOF'
===============================================
      INSTALLED GAMES - HOW TO PLAY
===============================================

This file explains how to run each installed game.

QUICK START:
- Double-click any game icon on your desktop
- Or find games in Applications Menu > Games
- Or run commands in terminal

===============================================
INSTALLED GAMES & HOW TO RUN THEM:
===============================================

🎮 SUPERTUX2 (Platform Game)
   Desktop: Double-click "SuperTux2" icon
   Terminal: supertux2
   Description: Mario-like platformer with Tux the penguin
   Controls: Arrow keys to move, Space to jump

🏰 BATTLE FOR WESNOTH (Strategy RPG)
   Desktop: Double-click "Wesnoth" icon  
   Terminal: wesnoth
   Description: Fantasy turn-based strategy with RPG elements
   Controls: Mouse-driven, tutorial included

🤖 FREEDROIDRPG (Sci-fi RPG)
   Desktop: Double-click "FreedroidRPG" icon
   Terminal: freedroidrpg
   Description: Sci-fi RPG with point-and-click elements
   Controls: Mouse for movement, keyboard for actions

🚆 OPENTTD (Transport Simulation)
   Desktop: Double-click "OpenTTD" icon
   Terminal: openttd
   Description: Transport simulation - build bus/train networks
   Controls: Mouse-driven, includes tutorial
   Note: Closest to bus driving simulation

🏎️ SUPERTUXKART (Racing Game)
   Desktop: Double-click "SuperTuxKart" icon
   Terminal: Navigate to ~/Games/SuperTuxKart*/bin/ and run ./supertuxkart
   Description: 3D kart racing with power-ups
   Controls: Arrow keys or WASD for driving

🚗 VDRIFT (Driving Simulation)
   Desktop: Double-click "VDrift" icon
   Terminal: vdrift
   Description: Realistic car driving simulation
   Controls: Arrow keys for driving, detailed physics

🎭 SCUMMVM (Classic Adventures)
   Desktop: Double-click "ScummVM" icon
   Terminal: scummvm
   Description: Runs classic point-and-click adventures
   Controls: Mouse-driven
   Note: You'll need to add game data files

⚔️ 0 A.D. (Real-Time Strategy)
   Desktop: Double-click "0 A.D." icon
   Terminal: 0ad
   Description: Historical real-time strategy
   Controls: Mouse-driven with keyboard shortcuts

⛏️ MINETEST (Sandbox Game)
   Desktop: Double-click "Minetest" icon
   Terminal: minetest
   Description: Open-world voxel sandbox game
   Controls: WASD to move, mouse to look, detailed in-game help

🚀 ENDLESS SKY (Space Trading RPG)
   Desktop: Double-click "Endless Sky" icon
   Terminal: endless-sky
   Description: Space exploration, trading, and combat
   Controls: Mouse for navigation, detailed tutorial

===============================================
TROUBLESHOOTING:
===============================================

❌ Game won't start from desktop icon:
   - Try running from terminal to see error messages
   - Check if file permissions are correct: ls -la ~/Desktop/*.desktop

❌ Missing dependencies:
   - Run: sudo apt update && sudo apt upgrade
   - Install missing libraries as needed

❌ SuperTuxKart won't start:
   - Navigate to: ~/Games/SuperTuxKart*/bin/
   - Run: ./supertuxkart
   - Check file permissions: chmod +x supertuxkart

❌ ScummVM has no games:
   - Download free games like "Flight of the Amazon Queen"
   - Add games through ScummVM interface

❌ Performance issues:
   - Lower graphics settings in game options
   - Close other applications
   - Check system requirements

===============================================
GAME LOCATIONS:
===============================================

System games (installed via apt):
- /usr/games/ or /usr/bin/

Downloaded games:
- ~/Games/

Desktop shortcuts:
- ~/Desktop/

Application menu shortcuts:
- ~/.local/share/applications/

===============================================
ADDITIONAL FREE GAMES:
===============================================

To install more games:
- Ubuntu Software Center
- Steam (free games section)
- itch.io (many free Linux games)
- Lutris (for managing games)

Commands to install more:
- sudo apt search game
- sudo snap find games
- flatpak search games

===============================================
UNINSTALLING:
===============================================

To remove installed games:
- sudo apt remove [gamename]
- Delete shortcuts from Desktop
- Remove ~/Games directory if desired

Game names for removal:
- supertux2, wesnoth, freedroidrpg, openttd
- vdrift, scummvm, 0ad, minetest, endless-sky

===============================================

Created by: Linux Games Auto-Installer
Date: $(date)
System: Ubuntu 22.04 XFCE

Have fun gaming! 🎮

===============================================
EOF

# Make README executable (so it can be double-clicked)
chmod +x "$DESKTOP_DIR/GAMES_README.txt"

# Create a more detailed README in the Games directory
cat > "$GAMES_DIR/README.md" << 'EOF'
# Linux Games Collection

This directory contains games installed by the Linux Games Auto-Installer.

## Directory Structure

```
~/Games/
├── SuperTuxKart-*/          # Racing game files
├── README.md                # This file
└── [other downloaded games]
```

## Running Games

### From Desktop
- Look for game icons on your desktop
- Double-click to launch

### From Terminal
Each game can be run with its command:
- `supertux2` - SuperTux platformer
- `wesnoth` - Battle for Wesnoth strategy
- `freedroidrpg` - FreedroidRPG
- `openttd` - OpenTTD transport simulation
- `vdrift` - VDrift driving simulator
- `scummvm` - ScummVM adventure engine
- `0ad` - 0 A.D. strategy game
- `minetest` - Minetest sandbox
- `endless-sky` - Endless Sky space game

### SuperTuxKart (Special Case)
SuperTuxKart is downloaded as a standalone archive:
```bash
cd ~/Games/SuperTuxKart-*/bin/
./supertuxkart
```

## Game Data

Some games may require additional data files:
- **ScummVM**: Requires game data files for classic adventures
- **OpenTTD**: May benefit from additional graphics/sound packs
- **0 A.D.**: Downloads additional assets on first run

## Updating Games

System-installed games (via apt):
```bash
sudo apt update && sudo apt upgrade
```

Downloaded games: Check their respective websites/repositories for updates.

## Support

- Check game-specific documentation
- Visit game websites for communities and support
- Use in-game help systems when available

Enjoy your games! 🎮
EOF

# Final message
echo -e "${GREEN}"
echo "============================================"
echo "Installation Complete!"
echo "============================================"
echo -e "${NC}"
echo "Games installed in: $GAMES_DIR"
echo "Desktop shortcuts created on your desktop"
echo "Applications menu shortcuts also created"
echo ""
echo -e "${BLUE}Installed Games:${NC}"
echo "• SuperTux2 - Platform game"
echo "• Battle for Wesnoth - Turn-based strategy RPG"
echo "• FreedroidRPG - Sci-fi RPG"
echo "• OpenTTD - Transport simulation"
echo "• SuperTuxKart - Kart racing"
echo "• VDrift - Driving simulation"  
echo "• ScummVM - Classic adventures"
echo "• 0 A.D. - Historical RTS"
echo "• Minetest - Voxel sandbox"
echo "• Endless Sky - Space trading RPG"
echo "• Alien Arena - First-person shooter"
echo "• Warzone 2100 - 3D strategy"
echo ""
echo -e "${YELLOW}Note: Some games may require additional setup or game data.${NC}"
echo -e "${YELLOW}Check each game's documentation for details.${NC}"

# Optional: Update desktop database
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPLICATIONS_DIR" 2>/dev/null || true
fi

echo -e "${GREEN}Setup complete! Check your desktop for game shortcuts.${NC}"
echo ""
echo -e "${BLUE}📖 README FILES CREATED:${NC}"
echo "• Desktop README: ~/Desktop/GAMES_README.txt (double-click to open)"
echo "• Games directory README: ~/Games/README.md"
echo ""
echo -e "${YELLOW}💡 QUICK TIPS:${NC}"
echo "• All desktop shortcuts are executable - just double-click!"
echo "• Check GAMES_README.txt for detailed instructions"
echo "• Some games may download additional content on first run"
echo "• Having issues? Try running games from terminal for error messages"
