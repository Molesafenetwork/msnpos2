#!/bin/bash
set -e

echo "=== Updating system ==="
sudo apt update && sudo apt upgrade -y

echo "=== Installing dependencies ==="
sudo apt install -y \
    build-essential git cmake unzip wget \
    libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev \
    wine winetricks

echo "=== Installing Open Source Games ==="
sudo apt install -y \
    supertux supertuxkart openttd freeciv-client-gtk minetest \
    aisleriot gnome-mahjongg gnome-mines gnome-sudoku snake4 \
    xboard gnuchess pacman4console

echo "=== Installing Box64 (for running x86 games on ARM64) ==="
cd ~
if [ ! -d "box64" ]; then
    git clone https://github.com/ptitSeb/box64
fi
cd box64
mkdir -p build && cd build
cmake .. -DRK3399=1
make -j$(nproc)
sudo make install

echo "=== Setting up Games folder ==="
mkdir -p ~/Games
echo "Place your Simpsons Hit & Run .iso or installer .exe into ~/Games"
echo "To run it: box64 wine setup.exe"

echo "=== Installation Complete! ==="
echo "Installed:"
echo "- SuperTux, SuperTuxKart, OpenTTD, FreeCiv, Minetest"
echo "- Solitaire (Aisleriot), Minesweeper, Mahjongg, Sudoku, Snake, Chess, Pac-Man"
