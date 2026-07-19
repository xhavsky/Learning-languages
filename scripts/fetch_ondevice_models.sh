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
  mkdir -p "$OLLAMA_DIR"
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64|amd64) ARCH=amd64 ;;
    aarch64|arm64) ARCH=arm64 ;;
  esac
  # Oficjalne release Ollama (Linux tgz / Windows zip)
  if [[ "$OS" == "linux" ]]; then
    OLLAMA_TGZ="https://github.com/ollama/ollama/releases/latest/download/ollama-linux-${ARCH}.tgz"
    TMP="$(mktemp -d)"
    echo "Pobieram Ollama Linux ($ARCH)…"
    curl -L --fail -o "$TMP/ollama.tgz" "$OLLAMA_TGZ"
    tar -xzf "$TMP/ollama.tgz" -C "$TMP"
    # Layout release bywa różny — szukamy binarki
    BIN="$(find "$TMP" -type f -name ollama | head -1)"
    if [[ -z "$BIN" ]]; then
      echo "Nie znaleziono binarki ollama w archiwum" >&2
      exit 1
    fi
    cp "$BIN" "$OLLAMA_DIR/ollama"
    chmod +x "$OLLAMA_DIR/ollama"
    rm -rf "$TMP"
    echo "Ollama → $OLLAMA_DIR/ollama"
  elif [[ "$OS" == "mingw"* ]] || [[ "$OS" == "msys"* ]] || [[ "$OS" == "cygwin"* ]]; then
    echo "Windows: pobierz ollama.exe z https://ollama.com/download i połóż w bundled/ollama/"
  else
    echo "OS=$OS — ręcznie skopiuj binarkę Ollamy do $OLLAMA_DIR"
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
