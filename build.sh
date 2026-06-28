#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "=== Building Lean library ==="
cd "$ROOT/Native"
lake build LeanLink

echo "=== Preparing Cross-Compilation Sysroots ==="
# Get Lean version from lean-toolchain file
TOOLCHAIN_STR="$(cat "$ROOT/Native/lean-toolchain")"
# Format: leanprover/lean4:v4.29.0-rc6
LEAN_VER_TAG="${TOOLCHAIN_STR##*:}" # Output: v4.29.0-rc6
LEAN_VER_NUM="${LEAN_VER_TAG#v}"    # Output: 4.29.0-rc6

CACHE_DIR="$ROOT/Native/shim/.cache/lean_cross"
mkdir -p "$CACHE_DIR"
cd "$CACHE_DIR"

download_sysroot() {
    local platform=$1      # e.g., 'windows' or 'linux'
    local zipname="lean-${LEAN_VER_NUM}-${platform}.zip"
    local url="https://github.com/leanprover/lean4/releases/download/${LEAN_VER_TAG}/${zipname}"
    local ext_dir="${CACHE_DIR}/lean-${LEAN_VER_NUM}-${platform}"
    
    if [ ! -d "$ext_dir" ]; then
        echo "--> Downloading Lean ${LEAN_VER_TAG} for ${platform}..." >&2
        curl -L -f -s "$url" -o "$zipname" || { echo "Failed to download $url" >&2; exit 1; }
        echo "--> Extracting ${zipname}..." >&2
        unzip -q "$zipname"
        rm -f "$zipname"
    fi
    echo "$ext_dir"
}

LINUX_SYSROOT="$(download_sysroot "linux")"
LINUX_ARM_SYSROOT="$(download_sysroot "linux_aarch64")"
WINDOWS_SYSROOT="$(download_sysroot "windows")"
DARWIN_X86_SYSROOT="$(download_sysroot "darwin")"
DARWIN_ARM_SYSROOT="$(download_sysroot "darwin_aarch64")"

# MacOS uses the local `.elan` toolchain via `lean --print-prefix`
MAC_SYSROOT="$(lean --print-prefix 2>/dev/null || echo '')"
# Print puts the path on the FIRST stdout line; wolframscript then echoes the
# expression's "Null" result on a trailing line, so take head -n 1 (not tail).
WL_INCLUDE="$(wolframscript -c 'Print[FileNameJoin[{$InstallationDirectory, "SystemFiles", "IncludeFiles", "C"}]]' 2>/dev/null | head -n 1 || echo '')"

if [ -z "$WL_INCLUDE" ]; then
    echo "ERROR: wolframscript not found to detect WL_INCLUDE."
    exit 1
fi

echo "=== Compiling Targets ==="
cd "$ROOT/Native/shim"

build_target() {
    local sysid=$1
    local lean_home=$2
    local cc=$3
    local osx_arch=${4:-}

    if [ -z "$lean_home" ] || [ ! -d "$lean_home" ]; then
        echo "Skipping $sysid - Sysroot not found at $lean_home"
        return
    fi
    if ! command -v "$cc" &> /dev/null; then
        echo "Skipping $sysid - Compiler $cc not found!"
        return
    fi

    echo "--- Building ${sysid} ---"
    local build_dir="build_${sysid}"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    local CMAKE_CMD=("cmake" "-DLEAN_HOME=${lean_home}" "-DWL_INCLUDE=${WL_INCLUDE}" "-DCMAKE_C_COMPILER=${cc}" "-DWL_SYSID=${sysid}")
    
    if [[ "$sysid" == *"Windows"* ]]; then
        CMAKE_CMD+=("-DCMAKE_SYSTEM_NAME=Windows")
    elif [[ "$sysid" == *"Linux"* ]]; then
        CMAKE_CMD+=("-DCMAKE_SYSTEM_NAME=Linux")
        if [[ "$sysid" == *"ARM"* ]]; then
            CMAKE_CMD+=("-DCMAKE_SYSTEM_PROCESSOR=aarch64")
        fi
    fi

    if [ -n "$osx_arch" ]; then
        CMAKE_CMD+=("-DCMAKE_OSX_ARCHITECTURES=${osx_arch}")
    fi

    "${CMAKE_CMD[@]}" ..
    cmake --build . --config Release --target LeanLinkShim
    cd "$ROOT/Native/shim"
}

# 1. MacOS ARM64
build_target "MacOSX-ARM64" "$DARWIN_ARM_SYSROOT" "clang" "arm64"

# 2. MacOS x86_64
build_target "MacOSX-x86-64" "$DARWIN_X86_SYSROOT" "clang" "x86_64"

# 3. Linux x86_64
build_target "Linux-x86-64" "$LINUX_SYSROOT" "x86_64-linux-gnu-gcc" ""

# 4. Linux ARM64
build_target "Linux-ARM64" "$LINUX_ARM_SYSROOT" "aarch64-linux-gnu-gcc" ""

# 5. Windows x86_64
build_target "Windows-x86-64" "$WINDOWS_SYSROOT" "x86_64-w64-mingw32-gcc" ""

echo "=== Done ==="
ls -lh "$ROOT/LeanLink/LibraryResources/"*/*.dylib "$ROOT/LeanLink/LibraryResources/"*/*.so "$ROOT/LeanLink/LibraryResources/"*/*.dll 2>/dev/null || true
