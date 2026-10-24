import Foundation

/// Everything needed to show the label where the normal app cannot run:
/// the pre-login login window (a LaunchAgent in the LoginWindow session)
/// and the secure lock screen (the system's own `LoginwindowText`).
enum LoginLabel {
    static let agentLabel = "io.github.arikweb.maclabel.login"
    static let agentPlistPath = "/Library/LaunchAgents/io.github.arikweb.maclabel.login.plist"
    static let sharedDirectoryPath = "/Library/Application Support/MacLabel"
    static let sharedFilePath = "/Library/Application Support/MacLabel/label.json"
    static let loginWindowArgument = "--login-window"

    /// One shared, machine-wide copy of the label. Written by the user app
    /// after a one-time admin install made the directory writable; read by
    /// the login-window agent, which runs before any user has logged in and
    /// so cannot see the user's UserDefaults.
    struct Shared: Codable, Equatable {
        var name: String
        var colorHex: String
        var fontSize: Double
        var backgroundOpacity: Double

        func encoded() -> Data? { try? JSONEncoder().encode(self) }

        static func decoded(from data: Data) -> Shared? {
            guard let value = try? JSONDecoder().decode(Shared.self, from: data),
                  Settings.sanitize(value.name) != nil else { return nil }
            return Shared(name: Settings.sanitize(value.name)!,
                          colorHex: Settings.normalizeHex(value.colorHex) ?? Settings.defaultColorHex,
                          fontSize: value.fontSize.clamped(to: Settings.fontSizeRange),
                          backgroundOpacity: value.backgroundOpacity.clamped(to: 0...1))
        }
    }

    static var isAgentInstalled: Bool {
        FileManager.default.fileExists(atPath: agentPlistPath)
    }

    @discardableResult
    static func writeShared(_ shared: Shared) -> Bool {
        guard let data = shared.encoded() else { return false }
        // Non-atomic: the install script pre-creates this file world-writable.
        // An atomic replace would swap in a user-owned file the next writer
        // (possibly a different user on a shared Mac) could not overwrite.
        return (try? data.write(to: URL(fileURLWithPath: sharedFilePath), options: [])) != nil
    }

    static func readShared() -> Shared? {
        FileManager.default.contents(atPath: sharedFilePath).flatMap(Shared.decoded(from:))
    }

    /// LaunchAgent that runs the same binary at the login window.
    /// `LimitLoadToSessionType = LoginWindow` keeps it out of Aqua sessions,
    /// where the normal menu-bar app already shows the label.
    static func agentPlist(executablePath: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(agentLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(xmlEscaped(executablePath))</string>
                <string>\(loginWindowArgument)</string>
            </array>
            <key>LimitLoadToSessionType</key>
            <string>LoginWindow</string>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """
    }

    /// Admin shell script: installs the agent, seeds the shared label,
    /// and sets the system lock-screen message. Run via an admin prompt.
    static func installScript(executablePath: String, shared: Shared) -> String {
        let plistBase64 = Data(agentPlist(executablePath: executablePath).utf8).base64EncodedString()
        let labelBase64 = (shared.encoded() ?? Data()).base64EncodedString()
        return """
        set -e
        mkdir -p \(shellQuoted(sharedDirectoryPath)) /Library/LaunchAgents
        echo \(shellQuoted(plistBase64)) | base64 -d > \(shellQuoted(agentPlistPath))
        chmod 644 \(shellQuoted(agentPlistPath))
        echo \(shellQuoted(labelBase64)) | base64 -d > \(shellQuoted(sharedFilePath))
        chmod 666 \(shellQuoted(sharedFilePath))
        chmod 777 \(shellQuoted(sharedDirectoryPath))
        defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null || true
        """
    }

    /// Admin shell script: removes the agent, shared label and lock message.
    static func uninstallScript() -> String {
        """
        rm -f \(shellQuoted(agentPlistPath))
        rm -rf \(shellQuoted(sharedDirectoryPath))
        defaults delete /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null || true
        """
    }

    static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func xmlEscaped(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
