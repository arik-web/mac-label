import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private let overlay = Overlay()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    private let overlayItem = NSMenuItem(title: "Show name on screen",
                                         action: #selector(toggleOverlay), keyEquivalent: "o")
    private let resetItem = NSMenuItem(title: "Reset to computer name",
                                       action: #selector(resetName), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at login",
                                       action: #selector(toggleLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.addItem(overlayItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Edit name…", action: #selector(editName), keyEquivalent: "e"))
        menu.addItem(resetItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: "Quit Mac Label", action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        menu.items.filter { $0.action != #selector(NSApplication.terminate(_:)) }
            .forEach { $0.target = self }
        statusItem.menu = menu

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        refresh()
    }

    private func refresh() {
        let name = settings.displayName
        statusItem.button?.title = name
        overlayItem.state = settings.overlayVisible ? .on : .off
        resetItem.isEnabled = settings.hasCustomName
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        if settings.overlayVisible {
            overlay.show(text: name)
        } else {
            overlay.hide()
        }
    }

    @objc private func toggleOverlay() {
        settings.overlayVisible.toggle()
        refresh()
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

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
