#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "=== Building Lean library ==="
cd "$ROOT/Native"
lake build LeanLink

echo "=== Building C shim ==="
cd "$ROOT/Native/shim"
mkdir -p build
cd build
cmake ..
make LeanLinkShim

echo "=== Done ==="
ls -lh "$ROOT/LeanLink/LibraryResources/"*/*.dylib "$ROOT/LeanLink/LibraryResources/"*/*.so 2>/dev/null || true
