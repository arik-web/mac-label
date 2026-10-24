import Foundation

// Plain executable test runner: XCTest ships only with Xcode, not the
// Command Line Tools. Run via scripts/test.sh.

var failures = 0

func check(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition {
        failures += 1
        print("FAIL line \(line): \(message)")
    }
}

func freshSettings() -> Settings {
    let suite = "maclabel.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return Settings(defaults: defaults, systemName: { "Studio" })
}

// sanitize
check(Settings.sanitize("  Mini  ") == "Mini", "trims whitespace")
check(Settings.sanitize("   ") == nil, "blank is nil")
check(Settings.sanitize("") == nil, "empty is nil")
check(Settings.sanitize(String(repeating: "x", count: 100))?.count == Settings.maxNameLength, "caps length")

// default name falls back to system name
let s1 = freshSettings()
check(s1.displayName == "Studio", "defaults to computer name")
check(!s1.hasCustomName, "no custom name by default")

// custom name is stored trimmed
s1.setDisplayName("  Mac mini (left)  ")
check(s1.displayName == "Mac mini (left)", "custom name stored trimmed")
check(s1.hasCustomName, "custom name flagged")

// empty resets to system name
s1.setDisplayName("")
check(s1.displayName == "Studio", "empty resets to computer name")
check(!s1.hasCustomName, "reset clears custom flag")

// overlay flag persists
let s2 = freshSettings()
check(!s2.overlayVisible, "overlay off by default")
s2.overlayVisible = true
check(s2.overlayVisible, "overlay toggles on")

// hex parsing
check(Settings.normalizeHex("#ffcc00") == "FFCC00", "normalizes hex")
check(Settings.normalizeHex("FFF") == nil, "rejects short hex")
check(Settings.normalizeHex("GGGGGG") == nil, "rejects non-hex")
let rgb = Settings.rgb(fromHex: "FF8000")
check(rgb.red == 1 && rgb.blue == 0 && abs(rgb.green - 128.0 / 255) < 0.001, "hex to rgb")

// style defaults and persistence
let s3 = freshSettings()
check(s3.textColorHex == "FFFFFF", "color defaults to white")
check(s3.fontSize == Settings.defaultFontSize, "size default")
check(s3.backgroundOpacity == Settings.defaultOpacity, "opacity default")
s3.textColorHex = "#00ff00"
check(s3.textColorHex == "00FF00", "color stored")
s3.textColorHex = "nope"
check(s3.textColorHex == "00FF00", "bad color ignored")
s3.fontSize = 500
check(s3.fontSize == Settings.fontSizeRange.upperBound, "size clamped high")
s3.fontSize = 32
check(s3.fontSize == 32, "size stored")
s3.backgroundOpacity = -1
check(s3.backgroundOpacity == 0, "opacity clamped low")
s3.backgroundOpacity = 0.25
check(s3.backgroundOpacity == 0.25, "opacity stored")

// launch-at-login default applies once
let s4 = freshSettings()
check(s4.takeFirstLaunchLoginDefault(), "first launch applies login default")
check(!s4.takeFirstLaunchLoginDefault(), "later launches do not")

// login & lock flag persists, off by default
let s5 = freshSettings()
check(!s5.loginLockVisible, "login & lock off by default")
s5.loginLockVisible = true
check(s5.loginLockVisible, "login & lock toggles on")

// lock-screen size: 0 = same as on-screen (default), else clamped choice
let s6 = freshSettings()
check(s6.lockFontSize == 0, "lock size defaults to same-as-screen")
check(s6.effectiveLockFontSize == Settings.defaultFontSize, "lock size follows screen size by default")
s6.fontSize = 32
check(s6.effectiveLockFontSize == 32, "lock size follows screen size change")
s6.lockFontSize = 48
check(s6.effectiveLockFontSize == 48, "chosen lock size wins")
s6.lockFontSize = 999
check(s6.effectiveLockFontSize == Settings.fontSizeRange.upperBound, "lock size clamped")
s6.lockFontSize = 0
check(s6.effectiveLockFontSize == 32, "reset lock size follows screen again")

