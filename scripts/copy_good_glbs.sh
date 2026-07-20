#!/nix/store/gik3rh1vz2jlgnifb9dh6vc6sxwwz9jj-bash-5.3p9/bin/bash
# Kopiuje gotowe GLB z Trellis → assets/models3d/ wg scripts/.trellis_mascot_jobs.json
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/assets/models3d"
SRC="/var/lib/trellis3d/output"
STATE="$ROOT/scripts/.trellis_mascot_jobs.json"
API="http://127.0.0.1:8004"
CURL="/run/current-system/sw/bin/curl"
mkdir -p "$OUT"

copy_one() {
  local name="$1" out_id="$2"
  local dest="$OUT/${name}.glb"
  if $CURL -sf "$API/view/${out_id}.glb" -o "${dest}.partial" 2>/dev/null; then
    mv "${dest}.partial" "$dest"
  elif [[ -f "$SRC/${out_id}.glb" ]]; then
    cp -f "$SRC/${out_id}.glb" "$dest"
  else
    echo "FAIL: $name ($out_id)" >&2
    return 1
  fi
  echo "OK: $name $(stat -c%s "$dest") bytes"
}

mapfile -t ROWS < <(python3 -c "
import json, sys
from pathlib import Path
state = json.loads(Path('$STATE').read_text())
src = Path('$SRC')
for name, meta in state.items():
    if meta.get('status') != 'done':
        continue
    oid = meta.get('out_id') or ''
    if not oid or not (src / f'{oid}.glb').exists():
        if oid:
            print(f'SKIP missing glb: {name} {oid}', file=sys.stderr)
        continue
    print(f'{name}\t{oid}')
")

for row in "${ROWS[@]}"; do
  [[ "$row" == SKIP* ]] && continue
  name="${row%%$'\t'*}"
  out_id="${row#*$'\t'}"
  copy_one "$name" "$out_id" || true
done

echo "Done."
