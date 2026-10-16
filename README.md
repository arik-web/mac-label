# Mac Label

A tiny macOS menu-bar app that tells you which Mac you are looking at — built for
desks with several Macs behind one KVM switch, where every screen looks the same.

```
  Studio  ◐  🔋  Fri 16:27          <- menu bar shows this Mac's name
+----------------+
|  Studio        |                   <- optional on-screen label, top-left
+----------------+                      of every display
```

## What it does

- **Menu-bar name.** The status item is the Mac's name, always visible.
- **On-screen label** (⌘O in the menu). A click-through label in the top-left
  corner of every display, on every Space and over full-screen apps.
- **Your own name per Mac.** *Edit name…* sets any label; leave it empty to fall
  back to the macOS Computer Name.
- **Style.** Text color (presets or any color from the system picker), text size
  (16–72 pt), background from none (text only, with a shadow) to solid.
- **Launch at login**, on by default from the first launch. Turn it off in the menu.

## Requirements

- macOS 13 or later, Apple silicon or Intel (universal binary).
- No Xcode needed to build — the Command Line Tools are enough.

## Install

On each Mac:

```bash
curl -fsSL https://raw.githubusercontent.com/arik-web/mac-label/main/scripts/install.sh | bash
```

That downloads the latest release into `/Applications`, clears the quarantine
flag (the app is ad-hoc signed, not notarized) and starts it. Run it again to update.

Or grab `MacLabel.zip` from [Releases](https://github.com/arik-web/mac-label/releases)
and unzip it into `/Applications`.

## Build

```bash
scripts/test.sh            # unit tests (plain executable; XCTest needs Xcode)
scripts/build-app.sh       # build/MacLabel.app + build/MacLabel.zip
scripts/install.sh --local # install the local build
```

## How it is put together

- `Sources/MacLabel/main.swift` — status item, menu, name editor, login item.
- `Sources/MacLabel/StyleMenu.swift` — color, size and background submenus.
- `Sources/MacLabel/Overlay.swift` — one borderless, click-through window per display.
- `Sources/MacLabel/Settings.swift` — everything persisted, in `UserDefaults`
  (`io.github.arikweb.maclabel`), so each Mac keeps its own name and style.

Pure AppKit, no SwiftUI: the macOS 27 SDK's SwiftUI macros need full Xcode, and
this app has nothing that needs SwiftUI.

## Caveats

- **Not notarized.** Downloaded by a browser, Gatekeeper will refuse to open it;
  the install script clears the quarantine flag, or right-click → Open once.
- **Launch at login** may need approving once in System Settings → General →
  Login Items, depending on macOS version.

## Licence

Public domain — [The Unlicense](LICENSE). No copyright, no attribution
required. Copy it, sell it, fork it, do what you like.
