#!/usr/bin/env bash
# Pobiera modele Bielik v3 + (opcjonalnie) binarkę Ollamy do paczki desktopowej.
# Użycie:
#   ./scripts/fetch_ondevice_models.sh              # telefon 1.5B
#   ./scripts/fetch_ondevice_models.sh --desktop     # + 11B + ollama
#   ./scripts/fetch_ondevice_models.sh --phone-only
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODELS="$ROOT/models"
OLLAMA_DIR="$ROOT/bundled/ollama"
mkdir -p "$MODELS"

PHONE_URL="https://huggingface.co/second-state/Bielik-1.5B-v3.0-Instruct-GGUF/resolve/main/Bielik-1.5B-v3.0-Instruct-Q4_K_M.gguf"
PHONE_FILE="$MODELS/Bielik-1.5B-v3.0-Instruct-Q4_K_M.gguf"

DESKTOP_URL="https://huggingface.co/speakleash/Bielik-11B-v3.0-Instruct-GGUF/resolve/main/Bielik-11B-v3.0-Instruct.Q4_K_M.gguf"
DESKTOP_FILE="$MODELS/Bielik-11B-v3.0-Instruct.Q4_K_M.gguf"

WANT_PHONE=1
WANT_DESKTOP=0
WANT_OLLAMA=0

for arg in "$@"; do
  case "$arg" in
    --desktop) WANT_DESKTOP=1; WANT_OLLAMA=1 ;;
    --phone-only) WANT_PHONE=1; WANT_DESKTOP=0; WANT_OLLAMA=0 ;;
    --ollama) WANT_OLLAMA=1 ;;
    --all) WANT_PHONE=1; WANT_DESKTOP=1; WANT_OLLAMA=1 ;;
    *) echo "Nieznany argument: $arg" >&2; exit 1 ;;
  esac
done

download() {
  local url="$1" dest="$2"
  if [[ -f "$dest" ]] && [[ $(stat -c%s "$dest" 2>/dev/null || stat -f%z "$dest") -gt 1000000 ]]; then
    echo "OK (już jest): $dest"
    return 0
  fi
  echo "Pobieram: $url"
  echo "  → $dest"
  if command -v curl >/dev/null 2>&1; then
    curl -L --fail --retry 3 -o "$dest.partial" "$url"
  else
    wget -O "$dest.partial" "$url"
  fi
  mv "$dest.partial" "$dest"
  echo "Zapisano: $dest ($(du -h "$dest" | cut -f1))"
}

if [[ "$WANT_PHONE" == 1 ]]; then
  download "$PHONE_URL" "$PHONE_FILE"
fi

if [[ "$WANT_DESKTOP" == 1 ]]; then
  download "$DESKTOP_URL" "$DESKTOP_FILE"
fi

if [[ "$WANT_OLLAMA" == 1 ]]; then
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  if [[ "$OS" == "linux" ]]; then
    # Pełny layout (bin + lib/) — sam ollama bez lib/ nie wczyta modelu
    chmod +x "$ROOT/scripts/bundle_ollama_linux.sh"
    "$ROOT/scripts/bundle_ollama_linux.sh"
  elif [[ "$OS" == "mingw"* ]] || [[ "$OS" == "msys"* ]] || [[ "$OS" == "cygwin"* ]]; then
    chmod +x "$ROOT/scripts/bundle_ollama_windows.sh"
    "$ROOT/scripts/bundle_ollama_windows.sh"
  else
    echo "OS=$OS — ręcznie: ./scripts/bundle_ollama_linux.sh lub bundle_ollama_windows.sh" >&2
  fi
fi

cat > "$MODELS/README.md" <<'EOF'
# Modele lokalne (nie w gicie)

- `Bielik-1.5B-v3.0-Instruct-Q4_K_M.gguf` — telefon + fallback PC (~1 GB)
- `Bielik-11B-v3.0-Instruct.Q4_K_M.gguf` — pełny Bielik v3 na PC (~6.7 GB)

Pobieranie: `./scripts/fetch_ondevice_models.sh --all`
EOF

echo "Gotowe. models/:"
ls -lh "$MODELS"/*.gguf 2>/dev/null || true
