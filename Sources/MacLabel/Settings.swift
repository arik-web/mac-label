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
}
