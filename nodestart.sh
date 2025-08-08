#!/bin/bash
# nodestart.sh - POS System Starter (XFCE Compatible)

echo "--------------------------------------"
echo " POS System Startup Script"
echo "--------------------------------------"
echo "This script will start your POS server"
echo "and optionally set it to start at login."
echo
echo "MOLESAFENETWORK.COM - POINT OF SALES - FOR THE ORANGEPI 3B (UBUNTU20.04-FOCAL)"
echo "@@@@@@@@@@    @@@@@@   @@@  @@@"       
echo "@@@@@@@@@@@  @@@@@@@   @@@@ @@@"       
echo "@@! @@! @@!  !@@       @@!@!@@@"       
echo "!@! !@! !@!  !@!       !@!!@!@!"       
echo "@!! !!@ @!@  !!@@!!    @!@ !!@!"        
echo "!@!   ! !@!   !!@!!!   !@!  !!!"        
echo "!!:     !!:       !:!  !!:  !!!"        
echo ":!:     :!:      !:!   :!:  !:!"        
echo ":::     ::   :::: ::    ::   ::"      
echo " :      :    :: : :     ::    :"    
                                       
                                       
echo "@@@@@@   @@@@@@@   @@@@@@@@  @@@  @@@"
echo "@@@@@@@@  @@@@@@@@  @@@@@@@@  @@@@ @@@" 
echo "@@!  @@@  @@!  @@@  @@!       @@!@!@@@" 
echo "!@!  @!@  !@!  @!@  !@!       !@!!@!@!" 
echo "@!@  !@!  @!@@!@!   @!!!:!    @!@ !!@!"
echo "!@!  !!!  !!@!!!    !!!!!:    !@!  !!!" 
echo "!!:  !!!  !!:       !!:       !!:  !!!" 
echo ":!:  !:!  :!:       :!:       :!:  !:!" 
echo "::::: ::   ::       :: ::::   ::   ::" 
echo " : :  :    :        : :: ::   ::    :"  
                                       
                                       
echo "@@@@@@@    @@@@@@    @@@@@@"            
echo "@@@@@@@@  @@@@@@@@  @@@@@@@"            
echo "@@!  @@@  @@!  @@@  !@@"                
echo "!@!  @!@  !@!  @!@  !@!"               
echo "@!@@!@!   @!@  !@!  !!@@!!"             
echo "!!@!!!    !@!  !!!   !!@!!!"            
echo "!!:       !!:  !!!       !:!"           
echo ":!:       :!:  !:!      !:!"            
echo " ::       ::::: ::  :::: ::"            
echo " :         : :  :   :: : :"             
echo
# Step 1: Check for POS folder
if [ ! -d "$HOME/pos-system" ]; then
    echo "Error: pos-system folder not found in $HOME."
    exit 1
fi

# Step 2: Ask about auto-start BEFORE starting the server
while true; do
    read -rp "Do you want to run this POS server every time you log in? (y/n): " choice
    case "$choice" in
        [Yy]* )
            AUTOSTART_PATH="$HOME/.config/autostart"
            mkdir -p "$AUTOSTART_PATH"
            cat > "$AUTOSTART_PATH/pos-server.desktop" <<EOL
[Desktop Entry]
Type=Application
Name=POS Server
Exec=xfce4-terminal --command="bash -ic 'cd \$HOME/pos-system && node server.js'"
X-GNOME-Autostart-enabled=true
EOL
            chmod +x "$AUTOSTART_PATH/pos-server.desktop"
            echo "Auto-start enabled."
            break;;
        [Nn]* )
            echo "Auto-start skipped."
            break;;
        * )
            echo "Please answer y or n.";;
    esac
done
echo "adding keybinds"
curl -sSL https://raw.githubusercontent.com/Molesafenetwork/msnpos2/main/pos-hotkeys.sh | bash

# Step 3: Start server and show logs
echo
echo "Starting POS server..."
cd "$HOME/pos-system" || exit 1
echo "--------------------------------------"
echo " Press CTRL+C to stop the server."
echo " Server logs will appear below:"
echo "--------------------------------------"
node server.js
