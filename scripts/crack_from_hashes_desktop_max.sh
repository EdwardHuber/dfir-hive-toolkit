#!/usr/bin/env bash
# crack_from_hashes_desktop_max.sh
# Desktop-optimized NTLM cracking (no decoding). Uses newest results/<LABEL>/<STAMP>/hashes.txt.
# - Builds a target-aware base wordlist from usernames/labels (no external lists).
# - Runs aggressive mask + hybrid progression.
# - Keeps per-target potfile & cracked.txt inside results/<LABEL>/<STAMP>/.
#
# Usage:
#   bash crack_from_hashes_desktop_max.sh
#   bash crack_from_hashes_desktop_max.sh /media/<user>/<USB_LABEL>
#   bash crack_from_hashes_desktop_max.sh --device /dev/sdb1
#
# Options (env vars):
#   HEAVY8=1     include full ?a x 8 brute-force (long but thorough) [default ON]
#   PLUS9=1      include curated 9-char masks (adds time)            [default OFF]
#   FAST=1       skip heavy phases (quick run)
#
# Requirements: hashcat (GPU highly recommended)
# Scope: authorized lab use only.

set -euo pipefail

die(){ echo "[!] $*" >&2; exit 1; }
info(){ echo "[*] $*"; }
ok(){ echo "[✓] $*"; }

need(){ command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }
need hashcat

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
      [[ -d "$mp/results" ]] && MOUNT="$mp" && break 2
    done
  done
fi

[[ -n "${MOUNT:-}" ]] || die "Could not find USB mountpoint. Pass a mountpoint or use --device /dev/sdXN"
[[ -d "$MOUNT/results" ]] || die "No 'results' folder at $MOUNT"
ok "Using USB mount: $MOUNT"

# -------- Pick newest results/<LABEL>/<STAMP> that has hashes.txt --------
LATEST_RES_DIR="$(find "$MOUNT/results" -mindepth 2 -maxdepth 2 -type d 2>/dev/null \
  | while read -r d; do [[ -s "$d/hashes.txt" ]] && echo "$d"; done \
  | sort | tail -n1 || true)"
[[ -n "$LATEST_RES_DIR" ]] || die "No results/<LABEL>/<STAMP>/hashes.txt found under $MOUNT/results"

LABEL="$(basename "$(dirname "$LATEST_RES_DIR")")"
STAMP="$(basename "$LATEST_RES_DIR")"
HASHES="$LATEST_RES_DIR/hashes.txt"
[[ -s "$HASHES" ]] || die "Empty hashes file: $HASHES"

ok "Target label: $LABEL"
ok "Timestamp:    $STAMP"
ok "Hashes file:  $HASHES"

# -------- Per-target potfile and cracked output --------
POTFILE="$LATEST_RES_DIR/hashcat_${LABEL}_${STAMP}.potfile"
CRACKED_OUT="$LATEST_RES_DIR/cracked_${LABEL}_${STAMP}.txt"
SESSION_PREFIX="NTLM_${LABEL}_${STAMP}"

# -------- Helper: counts --------
total_hashes(){ wc -l <"$HASHES" | tr -d ' '; }
cracked_count(){ hashcat --show --username -m 1000 --potfile-path "$POTFILE" "$HASHES" 2>/dev/null | wc -l | tr -d ' '; }

TOTAL="$(total_hashes)"
info "Total hashes: $TOTAL"

# -------- Build smart base wordlist (on the fly, no external lists) --------
BASE_RAW="$LATEST_RES_DIR/base_raw.txt"
BASE_TXT="$LATEST_RES_DIR/base.txt"
YEARS_TXT="$LATEST_RES_DIR/years.txt"
DIG2_TXT="$LATEST_RES_DIR/digits2.txt"
DIG3_TXT="$LATEST_RES_DIR/digits3.txt"
SEP_TXT="$LATEST_RES_DIR/separators.txt"

# Extract usernames from hashes.txt (format: user:LM:NT)
cut -d: -f1 "$HASHES" | sed -E 's/\$.*$//' | sort -u > "$BASE_RAW" || true

# Add label tokens
echo "$LABEL" >> "$BASE_RAW"
echo "$STAMP" >> "$BASE_RAW"
echo "$LABEL" | tr '._- ' '\n' >> "$BASE_RAW"

# Common months/seasons (short list, lower only)
cat >> "$BASE_RAW" <<'EOF'
spring
summer
autumn
fall
winter
jan
feb
mar
apr
may
jun
jul
aug
sep
oct
nov
dec
password
welcome
admin
user
test
guest
EOF

