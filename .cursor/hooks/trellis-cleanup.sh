#!/nix/store/gik3rh1vz2jlgnifb9dh6vc6sxwwz9jj-bash-5.3p9/bin/bash
# One-shot Trellis cleanup for Learning-languages mascot 3D.
set -euo pipefail

FLAG="/tmp/run-trellis-cleanup.flag"
REPORT="/tmp/trellis-cleanup-report.json"
API="http://127.0.0.1:8004"
USER="Adam"
ROOT="/home/adam/Dokumenty/Projekty/Learning-languages"
OUT="$ROOT/assets/models3d"
QUEUE_DIR="/var/lib/trellis3d/queue"
OUTPUT_DIR="/var/lib/trellis3d/output"
CURL="/run/current-system/sw/bin/curl"
PYTHON="/nix/store/mj8b2zc2i4f77ak89k1fckgs40dqa09n-python3-3.13.13-env/bin/python3"

if [[ ! -f "$FLAG" ]]; then
  echo '{}' 
  exit 0
fi

mkdir -p "$OUT"
: > "$REPORT.tmp"

log() { echo "$1" >> "$REPORT.tmp"; }

log "=== Trellis cleanup $(date -Iseconds) ==="

# Collect Adam job ids from API
QUEUE_JSON="$($CURL -sf "$API/queue" 2>/dev/null || echo '{}')"
ADAM_JOBS="$($PYTHON -c "
import json,sys
d=json.loads(sys.argv[1])
ids=set(['668d63caa5204bf9','c748029a22364e57','aa1fe884e5f34155'])
for j in d.get('queued',[]):
    if j and j.get('user')=='Adam':
        ids.add(j.get('job_id') or j.get('id'))
r=d.get('running')
if r and r.get('user')=='Adam':
    ids.add(r.get('job_id') or r.get('id'))
print(' '.join(sorted(x for x in ids if x)))
" "$QUEUE_JSON")"

log "Adam jobs to cancel: $ADAM_JOBS"

for job_id in $ADAM_JOBS; do
  resp="$($CURL -sf -X POST "$API/cancel/$job_id" \
    -H 'Content-Type: application/json' \
    -d '{"user":"Adam"}' 2>&1 || true)"
  log "CANCEL $job_id: $resp"
  qf="$QUEUE_DIR/${job_id}.json"
  if [[ -f "$qf" ]]; then
    sudo rm -f "$qf" && log "  removed queue file $qf" || log "  FAILED rm $qf"
  fi
done

declare -A GOOD=(
  [mascot_cat]=cc6ac0bcb72e
  [mascot_dog]=4f9dccbf9cfe
  [dress_sparkle]=98d1b5d87da7
  [bowl_pink]=c2d24e3cae66
  [bowl_gold]=8b8026ce94d7
)

for name in "${!GOOD[@]}"; do
  out_id="${GOOD[$name]}"
  dest="$OUT/${name}.glb"
  ok=0
  if $CURL -sf "$API/view/${out_id}.glb" -o "${dest}.partial" 2>/dev/null; then
    mv "${dest}.partial" "$dest"
    ok=1
  elif [[ -f "$OUTPUT_DIR/${out_id}.glb" ]]; then
    sudo cp "$OUTPUT_DIR/${out_id}.glb" "$dest" 2>/dev/null || cp "$OUTPUT_DIR/${out_id}.glb" "$dest"
    ok=1
  fi
  if [[ $ok -eq 1 ]]; then
    sz=$(stat -c%s "$dest" 2>/dev/null || echo 0)
    log "COPIED $name ($out_id) -> $dest size=$sz"
  else
    log "FAIL copy $name ($out_id)"
  fi
done

for bad in bow_gold.glb scarf_rainbow.glb boots_pink.glb tiara_crystal.glb; do
  p="$OUT/$bad"
  if [[ -f "$p" ]]; then
    rm -f "$p"
    log "DELETED $bad"
  else
    log "SKIP delete (missing): $bad"
  fi
done

QUEUE_AFTER="$($CURL -sf "$API/queue" 2>/dev/null || echo '{}')"
log "QUEUE_AFTER: $QUEUE_AFTER"

SCRIPT="$ROOT/scripts/generate_mascot_3d_trellis.sh"
if grep -q "naked fur only" "$SCRIPT" && grep -q "NO cat" "$SCRIPT" && grep -q "NO dog" "$SCRIPT"; then
  nohup /nix/store/gik3rh1vz2jlgnifb9dh6vc6sxwwz9jj-bash-5.3p9/bin/bash "$SCRIPT" \
    > /tmp/trellis-mascot-gen.log 2>&1 &
  echo $! > /tmp/trellis-mascot-gen.pid
  log "STARTED generation PID=$(cat /tmp/trellis-mascot-gen.pid)"
else
  log "NOT started generation — script missing 'naked fur only' / 'NO cat' / 'NO dog'"
fi

rm -f "$FLAG"
mv "$REPORT.tmp" "$REPORT"
echo '{}'
exit 0
