#!/bin/bash
#
# Installs the latest MacLabel release on this Mac.
#   curl -fsSL https://raw.githubusercontent.com/arik-web/mac-label/main/scripts/install.sh | bash
# Or, from a checkout after scripts/build-app.sh:  scripts/install.sh --local

set -euo pipefail

REPO="arik-web/mac-label"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [[ "${1:-}" == "--local" ]]; then
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    cp "$ROOT/build/MacLabel.zip" "$TMP/MacLabel.zip"
elif command -v gh >/dev/null; then
    gh release download --repo "$REPO" --pattern MacLabel.zip --dir "$TMP"
else
    curl -fsSL -o "$TMP/MacLabel.zip" "https://github.com/$REPO/releases/latest/download/MacLabel.zip"
fi

pkill -x MacLabel 2>/dev/null || true
rm -rf /Applications/MacLabel.app
ditto -x -k "$TMP/MacLabel.zip" /Applications
# Ad-hoc signed, not notarized: clear quarantine so Gatekeeper lets it open.
xattr -dr com.apple.quarantine /Applications/MacLabel.app 2>/dev/null || true
open /Applications/MacLabel.app
echo "Installed /Applications/MacLabel.app"
