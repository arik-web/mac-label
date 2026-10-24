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
- **Login & lock screens** (menu: *Show on login & lock screens*). One admin
  prompt installs a login-window agent, so the same styled label shows before
  anyone logs in. On the lock screen no app window can appear, so the label
  is baked into a copy of your wallpaper, centered, at the *Lock screen size*
  you choose (default: same size and color as on screen). The copy is swapped
  in on lock and out on unlock; turning the feature off restores your
  original wallpaper.

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

- `Sources/MacLabel/main.swift` — status item, menu, name editor, login item;
  also runs the login-window mode (`--login-window`, no menu bar).
- `Sources/MacLabel/StyleMenu.swift` — color, size and background submenus.
- `Sources/MacLabel/Overlay.swift` — one borderless, click-through window per display.
- `Sources/MacLabel/LoginLabel.swift` — login-window LaunchAgent plist, the
  machine-wide shared label file, and the admin install/uninstall scripts.
- `Sources/MacLabel/Settings.swift` — everything persisted, in `UserDefaults`
  (`io.github.arikweb.maclabel`), so each Mac keeps its own name and style.

Pure AppKit, no SwiftUI: the macOS 27 SDK's SwiftUI macros need full Xcode, and
this app has nothing that needs SwiftUI.

## Caveats

- **Not notarized.** Downloaded by a browser, Gatekeeper will refuse to open it;
  the install script clears the quarantine flag, or right-click → Open once.
- **Launch at login** may need approving once in System Settings → General →
  Login Items, depending on macOS version.
- **Login & lock screens** need one administrator password at install (it
  writes to `/Library`). Install the app in `/Applications` first — the
  login-window agent points at the copy you toggled it from. With FileVault,
  the very first (pre-boot) unlock screen is drawn by firmware and cannot
  show the label; it appears at the login window right after.

## Windows version

A Windows twin (tray app, same features including login & lock screens)
lives in [`windows/`](windows/README.md), with prebuilt zips produced by
`windows/build-windows.sh`.

## Licence

Public domain — [The Unlicense](LICENSE). No copyright, no attribution
required. Copy it, sell it, fork it, do what you like.
