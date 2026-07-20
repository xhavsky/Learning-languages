#!/usr/bin/env bash
# Pobiera oficjalne Ollama Linux i składa portable layout:
#   bundled/ollama/ollama
#   bundled/ollama/lib/ollama/...
#
# Domyślnie BEZ CUDA (oszczędza ~1 GB) — CPU + Vulkan wystarczą do Bielika.
# Pełne GPU NVIDIA: ./scripts/bundle_ollama_linux.sh --with-cuda
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
# Już kompletne (np. z cache CI)
if [[ -x "$OUT/ollama" && -f "$OUT/lib/ollama/libggml.so" ]]; then
  if [[ "$WITH_CUDA" == 0 ]] || [[ -d "$OUT/lib/ollama/cuda_v12" ]]; then
    echo "OK: $OUT (już jest)"
    ls -lh "$OUT/ollama"
    exit 0
  fi
fi

if ! command -v zstd >/dev/null 2>&1; then
  echo "Brak zstd — zainstaluj (apt install zstd / nix-shell -p zstd)" >&2
  exit 1
fi

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) echo "Nieobsługiwana architektura: $ARCH" >&2; exit 1 ;;
esac

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

URL="https://github.com/ollama/ollama/releases/latest/download/ollama-linux-${ARCH}.tar.zst"
echo "Pobieram ollama-linux-${ARCH}.tar.zst..."
curl -fsSL -o "$TMP/ollama.tar.zst" "$URL"

# Rozpakuj do TMP/extract, pomijając CUDA gdy nie potrzeba
mkdir -p "$TMP/extract"
if [[ "$WITH_CUDA" == 1 ]]; then
  zstd -d -c "$TMP/ollama.tar.zst" | tar -x -C "$TMP/extract"
else
  zstd -d -c "$TMP/ollama.tar.zst" | tar -x -C "$TMP/extract" \
    --exclude='lib/ollama/cuda_v12' \
    --exclude='lib/ollama/cuda_v13' \
    --exclude='lib/ollama/cuda_v12/*' \
    --exclude='lib/ollama/cuda_v13/*'
fi

BIN="$(find "$TMP/extract" -type f -name ollama | head -1)"
if [[ -z "$BIN" ]]; then
  echo "Nie znaleziono binarki ollama w archiwum" >&2
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"
cp -a "$BIN" "$OUT/ollama"
chmod +x "$OUT/ollama"

# lib/ może być obok bin/ albo w korzeniu archiwum
if [[ -d "$TMP/extract/lib" ]]; then
  cp -a "$TMP/extract/lib" "$OUT/"
elif [[ -d "$(dirname "$BIN")/../lib" ]]; then
  cp -a "$(dirname "$BIN")/../lib" "$OUT/"
fi

if [[ ! -f "$OUT/lib/ollama/libggml.so" && ! -f "$OUT/lib/ollama/libggml-base.so" ]]; then
  echo "Brak bundled/ollama/lib/ollama — AI może nie wystartować." >&2
  find "$OUT" -maxdepth 3 -type f | head -40 >&2
  exit 1
fi

echo "Ollama → $OUT"
ls -lh "$OUT/ollama"
du -sh "$OUT" "$OUT/lib" 2>/dev/null || true