// lock wallpaper fingerprint tracks drawn inputs
let key1 = Settings.lockWallpaperKey(name: "Studio", colorHex: "FFD60A", backgroundOpacity: 0.2, effectiveLockFontSize: 22, sourcePaths: ["/a.jpg"])
check(key1 == Settings.lockWallpaperKey(name: "Studio", colorHex: "FFD60A", backgroundOpacity: 0.2, effectiveLockFontSize: 22, sourcePaths: ["/a.jpg"]), "wallpaper key stable")
check(key1 != Settings.lockWallpaperKey(name: "Studio", colorHex: "FFD60A", backgroundOpacity: 0.2, effectiveLockFontSize: 48, sourcePaths: ["/a.jpg"]), "wallpaper key changes with lock size")
check(key1 != Settings.lockWallpaperKey(name: "Studio", colorHex: "FFFFFF", backgroundOpacity: 0.2, effectiveLockFontSize: 22, sourcePaths: ["/a.jpg"]), "wallpaper key changes with color")

// shared label round-trips and is sanitized on decode
let shared = LoginLabel.Shared(name: "Studio", colorHex: "FFD60A", fontSize: 32, backgroundOpacity: 0.4)
check(LoginLabel.Shared.decoded(from: shared.encoded()!) == shared, "shared label round-trips")
let dirty = LoginLabel.Shared(name: "  Pad  ", colorHex: "nope", fontSize: 999, backgroundOpacity: 2)
let cleaned = LoginLabel.Shared.decoded(from: dirty.encoded()!)
check(cleaned?.name == "Pad", "shared name trimmed")
check(cleaned?.colorHex == Settings.defaultColorHex, "bad shared color falls back")
check(cleaned?.fontSize == Settings.fontSizeRange.upperBound, "shared size clamped")
check(cleaned?.backgroundOpacity == 1, "shared opacity clamped")
check(LoginLabel.Shared.decoded(from: Data("junk".utf8)) == nil, "junk shared label rejected")

// login-window agent plist targets only the LoginWindow session
let plist = LoginLabel.agentPlist(executablePath: "/Applications/MacLabel.app/Contents/MacOS/MacLabel")
check(plist.contains("<string>LoginWindow</string>"), "agent limited to LoginWindow session")
check(plist.contains(LoginLabel.loginWindowArgument), "agent passes login-window flag")
check(plist.contains("/Applications/MacLabel.app/Contents/MacOS/MacLabel"), "agent points at executable")
check(LoginLabel.agentPlist(executablePath: "/tmp/a&b").contains("/tmp/a&amp;b"), "plist escapes path")

// shell quoting and admin scripts
check(LoginLabel.shellQuoted("it's") == "'it'\\''s'", "shell quote escapes single quote")
let install = LoginLabel.installScript(executablePath: "/Applications/MacLabel.app/Contents/MacOS/MacLabel", shared: shared)
check(install.contains(LoginLabel.agentPlistPath), "install writes agent plist")
check(install.contains("defaults delete"), "install clears old lock-screen message")
check(!install.contains("defaults write /Library/Preferences/com.apple.loginwindow"), "install does not set small lock text")
check(install.contains(LoginLabel.sharedFilePath), "install seeds shared label")
check(LoginLabel.uninstallScript().contains("defaults delete"), "uninstall clears lock-screen message")

// centered origin for the baked lock label
let origin = Settings.centeredOrigin(container: CGSize(width: 1000, height: 800), box: CGSize(width: 200, height: 100))
check(origin.x == 400 && origin.y == 350, "box centered in container")

print(failures == 0 ? "OK all tests passed" : "\(failures) failure(s)")
exit(failures == 0 ? 0 : 1)
