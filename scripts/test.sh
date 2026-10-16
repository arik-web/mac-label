#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/build"
swiftc -o "$ROOT/build/SettingsTests" \
    "$ROOT/Sources/MacLabel/Settings.swift" "$ROOT/Tests/main.swift"
"$ROOT/build/SettingsTests"
