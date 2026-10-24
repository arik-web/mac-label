# Mac Label for Windows

The Windows twin of Mac Label: a tray app that tells you which PC you are
looking at — built for desks with several machines behind one KVM switch.

## What it does

- **Tray name.** The tray icon draws this PC's name, with the full name in
  the tooltip and at the top of the right-click menu.
- **On-screen label.** *Show name on screen* — a click-through label in the
  top-left corner of every monitor, always on top.
- **Your own name per PC.** *Edit name…* sets any label; leave it empty to
  fall back to the Windows Computer Name.
- **Style.** Text color (presets or any color), text size (16–72 pt),
  background from none (text only) to solid.
- **Login & lock screens.** *Show on login & lock screens*:
  - Lock: the label is baked, centered, into a copy of your wallpaper at the
    *Lock screen size* you choose (default: same size and color as on
    screen) and swapped in while locked, restored on unlock.
  - Login: the same image is installed as the system lock-screen image
    (one UAC prompt; uses PersonalizationCSP, so Windows Pro/Enterprise/
    Education for that part — the lock-screen swap works everywhere).
- **Launch at startup**, via the HKCU Run key.

Settings live in `%AppData%\MacLabel\settings.json`, so each PC keeps its
own name and style.

## Install

Copy `MacLabel.exe` from the zip for your CPU (`win-x64` or `win-arm64`)
anywhere and run it. It is a self-contained single file — no .NET install
needed. It is not code-signed, so SmartScreen may warn once
(*More info → Run anyway*).

## Build

Needs the .NET 8 SDK (or later). Building works on macOS/Linux; running
needs Windows.

```bash
windows/build-windows.sh     # windows/dist/MacLabel-win-{x64,arm64}.zip
dotnet run --project windows/Tests   # logic tests (name/hex/size rules)
```

## Layout

- `MacLabel.Windows/Program.cs` — entry point, single-instance, elevated
  `--install-lock` helper.
- `MacLabel.Windows/TrayApp.cs` — tray icon, menu, name editor, startup.
- `MacLabel.Windows/OverlayForm.cs` — click-through per-monitor label.
- `MacLabel.Windows/LockImage.cs` — wallpaper bake/swap and the
  login-screen image.
- `MacLabel.Windows/Settings.cs` — persisted choices (no UI dependencies).
