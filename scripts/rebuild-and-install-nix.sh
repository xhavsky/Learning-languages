#!/usr/bin/env bash
set -euo pipefail
exec > >(tee /tmp/dialectium-rebuild-install.log) 2>&1
set -x

pkill -f 'dialectium' 2>/dev/null || true
sleep 1

ROOT="/home/adam/Dokumenty/Projekty/Learning-languages"
BUNDLE="/home/adam/.nixos-config/pkgs/dialectium-bundle"
cd "$ROOT"

# Find flutter
if command -v flutter >/dev/null 2>&1; then
  FLUTTER=(flutter)
elif [[ -x /home/adam/flutter/bin/flutter ]]; then
  FLUTTER=(/home/adam/flutter/bin/flutter)
else
  FLUTTER=(nix-shell -p flutter --run "flutter")
fi

echo "Using flutter via: ${FLUTTER[*]}"

# Prefer nix-shell -p flutter for full env if flutter not on PATH
if ! command -v flutter >/dev/null 2>&1; then
  nix-shell -p flutter --run "cd '$ROOT' && flutter pub get && flutter build linux --release" || true
else
  flutter pub get
  flutter build linux --release || true
fi

PREFIX="$ROOT/build/linux/x64/release/bundle"
if [[ -f build/linux/x64/release/CMakeCache.txt ]]; then
  sed -i "s|CMAKE_INSTALL_PREFIX:PATH=.*|CMAKE_INSTALL_PREFIX:PATH=$PREFIX|" \
    build/linux/x64/release/CMakeCache.txt
  (cd build/linux/x64/release && ninja install)
fi

test -x "$PREFIX/dialectium"
test -f "$PREFIX/data/flutter_assets/version.json"
cat "$PREFIX/data/flutter_assets/version.json"

rm -rf "${BUNDLE:?}"/*
cp -a "$PREFIX"/. "$BUNDLE"/

# Update version in nix
sed -i 's/version = "0.0.1"/version = "0.0.10"/' \
  /home/adam/.nixos-config/pkgs/learning-languages.nix
# also handle other old versions
sed -i 's/version = "1.0.0"/version = "0.0.10"/' \
  /home/adam/.nixos-config/pkgs/learning-languages.nix || true

grep version /home/adam/.nixos-config/pkgs/learning-languages.nix | head -3
cat "$BUNDLE/data/flutter_assets/version.json"

# Track new files for flake if needed
cd /home/adam/.nixos-config
git add pkgs/learning-languages.nix pkgs/dialectium-bundle 2>/dev/null || true

if type nrs >/dev/null 2>&1; then
  nrs
else
  sudo nixos-rebuild switch --flake ~/.nixos-config#nixos
fi

echo "=== which ==="
which dialectium
TJ="$(readlink -f "$(which dialectium)")"
echo "TJ=$TJ"
cat "$(dirname "$TJ")/../lib/dialectium/data/flutter_assets/version.json" || \
  find "$(dirname "$TJ")/.." -name version.json -print -exec cat {} \;

rm -f /home/adam/Dokumenty/dialectium-boot.log
timeout 25s dialectium 2>&1 | tee /tmp/dialectium-new-run.log || true
echo "=== boot log ==="
cat /home/adam/Dokumenty/dialectium-boot.log || echo 'no boot log'
echo "DONE"
