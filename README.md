# Mac Label

Menu bar app that shows which Mac you are on — for desks with several Macs behind one KVM.

- Menu bar title = this Mac's name.
- **Show name on screen** (⌘O in menu) → click-through label, top-left of every display, all Spaces, over full-screen apps.
- **Edit name…** → set any label per Mac. Empty = macOS Computer Name.
- **Launch at login** toggle.

## Install on each Mac

```bash
gh api repos/arik-web/mac-label/contents/scripts/install.sh -H 'Accept: application/vnd.github.raw' | bash
```

Needs `gh` logged in (repo is private). No gh: download `MacLabel.zip` from Releases, unzip into /Applications.

## Build

```bash
scripts/test.sh        # unit tests (no Xcode needed)
scripts/build-app.sh   # build/MacLabel.app + build/MacLabel.zip (universal)
scripts/install.sh --local
```

Universal binary, macOS 13+, ad-hoc signed (installer clears quarantine).
