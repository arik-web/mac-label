# Mac Label

Menu bar app that shows which Mac you are on — for desks with several Macs behind one KVM.

- Menu bar title = this Mac's name.
- **Show name on screen** (⌘O in menu) → click-through label, top-left of every display, all Spaces, over full-screen apps.
- **Edit name…** → set any label per Mac. Empty = macOS Computer Name.
- **Launch at login** toggle.

## Install on each Mac

```bash
curl -fsSL https://raw.githubusercontent.com/arik-web/mac-label/main/scripts/install.sh | bash
```

Private repo? Use `gh` (installer uses it when present) or download `MacLabel.zip` from Releases into /Applications.

## Build

```bash
scripts/test.sh        # unit tests (no Xcode needed)
scripts/build-app.sh   # build/MacLabel.app + build/MacLabel.zip (universal)
scripts/install.sh --local
```

Universal binary, macOS 13+, ad-hoc signed (installer clears quarantine).
