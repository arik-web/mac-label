import Foundation

/// Persisted user choices. Everything lives in the app's UserDefaults domain,
/// so each Mac keeps its own label.
struct Settings {
    static let nameKey = "displayName"
    static let overlayKey = "overlayVisible"
    static let maxNameLength = 40

    let defaults: UserDefaults
    let systemName: () -> String

    init(defaults: UserDefaults = .standard,
         systemName: @escaping () -> String = Settings.computerName) {
        self.defaults = defaults
        self.systemName = systemName
    }

    /// The macOS "Computer Name" from Sharing settings, falling back to the host name.
    static func computerName() -> String {
        Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    }

    /// Trims whitespace and caps length. Returns nil for an empty name, which
    /// means "use the computer name".
    static func sanitize(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxNameLength))
    }

    var displayName: String {
        defaults.string(forKey: Settings.nameKey).flatMap(Settings.sanitize) ?? systemName()
    }

    var hasCustomName: Bool {
        defaults.string(forKey: Settings.nameKey).flatMap(Settings.sanitize) != nil
    }

    func setDisplayName(_ raw: String) {
        if let name = Settings.sanitize(raw) {
            defaults.set(name, forKey: Settings.nameKey)
        } else {
            defaults.removeObject(forKey: Settings.nameKey)
        }
    }

    var overlayVisible: Bool {
        get { defaults.bool(forKey: Settings.overlayKey) }
        nonmutating set { defaults.set(newValue, forKey: Settings.overlayKey) }
    }

    static let loginLockKey = "loginLockVisible"

    /// User wants the label at the login window and on the lock screen.
    /// Takes effect only after the one-time admin install in LoginLabel.
    var loginLockVisible: Bool {
        get { defaults.bool(forKey: Settings.loginLockKey) }
        nonmutating set { defaults.set(newValue, forKey: Settings.loginLockKey) }
    }

    static let lockSizeKey = "lockFontSize"

    /// Lock-screen label size in pt. 0 (default) = same as the on-screen size.
    var lockFontSize: Double {
        get {
            guard let size = defaults.object(forKey: Settings.lockSizeKey) as? Double, size != 0 else { return 0 }
            return size.clamped(to: Settings.fontSizeRange)
        }
        nonmutating set {
            defaults.set(newValue == 0 ? 0 : newValue.clamped(to: Settings.fontSizeRange),
                         forKey: Settings.lockSizeKey)
        }
    }

    /// Size actually used on the lock screen: the lock size, or the
    /// on-screen size when the lock size is left at "same".
    var effectiveLockFontSize: Double {
        lockFontSize == 0 ? fontSize : lockFontSize
    }

    static let wallpaperHashKey = "lockWallpaperHash"
    static let wallpaperOriginalsKey = "wallpaperOriginals"

    /// Fingerprint of the last baked lock wallpaper; empty = none baked.
    var lockWallpaperHash: String {
        get { defaults.string(forKey: Settings.wallpaperHashKey) ?? "" }
        nonmutating set { defaults.set(newValue, forKey: Settings.wallpaperHashKey) }
    }

    /// Wallpaper paths in use before the first bake, per screen.
    var wallpaperOriginals: [String] {
        get { defaults.stringArray(forKey: Settings.wallpaperOriginalsKey) ?? [] }
        nonmutating set { defaults.set(newValue, forKey: Settings.wallpaperOriginalsKey) }
    }

    /// Changes whenever anything drawn into the lock wallpaper changes.
    static func lockWallpaperKey(name: String, colorHex: String, backgroundOpacity: Double,
                                 effectiveLockFontSize: Double, sourcePaths: [String]) -> String {
        ([name, colorHex, String(backgroundOpacity), String(effectiveLockFontSize)] + sourcePaths)
            .joined(separator: "|")
    }

    /// Top-left corner that centers a box in a container. Centered, so
    /// wallpaper fill-cropping at the edges can never cut the label off.
    static func centeredOrigin(container: CGSize, box: CGSize) -> CGPoint {
        CGPoint(x: (container.width - box.width) / 2, y: (container.height - box.height) / 2)
    }

    static let loginDefaultKey = "loginItemDefaultApplied"

    /// True exactly once per Mac: the first launch turns launch-at-login on,
    /// and after that the menu toggle is the only thing that changes it.
    func takeFirstLaunchLoginDefault() -> Bool {
        guard !defaults.bool(forKey: Settings.loginDefaultKey) else { return false }
        defaults.set(true, forKey: Settings.loginDefaultKey)
        return true
    }

    // MARK: Label style

    static let colorKey = "textColor"
    static let sizeKey = "fontSize"
    static let opacityKey = "backgroundOpacity"

    static let defaultColorHex = "FFFFFF"
    static let defaultFontSize = 22.0
    static let defaultOpacity = 0.6
    static let fontSizeRange = 10.0...120.0

    /// "#ffcc00" / "FFCC00" → "FFCC00"; nil when not six hex digits.
    static func normalizeHex(_ raw: String) -> String? {
        let hex = raw.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "#", with: "").uppercased()
        guard hex.count == 6, UInt32(hex, radix: 16) != nil else { return nil }
        return hex
    }

    /// RGB components in 0...1 for a normalized hex string.
    static func rgb(fromHex hex: String) -> (red: Double, green: Double, blue: Double) {
        let value = UInt32(normalizeHex(hex) ?? defaultColorHex, radix: 16) ?? 0xFFFFFF
        return (Double((value >> 16) & 0xFF) / 255,
                Double((value >> 8) & 0xFF) / 255,
                Double(value & 0xFF) / 255)
    }

    var textColorHex: String {
        get { defaults.string(forKey: Settings.colorKey).flatMap(Settings.normalizeHex) ?? Settings.defaultColorHex }
        nonmutating set {
            if let hex = Settings.normalizeHex(newValue) { defaults.set(hex, forKey: Settings.colorKey) }
        }
    }

    var fontSize: Double {
        get {
            guard let size = defaults.object(forKey: Settings.sizeKey) as? Double else { return Settings.defaultFontSize }
            return size.clamped(to: Settings.fontSizeRange)
        }
        nonmutating set { defaults.set(newValue.clamped(to: Settings.fontSizeRange), forKey: Settings.sizeKey) }
    }

    /// Opacity of the dark box behind the text: 0 = text only, 1 = solid.
    var backgroundOpacity: Double {
        get {
            guard let opacity = defaults.object(forKey: Settings.opacityKey) as? Double else { return Settings.defaultOpacity }
            return opacity.clamped(to: 0...1)
        }
        nonmutating set { defaults.set(newValue.clamped(to: 0...1), forKey: Settings.opacityKey) }
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
