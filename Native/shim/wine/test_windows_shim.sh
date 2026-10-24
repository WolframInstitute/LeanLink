#!/usr/bin/env bash
# Loads the Windows shim under Wine, in an x86-64 Linux container, as LeanImport does on Windows: the shim with
# Lean's Windows runtime DLLs next to it, an environment of Init from the toolchain's oleans, and a query. It
# fails if any symbol the shim imports is missing from the DLL it names (on Windows, LoadLibrary's error 127)
# or if the environment or the query fails.
#
#     Native/shim/wine/test_windows_shim.sh [libLeanLinkShim.dll]
#
# Needs Docker, x86_64-w64-mingw32-gcc, wolframscript (for LibraryLink's headers), lean, and the Windows
# sysroot that build.sh caches. The first run builds an image with Wine, a download of a few hundred MB.
# Wine is not Windows: a pass here is a check before a release, not a substitute for a Windows session.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
SHIM="${1:-$ROOT/LeanLink/LibraryResources/Windows-x86-64/libLeanLinkShim.dll}"
TOOLCHAIN_STR="$(cat "$ROOT/Native/lean-toolchain")"
LEAN_VER_NUM="${TOOLCHAIN_STR##*:v}"
SYSROOT="$ROOT/Native/shim/.cache/lean_cross/lean-${LEAN_VER_NUM}-windows"
OLEANS="$(lean --print-prefix)/lib/lean"
WL_INCLUDE="$(wolframscript -c 'Print[FileNameJoin[{$InstallationDirectory, "SystemFiles", "IncludeFiles", "C"}]]' 2>/dev/null | head -n 1)"
IMAGE="leanlink-wine:bookworm"

for path in "$SHIM" "$SYSROOT/bin" "$OLEANS/Init.olean" "$WL_INCLUDE/WolframLibrary.h"; do
    if [ ! -e "$path" ]; then
        echo "ERROR: $path not found; run ./build.sh first (it caches the Windows sysroot and builds the shim)."
        exit 1
    fi
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The harness, and the stand-in for Windows' icu.dll, which Wine lacks and Lean's runtime imports
x86_64-w64-mingw32-gcc -O2 -I"$WL_INCLUDE" -o "$WORK/shim_harness.exe" "$HERE/shim_harness.c"
x86_64-w64-mingw32-gcc -O2 -shared -o "$WORK/icu.dll" "$HERE/icu_stub.c"
cp "$SHIM" "$WORK/libLeanLinkShim.dll"
cp "$SYSROOT"/bin/*.dll "$WORK/"

if [ -z "$(docker images -q "$IMAGE")" ]; then
    echo "=== Building the image $IMAGE with Wine ==="
    docker build --platform linux/amd64 -t "$IMAGE" - <<'DOCKERFILE'
FROM debian:bookworm-slim
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends wine wine64 && rm -rf /var/lib/apt/lists/*
ENV WINEPREFIX=/root/.wine
RUN WINEDEBUG=-all wineboot --init || true
DOCKERFILE
fi

echo "=== Loading $(basename "$SHIM") under Wine ==="
# Wine binds an import that a DLL does not export to a stub, and says so, where Windows refuses the DLL
docker run --rm --platform linux/amd64 -v "$WORK":/work:ro -v "$OLEANS":/lean:ro "$IMAGE" bash -c \
    'cd /work && WINEDEBUG=warn+module wine shim_harness.exe "Z:\\work\\libLeanLinkShim.dll" Init "Z:\\lean" Init.Prelude' \
    > "$WORK/wine.log" 2>&1 || true

grep -E "^(shim loaded|load environment|module constant kinds|LoadLibrary failed|an entry point)" "$WORK/wine.log" || true
UNRESOLVED="$(grep -c "No implementation for .* imported from .*libLeanLinkShim.dll" "$WORK/wine.log" || true)"
if [ "$UNRESOLVED" != "0" ]; then
    echo "FAILED: $UNRESOLVED symbols the shim imports are not exported by the DLL it names (Windows: error 127), e.g."
    grep "No implementation for .* imported from .*libLeanLinkShim.dll" "$WORK/wine.log" | head -5 | sed -e 's/.*No implementation for /  /' -e 's/ imported from.*//'
    exit 1
fi
if ! grep -q "^module constant kinds: error 0" "$WORK/wine.log"; then
    echo "FAILED: the shim did not load Init and answer the query; Wine's log ends:"
    tail -20 "$WORK/wine.log"
    exit 1
fi
echo "OK: every import resolves, and the shim loads Init and answers a query."
