#!/usr/bin/env bash
# llm_llamacpp deklaruje platformę linux (ffiPlugin), ale w paczce z pub.dev
# nie ma katalogu linux/ — CMake pada: "add_subdirectory .../linux which is not
# an existing directory". Stub wystarczy: natywne liby idą przez Native Assets /
# a desktop Linux i tak używa bundlowanego Ollamy jako głównego backendu.
set -euo pipefail
CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
PKG="$(find "$CACHE/hosted" -maxdepth 2 -type d -name 'llm_llamacpp-*' 2>/dev/null | sort -V | tail -1 || true)"
if [[ -z "$PKG" ]]; then
  echo "Brak llm_llamacpp w pub-cache — pomijam patch" >&2
  exit 0
fi
mkdir -p "$PKG/linux"
TARGET="$PKG/linux/CMakeLists.txt"
cat > "$TARGET" <<'EOF'
# Stub for Flutter Linux FFI plugin (native assets / Ollama provide inference).
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "llm_llamacpp")
project(${PROJECT_NAME} LANGUAGES CXX)

set(llm_llamacpp_bundled_libraries
  ""
  PARENT_SCOPE
)
EOF
echo "Patched $TARGET (FFI stub for Linux)"
