#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMPKT="$ROOT/impacket/examples/secretsdump.py"
HIVES="$ROOT/hives"
RESULTS="$ROOT/results"

if [[ ! -f "$IMPKT" ]]; then
  echo "[!] secretsdump.py not found at: $IMPKT"
  echo "    Clone the impacket repo to $ROOT/impacket"
  exit 1
fi

label="${1:-}"
if [[ -z "$label" ]]; then
  read -rp "Target Label (e.g., WIN10LAB): " label
fi

TH="$HIVES/$label"
TR="$RESULTS/$label"
mkdir -p "$TR"

if [[ ! -f "$TH/SAM" || ! -f "$TH/SYSTEM" ]]; then
  echo "[!] Missing hives for label '$label' in $TH"
  echo "    Expected files: $TH/SAM and $TH/SYSTEM"
  exit 1
fi

ts="$(date +'%Y%m%d-%H%M%S')"
out="$TR/${label}_${ts}_offline.txt"

echo "[*] Running secretsdump (offline) for '$label'..."
python3 "$IMPKT" -sam "$TH/SAM" -system "$TH/SYSTEM" LOCAL | tee "$out"

echo "[+] Results saved: $out"
