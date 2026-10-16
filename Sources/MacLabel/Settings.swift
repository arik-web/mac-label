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
