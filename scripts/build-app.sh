#!/bin/bash
#
# Builds build/MacLabel.app with the Command Line Tools toolchain (no Xcode).
# Pure AppKit, so the macOS 27 SDK's SwiftUI-macro gap does not apply.
#
# Usage: scripts/build-app.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacLabel"
BUNDLE="$ROOT/build/$APP_NAME.app"
DEPLOYMENT_TARGET="13.0"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

# Universal binary so one zip installs on Apple silicon and Intel Macs.
for arch in arm64 x86_64; do
    swiftc -O \
        -target "$arch-apple-macos$DEPLOYMENT_TARGET" \
        -o "$ROOT/build/$APP_NAME-$arch" \
        "$ROOT"/Sources/MacLabel/*.swift
done
lipo -create -output "$BUNDLE/Contents/MacOS/$APP_NAME" \
    "$ROOT/build/$APP_NAME-arm64" "$ROOT/build/$APP_NAME-x86_64"
rm "$ROOT/build/$APP_NAME-arm64" "$ROOT/build/$APP_NAME-x86_64"

cp "$ROOT/App/Info.plist" "$BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"
plutil -lint "$BUNDLE/Contents/Info.plist" > /dev/null

codesign --force --sign - --identifier io.github.arikweb.maclabel "$BUNDLE"
codesign --verify --strict "$BUNDLE"

(cd "$ROOT/build" && rm -f "$APP_NAME.zip" && ditto -c -k --keepParent "$APP_NAME.app" "$APP_NAME.zip")

echo "Built: $BUNDLE"
echo "Zip:   $ROOT/build/$APP_NAME.zip"
