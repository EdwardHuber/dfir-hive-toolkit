#!/usr/bin/env bash
set -euo pipefail

echo "=== Linux Live Hive Copy Helper (Lab Edition) ==="
read -rp "Windows partition device (e.g., /dev/sda1): " WINDEV
read -rp "USB mount path (e.g., /media/$USER/USB20FD): " USBMNT
read -rp "Target Label (e.g., WIN10LAB): " LABEL

[[ -z "$WINDEV" || -z "$USBMNT" || -z "$LABEL" ]] && { echo "[!] All inputs required."; exit 1; }

sudo mkdir -p /mnt/win
sudo mount "$WINDEV" /mnt/win

DEST="$USBMNT/hives/$LABEL"
mkdir -p "$DEST"

echo "[*] Copying hives into $DEST ..."
sudo cp /mnt/win/Windows/System32/config/SAM "$DEST/SAM"
sudo cp /mnt/win/Windows/System32/config/SYSTEM "$DEST/SYSTEM"

sudo umount /mnt/win
echo "[+] Done. Hives at: $DEST"
