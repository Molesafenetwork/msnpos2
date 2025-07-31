#!/bin/bash
# DietPi / Armbian - Move RootFS to SSD (Simple Version)
# Usage: curl -sSL https://raw.githubusercontent.com/Molesafenetwork/msnpos2/main/move-to-ssd.sh | sudo bash

SSD_UUID="a47ae261-81af-487f-af39-12373f86315d"
SSD_MOUNT="/mnt/ssd"

echo "📦 Creating mount point..."
mkdir -p $SSD_MOUNT

echo "🔗 Mounting SSD at $SSD_MOUNT..."
mount UUID=$SSD_UUID $SSD_MOUNT || { echo "❌ Failed to mount SSD. Is the UUID correct?"; exit 1; }

echo "📁 Copying root filesystem to SSD..."
cp -a / $SSD_MOUNT --exclude=/mnt --exclude=/proc --exclude=/sys --exclude=/tmp --exclude=/dev --exclude=/run --exclude=/media --exclude=/lost+found

echo "🧾 Updating fstab on SSD..."
sed -i "/ \/ /d" $SSD_MOUNT/etc/fstab
echo "UUID=$SSD_UUID / ext4 defaults,noatime 0 1" >> $SSD_MOUNT/etc/fstab

echo "⚠️ Please now manually edit /boot/armbianEnv.txt or /boot/dietpiEnv.txt:"
echo "    Set: rootdev=UUID=$SSD_UUID"
echo ""
read -p "Press Enter after you've edited the boot config..."

echo "🔁 Rebooting in 5 seconds..."
sleep 5
reboot
