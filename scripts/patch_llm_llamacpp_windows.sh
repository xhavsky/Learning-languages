#!/usr/bin/env bash
# Poprawia llm_llamacpp Windows CMake: pusty INSTALL_BUNDLE_LIB_DIR → "install FILES given no DESTINATION".
# Ollama na Windows i tak jest głównym backendem — brak llama.dll nie blokuje builda.
set -euo pipefail
CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
PKG="$(find "$CACHE/hosted" -maxdepth 2 -type d -name 'llm_llamacpp-*' 2>/dev/null | sort -V | tail -1 || true)"
if [[ -z "$PKG" || ! -f "$PKG/windows/CMakeLists.txt" ]]; then
  echo "Brak llm_llamacpp/windows — pomijam patch" >&2
  exit 0
fi
TARGET="$PKG/windows/CMakeLists.txt"
cat > "$TARGET" <<'EOF'
# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "llm_llamacpp")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "llm_llamacpp_plugin")

add_library(${PLUGIN_NAME} SHARED
  "llm_llamacpp_plugin.cpp"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# List of absolute paths to libraries that should be bundled with the plugin.
# llama.dll is optional — Windows desktop uses bundled Ollama for Bielik.
set(llm_llamacpp_bundled_libraries
  ""
  PARENT_SCOPE
)
EOF
echo "Patched $TARGET (no broken install DESTINATION)"
