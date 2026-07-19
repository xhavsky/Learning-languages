#!/usr/bin/env bash
# Pełna paczka Linux: app + Bielik 1.5B + 11B v3 + Ollama sidecar.
# Użytkownik rozpakowuje i uruchamia — nic nie ściąga.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Modele + Ollama…"
./scripts/fetch_ondevice_models.sh --all

if [[ ! -f models/Bielik-1.5B-v3.0-Instruct-Q4_K_M.gguf ]]; then
  echo "Brak modelu 1.5B" >&2; exit 1
fi
if [[ ! -f models/Bielik-11B-v3.0-Instruct.Q4_K_M.gguf ]]; then
  echo "Brak modelu 11B" >&2; exit 1
fi
if [[ ! -x bundled/ollama/ollama ]]; then
  echo "Brak bundled/ollama/ollama" >&2; exit 1
fi

if command -v flutter >/dev/null 2>&1; then
  flutter pub get
  flutter build linux --release || true
fi

PREFIX="$ROOT/build/linux/x64/release/bundle"
if [[ ! -d "$PREFIX" ]]; then
  echo "Brak bundle Linux: $PREFIX" >&2
  exit 1
fi

mkdir -p "$PREFIX/models" "$PREFIX/bundled/ollama"
cp -f "$ROOT/models/"*.gguf "$PREFIX/models/"
cp -f "$ROOT/bundled/ollama/ollama" "$PREFIX/bundled/ollama/ollama"
chmod +x "$PREFIX/bundled/ollama/ollama"

DIST="$ROOT/dist"
mkdir -p "$DIST"
OUT="$DIST/trener-jezykowy-linux-x64"
rm -rf "$OUT" "$OUT.zip"
cp -a "$PREFIX" "$OUT"
(
  cd "$DIST"
  zip -r -q "trener-jezykowy-linux-x64.zip" "trener-jezykowy-linux-x64"
)
echo "Release ZIP: $DIST/trener-jezykowy-linux-x64.zip"
du -sh "$OUT" "$DIST/trener-jezykowy-linux-x64.zip"
