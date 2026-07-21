#!/usr/bin/env bash
# Paczka Linux: app + Bielik 1.5B + Ollama sidecar (lib/).
# Domyślnie jak Windows CI (1.5B; 11B dociąga się przy 1. starcie z netem).
# Pełna z 11B w ZIP: ./scripts/package_linux_with_llm.sh --full
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FULL=0
for arg in "$@"; do
  case "$arg" in
    --full) FULL=1 ;;
    *) echo "Nieznany argument: $arg" >&2; exit 1 ;;
  esac
done

echo "==> Modele + Ollama…"
if [[ "$FULL" == 1 ]]; then
  ./scripts/fetch_ondevice_models.sh --all
else
  ./scripts/fetch_ondevice_models.sh --phone-only
  ./scripts/bundle_ollama_linux.sh
fi

if [[ ! -f models/Bielik-1.5B-v3.0-Instruct-Q4_K_M.gguf ]]; then
  echo "Brak modelu 1.5B" >&2; exit 1
fi
if [[ "$FULL" == 1 && ! -f models/Bielik-11B-v3.0-Instruct.Q4_K_M.gguf ]]; then
  echo "Brak modelu 11B (--full)" >&2; exit 1
fi
if [[ ! -x bundled/ollama/ollama ]]; then
  echo "Brak bundled/ollama/ollama" >&2; exit 1
fi
if [[ ! -d bundled/ollama/lib/ollama ]]; then
  echo "Brak bundled/ollama/lib/ollama — uruchom scripts/bundle_ollama_linux.sh" >&2
  exit 1
fi

if command -v flutter >/dev/null 2>&1; then
  flutter pub get
  chmod +x scripts/patch_llm_llamacpp_linux.sh scripts/patch_webview_cef_gpu.sh
  ./scripts/patch_llm_llamacpp_linux.sh || true
  ./scripts/patch_webview_cef_gpu.sh || true
  flutter build linux --release || true
fi

PREFIX="$ROOT/build/linux/x64/release/bundle"
if [[ ! -d "$PREFIX" ]]; then
  echo "Brak bundle Linux: $PREFIX" >&2
  exit 1
fi

mkdir -p "$PREFIX/models" "$PREFIX/bundled/ollama"
if [[ "$FULL" == 1 ]]; then
  cp -f "$ROOT/models/"*.gguf "$PREFIX/models/"
else
  cp -f "$ROOT/models/Bielik-1.5B-v3.0-Instruct-Q4_K_M.gguf" "$PREFIX/models/"
fi
# Cały sidecar Ollamy (bin + lib/)
cp -a "$ROOT/bundled/ollama/." "$PREFIX/bundled/ollama/"
chmod +x "$PREFIX/bundled/ollama/ollama"

cat > "$PREFIX/CZYTAJ-MNIE.txt" <<'EOF'
Dialectium - paczka Linux (z lokalnym AI)

1. Rozpakuj ZIP (np. ~/Dialectium).
2. Uruchom: ./dialectium
3. Nic nie instaluj recznie.

W srodku: Bielik 1.5B + Ollama (z bibliotekami lib/). Przy pierwszym
starcie z internetem aplikacja sama dociagnie pelnego Bielika 11B v3.
Bez netu dziala od razu na 1.5B.

Nie usuwaj folderu bundled/ollama/lib — bez niego AI nie dziala.
Na NixOS moze byc potrzebny nix develop / LD_LIBRARY_PATH (GTK, CEF).
EOF

DIST="$ROOT/dist"
mkdir -p "$DIST"
OUT="$DIST/Dialectium-Linux"
rm -rf "$OUT" "$OUT.zip"
cp -a "$PREFIX" "$OUT"
(
  cd "$DIST"
  zip -r -q "Dialectium-Linux.zip" "Dialectium-Linux"
)
echo "Release ZIP: $DIST/Dialectium-Linux.zip"
du -sh "$OUT" "$DIST/Dialectium-Linux.zip"
