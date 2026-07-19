#!/usr/bin/env bash
# Pełna paczka Windows (składana na Linuxie z gotowego build/windows… albo na Windows).
# Wymaga wcześniejszego: flutter build windows --release
# oraz ./scripts/fetch_ondevice_models.sh --all (+ ollama.exe w bundled/ollama/).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

./scripts/fetch_ondevice_models.sh --all

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

if [[ ! -f "$ROOT/bundled/ollama/ollama.exe" ]]; then
  echo "Pobierz ollama.exe → bundled/ollama/ollama.exe (https://ollama.com/download)" >&2
  # Linux host: spróbuj oficjalne windows zip
  TMP="$(mktemp -d)"
  if curl -fsSL -o "$TMP/ollama.zip" \
    "https://github.com/ollama/ollama/releases/latest/download/ollama-windows-amd64.zip"; then
    unzip -qo "$TMP/ollama.zip" -d "$TMP/out"
    EXE="$(find "$TMP/out" -name 'ollama.exe' | head -1)"
    mkdir -p "$ROOT/bundled/ollama"
    cp -f "$EXE" "$ROOT/bundled/ollama/ollama.exe"
  else
    exit 1
  fi
  rm -rf "$TMP"
fi

DIST="$ROOT/dist/Trener-Jezykowy-Windows"
rm -rf "$DIST"
mkdir -p "$DIST/models" "$DIST/bundled/ollama"
cp -a "$SRC"/. "$DIST/"
cp -f "$ROOT/models/"*.gguf "$DIST/models/"
cp -f "$ROOT/bundled/ollama/ollama.exe" "$DIST/bundled/ollama/ollama.exe"

cat > "$DIST/CZYTAJ-MNIE.txt" <<'EOF'
Trener Językowy — pełna paczka (z lokalnym AI)

1. Rozpakuj ZIP gdzie chcesz.
2. Uruchom trener_jezykowy.exe
3. Nic nie instaluj i nic nie ściągaj — Bielik i Ollama są w środku.
EOF

(
  cd "$ROOT/dist"
  rm -f Trener-Jezykowy-Windows.zip
  zip -r -q Trener-Jezykowy-Windows.zip Trener-Jezykowy-Windows
)
echo "ZIP: $ROOT/dist/Trener-Jezykowy-Windows.zip"
du -sh "$DIST" "$ROOT/dist/Trener-Jezykowy-Windows.zip"
