#!/nix/store/gik3rh1vz2jlgnifb9dh6vc6sxwwz9jj-bash-5.3p9/bin/bash
# Kopiuje gotowe GLB z Trellis do assets/models3d/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/assets/models3d"
SRC="/var/lib/trellis3d/output"
API="http://127.0.0.1:8004"
CURL="/run/current-system/sw/bin/curl"
mkdir -p "$OUT"

copy_one() {
  local name="$1" out_id="$2"
  local dest="$OUT/${name}.glb"
  if $CURL -sf "$API/view/${out_id}.glb" -o "${dest}.partial" 2>/dev/null; then
    mv "${dest}.partial" "$dest"
  elif [[ -f "$SRC/${out_id}.glb" ]]; then
    cp "$SRC/${out_id}.glb" "$dest"
  else
    echo "FAIL: $name ($out_id)" >&2
    return 1
  fi
  echo "OK: $name $(stat -c%s "$dest") bytes"
}

copy_one mascot_cat cc6ac0bcb72e
copy_one mascot_dog 4f9dccbf9cfe
copy_one dress_sparkle 98d1b5d87da7
copy_one bowl_pink c2d24e3cae66
copy_one bowl_gold 8b8026ce94d7

rm -f "$OUT"/bow_gold.glb "$OUT"/scarf_rainbow.glb "$OUT"/boots_pink.glb "$OUT"/tiara_crystal.glb
echo "Done."
