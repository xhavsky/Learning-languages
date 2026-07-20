#!/usr/bin/env bash
# Pobiera oficjalne Ollama Windows i składa portable layout:
#   bundled/ollama/ollama.exe
#   bundled/ollama/lib/ollama/...
#
# Domyślnie BEZ CUDA (oszczędza ~1.3 GB) — CPU + Vulkan wystarczą do Bielika.
# Pełne GPU NVIDIA: ./scripts/bundle_ollama_windows.sh --with-cuda
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/bundled/ollama"
WITH_CUDA=0
for arg in "$@"; do
  case "$arg" in
    --with-cuda) WITH_CUDA=1 ;;
    *) echo "Nieznany argument: $arg" >&2; exit 1 ;;
  esac
done

mkdir -p "$OUT"
# Już kompletne (np. z cache CI) — ollama.exe + lib/ollama/ggml.dll
if [[ -f "$OUT/ollama.exe" && -f "$OUT/lib/ollama/ggml.dll" ]]; then
  if [[ "$WITH_CUDA" == 0 ]] || [[ -d "$OUT/lib/ollama/cuda_v12" ]]; then
    echo "OK: $OUT (już jest)"
    ls -lh "$OUT/ollama.exe"
    exit 0
  fi
fi

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

echo "Pobieram ollama-windows-amd64.zip..."
curl -fsSL -o "$TMP/ollama.zip" \
  "https://github.com/ollama/ollama/releases/latest/download/ollama-windows-amd64.zip"

# Windows CI (cp1252): polskie znaki w print() wywalaja UnicodeEncodeError
export PYTHONIOENCODING=utf-8
export PYTHONUTF8=1
python3 - "$TMP/ollama.zip" "$OUT" "$WITH_CUDA" <<'PY'
import sys, zipfile, shutil
from pathlib import Path

zip_path, out_s, with_cuda = sys.argv[1], Path(sys.argv[2]), sys.argv[3] == "1"
out = out_s
if out.exists():
    shutil.rmtree(out)
out.mkdir(parents=True)

skip_prefixes = ()
if not with_cuda:
    skip_prefixes = ("lib/ollama/cuda_v12/", "lib/ollama/cuda_v13/")

with zipfile.ZipFile(zip_path) as zf:
    for info in zf.infolist():
        name = info.filename.replace("\\", "/")
        if name.endswith("/"):
            continue
        if any(name.startswith(p) for p in skip_prefixes):
            continue
        # Zachowaj layout: ollama.exe + lib/ollama/...
        dest = out / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        with zf.open(info) as src, open(dest, "wb") as dst:
            shutil.copyfileobj(src, dst)

exe = out / "ollama.exe"
ggml = out / "lib" / "ollama" / "ggml.dll"
if not exe.is_file() or not ggml.is_file():
    raise SystemExit(f"Niepelna paczka Ollamy: exe={exe.exists()} ggml={ggml.exists()}")
# ASCII-only logs — runner Windows nie drukuje "ł" na cp1252
print(f"Zlozono: {out}")
print(f"  ollama.exe = {exe.stat().st_size // (1024*1024)} MB")
lib = out / "lib" / "ollama"
n = sum(1 for _ in lib.rglob("*") if _.is_file())
print(f"  lib/ollama plikow: {n}")
PY

echo "Gotowe: $OUT"
ls -lh "$OUT/ollama.exe"
du -sh "$OUT" "$OUT/lib" 2>/dev/null || true
