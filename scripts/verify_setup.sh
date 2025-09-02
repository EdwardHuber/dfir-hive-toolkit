#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PYCHK="$(command -v python3 || true)"
IMPKT="$ROOT/impacket/examples/secretsdump.py"

echo "=== Verify Portable Setup (Kali) ==="
echo "USB root: $ROOT"
echo

if [[ -n "$PYCHK" ]]; then
  echo "[OK] python3: $PYCHK"
else
  echo "[X] python3 not found in PATH"
fi

if [[ -f "$IMPKT" ]]; then
  echo "[OK] Impacket script: $IMPKT"
else
  echo "[X] Missing: $IMPKT"
fi

read -rp "Enter Label to check for hives (blank to skip): " LABEL
if [[ -n "$LABEL" ]]; then
  [[ -f "$ROOT/hives/$LABEL/SAM"    ]] && echo "[OK] hives/$LABEL/SAM"    || echo "[X] missing hives/$LABEL/SAM"
  [[ -f "$ROOT/hives/$LABEL/SYSTEM" ]] && echo "[OK] hives/$LABEL/SYSTEM" || echo "[X] missing hives/$LABEL/SYSTEM"
fi

echo
echo "Done."
