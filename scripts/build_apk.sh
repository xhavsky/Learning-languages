#!/usr/bin/env bash
# Build Android APK on NixOS (steam-run + lokalny Flutter SDK).
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

steam-run bash -c "
  export PATH='$FLUTTER_SDK/bin:$(dirname "$UNZIP_BIN"):\$PATH'
  export ANDROID_HOME='$ANDROID_HOME'
  export ANDROID_SDK_ROOT='$ANDROID_SDK_ROOT'
  cd '$ROOT'
  flutter pub get
  flutter build apk --release
"
echo "APK: $ROOT/build/app/outputs/flutter-apk/app-release.apk"
