#!/usr/bin/env bash
# Build Android APK Z WBUDOWANYM modelem Bielik 1.5B v3 (użytkownik nic nie ściąga).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FLUTTER_SDK="${FLUTTER_SDK:-$HOME/flutter}"
if [[ ! -x "$FLUTTER_SDK/bin/flutter" ]]; then
  echo "Brak $FLUTTER_SDK — klonuję stable Flutter..."
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_SDK"
fi

UNZIP_BIN="$(command -v unzip || true)"
if [[ -z "$UNZIP_BIN" ]]; then
  UNZIP_BIN="$(nix-build '<nixpkgs>' -A unzip --no-out-link)/bin/unzip"
fi

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

PHONE_GGUF="Bielik-1.5B-v3.0-Instruct-Q4_K_M.gguf"
ASSET_DIR="$ROOT/android/app/src/main/assets/models"
mkdir -p "$ASSET_DIR"

echo "==> Pobieram / sprawdzam model telefonu…"
"$ROOT/scripts/fetch_ondevice_models.sh" --phone-only
if [[ ! -f "$ROOT/models/$PHONE_GGUF" ]]; then
  echo "Brak $ROOT/models/$PHONE_GGUF — nie zbuduję APK bez modelu." >&2
  exit 1
fi
cp -f "$ROOT/models/$PHONE_GGUF" "$ASSET_DIR/$PHONE_GGUF"
echo "Model w APK assets: $ASSET_DIR/$PHONE_GGUF ($(du -h "$ASSET_DIR/$PHONE_GGUF" | cut -f1))"

# Natywne liby llm_llamacpp (jeśli flutter w PATH — lokalnie)
if command -v flutter >/dev/null 2>&1; then
  flutter pub get || true
fi
if [[ -x "$ROOT/scripts/prepare_llm_android_native.sh" ]]; then
  echo "==> Natywne biblioteki llama.cpp…"
  ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-}" "$ROOT/scripts/prepare_llm_android_native.sh" || {
    echo "UWAGA: prepare_llm_android_native.sh nie udał się — CI buduje je sam." >&2
  }
fi

steam-run bash -c "
  export PATH='$FLUTTER_SDK/bin:$(dirname "$UNZIP_BIN"):\$PATH'
  export ANDROID_HOME='$ANDROID_HOME'
  export ANDROID_SDK_ROOT='$ANDROID_SDK_ROOT'
  cd '$ROOT'
  flutter pub get
  flutter build apk --release
"
APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
echo "APK (z modelem w środku): $APK"
mkdir -p "$ROOT/dist"
cp -f "$APK" "$ROOT/dist/Dialectium.apk"
ls -lh "$ROOT/dist/Dialectium.apk"
echo "Użytkownik instaluje TYLKO ten APK — model wypakuje się przy 1. rozmowie AI."
