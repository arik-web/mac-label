#!/bin/bash
#
# Builds self-contained Windows binaries (no .NET install needed on the PC).
# Works on macOS/Linux with the .NET SDK: compilation is cross-platform,
# only running the app needs Windows.
#
# Usage: windows/build-windows.sh
# Output: windows/dist/MacLabel-win-x64.zip, MacLabel-win-arm64.zip

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$ROOT/MacLabel.Windows/MacLabel.Windows.csproj"
DIST="$ROOT/dist"

rm -rf "$DIST"
mkdir -p "$DIST"

for arch in win-x64 win-arm64; do
    out="$DIST/$arch"
    dotnet publish "$PROJECT" -c Release -r "$arch" --self-contained true -o "$out"
    (cd "$out" && zip -q -r "$DIST/MacLabel-$arch.zip" .)
    rm -rf "$out"
    echo "Built: $DIST/MacLabel-$arch.zip"
done
