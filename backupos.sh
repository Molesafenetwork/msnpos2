#!/bin/bash
# Orange Pi 3B System Backup Script
# Creates a full disk image of the NVMe drive

# === Settings ===
BACKUP_DIR="/home/pi/backup"
DEVICE="/dev/nvme0n1"   # adjust if your system disk is different
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
OUTPUT="$BACKUP_DIR/orangepi-backup-$DATE.img"

# === Script ===
set -e  # exit if anything fails

# Make sure backup folder exists
mkdir -p "$BACKUP_DIR"

echo "=== Orange Pi 3B Backup Utility ==="
echo "Backing up $DEVICE to $OUTPUT"
echo "This may take a while... do not power off."

# Run dd with progress info
sudo dd if="$DEVICE" of="$OUTPUT" bs=1M status=progress conv=fsync

echo "=== Backup Completed ==="
ls -lh "$OUTPUT"
