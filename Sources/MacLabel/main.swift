import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private let overlay = Overlay()
    private lazy var styleMenu = StyleMenu(settings: settings) { [weak self] in self?.refresh() }
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    private let overlayItem = NSMenuItem(title: "Show name on screen",
                                         action: #selector(toggleOverlay), keyEquivalent: "o")
    private let loginLockItem = NSMenuItem(title: "Show on login & lock screens",
                                           action: #selector(toggleLoginLock), keyEquivalent: "")
    private let resetItem = NSMenuItem(title: "Reset to computer name",
                                       action: #selector(resetName), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at login",
                                       action: #selector(toggleLogin), keyEquivalent: "")

    private var isLocked = false

    private var sharedLabel: LoginLabel.Shared {
        LoginLabel.Shared(name: settings.displayName, colorHex: settings.textColorHex,
                          fontSize: settings.fontSize, backgroundOpacity: settings.backgroundOpacity)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.addItem(overlayItem)
        menu.addItem(loginLockItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Edit name…", action: #selector(editName), keyEquivalent: "e"))
        menu.addItem(resetItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: "Quit Mac Label", action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        menu.items.filter { $0.action != #selector(NSApplication.terminate(_:)) }
            .forEach { $0.target = self }
        menu.insertItem(.separator(), at: 3)
        styleMenu.items.reversed().forEach { menu.insertItem($0, at: 3) }
        statusItem.menu = menu

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(screenLocked),
            name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(screenUnlocked),
            name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)

        if settings.takeFirstLaunchLoginDefault(), SMAppService.mainApp.status != .enabled {
            // Best effort: on failure the menu toggle shows off and can be retried.
            try? SMAppService.mainApp.register()
        }

        refresh()
    }

    private func refresh() {
        let name = settings.displayName
        statusItem.button?.title = name
        overlayItem.state = settings.overlayVisible ? .on : .off
        loginLockItem.state = settings.loginLockVisible && LoginLabel.isAgentInstalled ? .on : .off
        resetItem.isEnabled = settings.hasCustomName
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        styleMenu.refreshChecks()
        if settings.loginLockVisible && LoginLabel.isAgentInstalled {
            LoginLabel.writeShared(sharedLabel)
            LockWallpaper.applyIfNeeded(settings: settings, name: name)
            if isLocked {
                LockWallpaper.activate(settings: settings)
            } else {
                LockWallpaper.deactivate(settings: settings)
            }
        }
        if isLocked && settings.loginLockVisible && LoginLabel.isAgentInstalled {
            // Locked: styled label at the chosen lock size, same color.
            overlay.show(text: name, style: styleMenu.lockStyle)
        } else if settings.overlayVisible {
            overlay.show(text: name, style: styleMenu.style)
        } else {
            overlay.hide()
        }
    }

    @objc private func screenLocked() {
        isLocked = true
        refresh()
    }

    @objc private func screenUnlocked() {
        isLocked = false
        refresh()
    }

    @objc private func toggleOverlay() {
        settings.overlayVisible.toggle()
        refresh()
    }

    @objc private func toggleLoginLock() {
        let executable = Bundle.main.executablePath ?? CommandLine.arguments[0]
        if settings.loginLockVisible && LoginLabel.isAgentInstalled {
            guard runAdmin(script: LoginLabel.uninstallScript()) else { return }
            LockWallpaper.restore(settings: settings)
            settings.loginLockVisible = false
        } else {
            guard runAdmin(script: LoginLabel.installScript(executablePath: executable,
                                                            shared: sharedLabel)) else { return }
            settings.loginLockVisible = true
        }
        refresh()
    }

    /// Runs a shell script as root via the standard admin prompt.
    /// False on failure or a cancelled prompt; failure shows an alert.
    private func runAdmin(script: String) -> Bool {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("maclabel-admin-\(UUID().uuidString).sh")
        do { try script.write(to: url, atomically: true, encoding: .utf8) }
        catch { return false }
        defer { try? FileManager.default.removeItem(at: url) }

        let inner = "/bin/sh \(LoginLabel.shellQuoted(url.path))"
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", "do shell script \"\(inner)\" with administrator privileges"]
        let stderr = Pipe()
        process.standardError = stderr
        do { try process.run() } catch { return false }
        process.waitUntilExit()
        if process.terminationStatus == 0 { return true }
        // -128 is the user cancelling the password prompt: stay silent.
        let output = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if !output.contains("-128") {
            let alert = NSAlert()
            alert.messageText = "Could not change login & lock screen label"
            alert.informativeText = output.isEmpty ? "The administrator command failed." : output
            alert.runModal()
        }
        return false
    }

    @objc private func editName() {
        let alert = NSAlert()
        alert.messageText = "Name for this Mac"
        alert.informativeText = "Shown in the menu bar and the on-screen label. Leave empty to use the computer name."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = settings.displayName
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        settings.setDisplayName(field.stringValue)
        refresh()
    }

    @objc private func resetName() {
        settings.setDisplayName("")
        refresh()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Could not change launch at login"
            alert.runModal()
        }
        refresh()
    }

    @objc private func screensChanged() {
        refresh()
    }
}

/// Runs instead of the menu-bar app at the pre-login login window, where
/// launchd loads this binary via the LoginWindow LaunchAgent. No status
/// item exists in that session — just the label, kept current by polling
/// the shared label file the user app writes.
final class LoginWindowDelegate: NSObject, NSApplicationDelegate {
    private let overlay = Overlay()
    private var lastShown: LoginLabel.Shared?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        showCurrent()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.showCurrent() }
    }

    private func showCurrent() {
        let shared = LoginLabel.readShared() ?? LoginLabel.Shared(
            name: Settings().displayName, colorHex: Settings.defaultColorHex,
            fontSize: Settings.defaultFontSize, backgroundOpacity: Settings.defaultOpacity)
        guard shared != lastShown else { return }
        lastShown = shared
        let rgb = Settings.rgb(fromHex: shared.colorHex)
        overlay.show(text: shared.name, style: LabelStyle(
            color: NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1),
            fontSize: shared.fontSize, backgroundOpacity: shared.backgroundOpacity))
    }

    @objc private func screensChanged() {
        lastShown = nil
        showCurrent()
    }
}

let app = NSApplication.shared
let delegate: NSApplicationDelegate = CommandLine.arguments.contains(LoginLabel.loginWindowArgument)
    ? LoginWindowDelegate() : AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
