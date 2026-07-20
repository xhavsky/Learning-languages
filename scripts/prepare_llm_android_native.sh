#!/usr/bin/env bash
# Buduje libllama.so / libggml*.so do jniLibs pakietu llm_llamacpp w pub-cache.
# Wymagane przed: flutter build apk (pakiet z pub.dev nie ma gotowych .so).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="${PUB_CACHE:-$HOME/.pub-cache}"

PKG="$(find "$CACHE/hosted" -maxdepth 2 -type d -name 'llm_llamacpp-*' 2>/dev/null | sort -V | tail -1 || true)"
if [[ -z "$PKG" || ! -d "$PKG/android" ]]; then
  echo "Brak llm_llamacpp w pub-cache — najpierw: flutter pub get" >&2
  exit 1
fi

JNILIBS="$PKG/android/src/main/jniLibs"
need_build=0
for abi in arm64-v8a x86_64; do
  for lib in libllama.so libggml.so libggml-base.so; do
    if [[ ! -f "$JNILIBS/$abi/$lib" ]]; then
      need_build=1
    fi
  done
done
if [[ "$need_build" == 0 ]]; then
  echo "OK: natywne liby już są w $JNILIBS"
  find "$JNILIBS" -name '*.so' | head -20
  exit 0
fi

# NDK
PREFERRED_NDK=26.3.11579264
NDK_PATH="${ANDROID_NDK_HOME:-${ANDROID_NDK:-}}"
if [[ -z "$NDK_PATH" || ! -f "$NDK_PATH/build/cmake/android.toolchain.cmake" ]]; then
  for base in \
    "${ANDROID_HOME:-}/ndk" \
    "${ANDROID_SDK_ROOT:-}/ndk" \
    "$HOME/Android/Sdk/ndk" \
    "/usr/local/lib/android/sdk/ndk"; do
    [[ -d "$base" ]] || continue
    if [[ -d "$base/$PREFERRED_NDK" ]]; then
      NDK_PATH="$base/$PREFERRED_NDK"
      break
    fi
    NDK_PATH="$(find "$base" -maxdepth 1 -mindepth 1 -type d | sort -V | tail -1)"
    [[ -n "$NDK_PATH" ]] && break
  done
fi
if [[ -z "$NDK_PATH" || ! -f "$NDK_PATH/build/cmake/android.toolchain.cmake" ]]; then
  echo "Brak Android NDK (oczekiwany $PREFERRED_NDK)" >&2
  exit 1
fi
TOOLCHAIN="$NDK_PATH/build/cmake/android.toolchain.cmake"
echo "NDK: $NDK_PATH"

LLAMA_SRC="${LLAMA_CPP_SRC:-$HOME/.cache/llama.cpp-src}"
if [[ ! -f "$LLAMA_SRC/CMakeLists.txt" ]]; then
  echo "Klonuję llama.cpp → $LLAMA_SRC"
  rm -rf "$LLAMA_SRC"
  git clone --depth 1 https://github.com/ggml-org/llama.cpp.git "$LLAMA_SRC"
fi

BUILD_ROOT="${ROOT}/build/llama-android-native"
rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT"

build_abi() {
  local ABI="$1"
  local OUT="$BUILD_ROOT/$ABI"
  mkdir -p "$OUT"
  echo "=== CMake $ABI ==="
  cmake -S "$LLAMA_SRC" -B "$OUT" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM=android-28 \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_SERVER=OFF \
    -DLLAMA_BUILD_TOOLS=OFF \
    -DLLAMA_BUILD_APP=OFF \
    -DLLAMA_CURL=OFF \
    -DGGML_NATIVE=OFF \
    -DGGML_LLAMAFILE=OFF \
    -DGGML_BACKEND_DL=OFF \
    -G Ninja
  cmake --build "$OUT" --config Release -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"

  local DEST="$JNILIBS/$ABI"
  rm -rf "$DEST"
  mkdir -p "$DEST"
  # Zbierz .so
  find "$OUT" \( -name 'libllama.so' -o -name 'libggml.so' -o -name 'libggml-base.so' -o -name 'libggml-cpu*.so' \) \
    | while read -r f; do
        cp -f "$f" "$DEST/"
      done
  for req in libllama.so libggml.so libggml-base.so; do
    if [[ ! -f "$DEST/$req" ]]; then
      # czasem leżą pod bin/
      local alt
      alt="$(find "$OUT" -name "$req" | head -1 || true)"
      if [[ -n "$alt" ]]; then
        cp -f "$alt" "$DEST/"
      else
        echo "BRAK $req dla $ABI" >&2
        find "$OUT" -name '*.so' >&2 || true
        exit 1
      fi
    fi
  done
  echo "OK $ABI → $DEST"
  ls -lh "$DEST"
}

# Ninja wymagane
if ! command -v ninja >/dev/null 2>&1; then
  echo "Brak ninja — instaluję hint: apt install ninja-build" >&2
  # spróbuj bez -G Ninja
  build_abi_make() {
    local ABI="$1"
    local OUT="$BUILD_ROOT/$ABI"
    mkdir -p "$OUT"
    cmake -S "$LLAMA_SRC" -B "$OUT" \
      -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
      -DANDROID_ABI="$ABI" \
      -DANDROID_PLATFORM=android-28 \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=ON \
      -DLLAMA_BUILD_TESTS=OFF \
      -DLLAMA_BUILD_EXAMPLES=OFF \
      -DLLAMA_BUILD_SERVER=OFF \
      -DLLAMA_BUILD_TOOLS=OFF \
      -DLLAMA_BUILD_APP=OFF \
      -DLLAMA_CURL=OFF \
      -DGGML_NATIVE=OFF \
      -DGGML_LLAMAFILE=OFF \
      -DGGML_BACKEND_DL=OFF
    cmake --build "$OUT" --config Release -j"$(nproc 2>/dev/null || echo 4)"
    local DEST="$JNILIBS/$ABI"
    rm -rf "$DEST"; mkdir -p "$DEST"
    find "$OUT" \( -name 'libllama.so' -o -name 'libggml.so' -o -name 'libggml-base.so' \) -exec cp -f {} "$DEST/" \;
    for req in libllama.so libggml.so libggml-base.so; do
      [[ -f "$DEST/$req" ]] || { echo "BRAK $req"; exit 1; }
    done
  }
  build_abi_make arm64-v8a
  build_abi_make x86_64
else
  build_abi arm64-v8a
  build_abi x86_64
fi

echo "Gotowe: $JNILIBS"
find "$JNILIBS" -name '*.so' | sort
