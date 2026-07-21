#!/usr/bin/env bash
# Pełna paczka Windows (składana na Linuxie z gotowego build/windows… albo na Windows).
# Wymaga wcześniejszego: flutter build windows --release
# oraz ./scripts/fetch_ondevice_models.sh --phone-only (lub --all)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

./scripts/fetch_ondevice_models.sh --phone-only
chmod +x "$ROOT/scripts/bundle_ollama_windows.sh"
./scripts/bundle_ollama_windows.sh

SRC=""
for candidate in \
  "$ROOT/build/windows/x64/runner/Release" \
  "$ROOT/build/windows/runner/Release"; do
  if [[ -d "$candidate" ]]; then SRC="$candidate"; break; fi
done
if [[ -z "$SRC" ]]; then
  echo "Brak Windows Release build. Na Windows: flutter build windows --release" >&2
  exit 1
fi

if [[ ! -f "$ROOT/bundled/ollama/ollama.exe" || ! -f "$ROOT/bundled/ollama/lib/ollama/ggml.dll" ]]; then
  echo "Niepełna Ollama w bundled/ollama (brak exe lub lib/). Uruchom scripts/bundle_ollama_windows.sh" >&2
  exit 1
fi

DIST="$ROOT/dist/Dialectium-Windows"
rm -rf "$DIST"
mkdir -p "$DIST/models" "$DIST/bundled/ollama"
cp -a "$SRC"/. "$DIST/"
cp -f "$ROOT/models/"*.gguf "$DIST/models/"
# Cały sidecar — sam ollama.exe bez lib/ = Windows error 126
cp -a "$ROOT/bundled/ollama"/. "$DIST/bundled/ollama/"

cat > "$DIST/CZYTAJ-MNIE.txt" <<'EOF'
Dialectium — pełna paczka (z lokalnym AI)

1. Rozpakuj ZIP gdzie chcesz.
2. Uruchom dialectium.exe
3. Nic nie instaluj i nic nie ściągaj — Bielik i Ollama są w środku.
4. Nie usuwaj folderu bundled\ollama\lib — bez niego AI nie działa.
EOF

(
  cd "$ROOT/dist"
  rm -f Dialectium-Windows.zip
  zip -r -q Dialectium-Windows.zip Dialectium-Windows
)
echo "ZIP: $ROOT/dist/Dialectium-Windows.zip"
du -sh "$DIST" "$ROOT/dist/Dialectium-Windows.zip"
