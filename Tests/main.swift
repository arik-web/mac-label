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

print(failures == 0 ? "OK all tests passed" : "\(failures) failure(s)")
exit(failures == 0 ? 0 : 1)
