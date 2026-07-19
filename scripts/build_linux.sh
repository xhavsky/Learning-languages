#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PREFIX="$ROOT/build/linux/x64/release/bundle"
mkdir -p "$PREFIX"

# First configure/build (may fail on /usr/local install — we fix prefix next)
flutter build linux --release || true

if [[ -f build/linux/x64/release/CMakeCache.txt ]]; then
  sed -i "s|CMAKE_INSTALL_PREFIX:PATH=.*|CMAKE_INSTALL_PREFIX:PATH=$PREFIX|" \
    build/linux/x64/release/CMakeCache.txt
  (cd build/linux/x64/release && ninja install)
fi

echo "Linux bundle: $PREFIX"
ls -la "$PREFIX"