# Normalize + variants (lower, UPPER, Capitalize) and min length 3
awk '{
  if (length($0)>=3){
    l=tolower($0);
    printf "%s\n", l;
    # Capitalize
    printf toupper(substr(l,1,1)) substr(l,2) "\n";
    # UPPER
    printf toupper(l) "\n";
  }
}' "$BASE_RAW" | sort -u > "$BASE_TXT"

# Years and digits
seq 1995 2035 > "$YEARS_TXT"
printf "%02d\n" $(seq 0 99) > "$DIG2_TXT"
printf "%03d\n" $(seq 0 999) > "$DIG3_TXT"
printf "%s\n" '!' '@' '#' '$' '%' '^' '&' '*' '-' '_' '.' '?' > "$SEP_TXT"

BASE_COUNT=$(wc -l < "$BASE_TXT" | tr -d ' ')
info "Base words generated: $BASE_COUNT  → $BASE_TXT"

# -------- Helper to run hashcat with sane GPU flags --------
run_hc(){
  local session="$1"; shift
  info "Starting: $session  $*"
  hashcat \
    -m 1000 \
    --potfile-path "$POTFILE" \
    --session "$session" \
    --status --status-timer=20 \
    -O -w 4 \
    "$@" "$HASHES"
}

maybe_stop(){
  local cracked="$(cracked_count)"
  ok "Cracked so far: $cracked / $TOTAL"
  if [[ "$cracked" -ge "$TOTAL" ]]; then
    ok "All hashes cracked. Stopping early."
    return 0
  fi
  return 1
}

# -------- Phase 0: quick resume if already cracked --------
if maybe_stop; then
  :
fi

# -------- Phase 1: cheap wins (≤6, all printable, incremental) --------
if [[ "${FAST:-0}" != "1" ]]; then
  run_hc "${SESSION_PREFIX}_inc6_all" -a 3 '?a?a?a?a?a?a' --increment
  maybe_stop || true
fi

# -------- Phase 2: curated 8-char masks --------
# common human patterns
run_hc "${SESSION_PREFIX}_8_lower" -a 3 '?l?l?l?l?l?l?l?l'
maybe_stop || true
run_hc "${SESSION_PREFIX}_8_mix1"  -a 3 '?u?l?l?l?l?d?d?d'
maybe_stop || true
run_hc "${SESSION_PREFIX}_8_mix2"  -a 3 '?l?l?l?l?l?d?d?d'
maybe_stop || true
run_hc "${SESSION_PREFIX}_8_mix3"  -a 3 '?u?l?l?l?l?l?d?d'
maybe_stop || true
run_hc "${SESSION_PREFIX}_8_tail4" -a 3 '?l?l?l?l?d?d?d?d'
maybe_stop || true

# -------- Phase 3: hybrids with base words (no external lists) --------
# A) base + 2 digits
run_hc "${SESSION_PREFIX}_hy6_b+dd" -a 6 "$BASE_TXT" '?d?d'
maybe_stop || true
# B) base + 3 digits
run_hc "${SESSION_PREFIX}_hy6_b+ddd" -a 6 "$BASE_TXT" '?d?d?d'
maybe_stop || true
# C) base + 4 digits
run_hc "${SESSION_PREFIX}_hy6_b+dddd" -a 6 "$BASE_TXT" '?d?d?d?d'
maybe_stop || true
# D) Years as a mini list via combinator (base + year)
run_hc "${SESSION_PREFIX}_comb_b+year" -a 1 "$BASE_TXT" "$YEARS_TXT"
maybe_stop || true
# E) Small symbol joiners + digits (base + sep + 2 digits)
# Build a tiny joiner list like: "", "-", "_", ".", "!"
JOINERS="$LATEST_RES_DIR/joiners.txt"
printf "%s\n" "" "-" "_" "." "!" "@" "#" > "$JOINERS"
run_hc "${SESSION_PREFIX}_comb_b+join+dd" -a 1 "$BASE_TXT" "$JOINERS" ; true
# Then append digits on the result by re-feeding through mask (optional micro-step)
# (skipped to keep runtime sane)

# -------- Phase 4: heavy 8-char full keyspace (optional) --------
if [[ "${FAST:-0}" == "1" ]]; then
  info "FAST=1 set -> skipping heavy full 8-char."
else
  if [[ "${HEAVY8:-1}" == "1" ]]; then
    run_hc "${SESSION_PREFIX}_8_full" -a 3 '?a?a?a?a?a?a?a?a'
    maybe_stop || true
  else
    info "HEAVY8=0 -> skipping full 8-char."
  fi
fi

# -------- Phase 5: curated 9-char masks (optional) --------
if [[ "${PLUS9:-0}" == "1" && "${FAST:-0}" != "1" ]]; then
  run_hc "${SESSION_PREFIX}_9_mix1" -
