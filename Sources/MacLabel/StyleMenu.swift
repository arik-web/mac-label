import AppKit

/// The Text Color / Text Size / Background submenus. Writes straight to
/// Settings and calls `onChange` so the app can redraw the overlay.
final class StyleMenu: NSObject {
    private static let colors: [(String, String)] = [
        ("White", "FFFFFF"), ("Yellow", "FFD60A"), ("Orange", "FF9F0A"), ("Red", "FF453A"),
        ("Pink", "FF375F"), ("Purple", "BF5AF2"), ("Blue", "0A84FF"), ("Cyan", "64D2FF"),
        ("Green", "30D158"), ("Black", "000000"),
    ]
    private static let sizes: [(String, Double)] = [
        ("Small", 16), ("Medium", 22), ("Large", 32), ("Extra large", 48), ("Huge", 72),
    ]
    private static let opacities: [Double] = [0, 0.2, 0.4, 0.6, 0.8, 1]

    private let settings: Settings
    private let onChange: () -> Void
    private let colorMenu = NSMenu()
    private let sizeMenu = NSMenu()
    private let opacityMenu = NSMenu()
    private let lockSizeMenu = NSMenu()

    init(settings: Settings, onChange: @escaping () -> Void) {
        self.settings = settings
        self.onChange = onChange
        super.init()
        build()
    }

    /// Top-level items to add to the status menu.
    var items: [NSMenuItem] {
        [("Text color", colorMenu), ("Text size", sizeMenu), ("Background", opacityMenu),
         ("Lock screen size", lockSizeMenu)].map {
            let item = NSMenuItem(title: $0.0, action: nil, keyEquivalent: "")
            item.submenu = $0.1
            return item
        }
    }

    var style: LabelStyle {
        let rgb = Settings.rgb(fromHex: settings.textColorHex)
        return LabelStyle(color: NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1),
                          fontSize: settings.fontSize,
                          backgroundOpacity: settings.backgroundOpacity)
    }

    /// Lock-screen style: same color and background as on screen,
    /// size from the Lock screen size choice (default: the on-screen size).
    var lockStyle: LabelStyle {
        var style = style
        style.fontSize = settings.effectiveLockFontSize
        return style
    }

    /// Ticks the current choice in each submenu.
    func refreshChecks() {
        colorMenu.items.forEach { $0.state = ($0.representedObject as? String) == settings.textColorHex ? .on : .off }
        sizeMenu.items.forEach { $0.state = ($0.representedObject as? Double) == settings.fontSize ? .on : .off }
        opacityMenu.items.forEach {
            guard let value = $0.representedObject as? Double else { return }
            $0.state = abs(value - settings.backgroundOpacity) < 0.01 ? .on : .off
        }
        lockSizeMenu.items.forEach { $0.state = ($0.representedObject as? Double) == settings.lockFontSize ? .on : .off }
    }

    private func build() {
        for (name, hex) in StyleMenu.colors {
            // Styled title text instead of an item image: image swatches drew blank rows.
            let item = makeItem(name, #selector(pickColor(_:)), hex, in: colorMenu)
            item.attributedTitle = StyleMenu.swatchTitle(name, hex)
        }
        colorMenu.addItem(.separator())
        makeItem("Custom…", #selector(openColorPanel), nil, in: colorMenu)

        for (name, size) in StyleMenu.sizes {
            makeItem("\(name) (\(Int(size)) pt)", #selector(pickSize(_:)), size, in: sizeMenu)
        }

        for opacity in StyleMenu.opacities {
            let title = opacity == 0 ? "None (text only)" : "\(Int(opacity * 100))% dark"
            makeItem(title, #selector(pickOpacity(_:)), opacity, in: opacityMenu)
        }

        makeItem("Same as on-screen", #selector(pickLockSize(_:)), 0.0, in: lockSizeMenu)
        for (name, size) in StyleMenu.sizes {
            makeItem("\(name) (\(Int(size)) pt)", #selector(pickLockSize(_:)), size, in: lockSizeMenu)
        }
    }

    @discardableResult
    private func makeItem(_ title: String, _ action: Selector, _ value: Any?, in menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = value
        menu.addItem(item)
        return item
    }

    /// "■■■  Yellow", blocks in the color itself, name in the normal menu text color.
    private static func swatchTitle(_ name: String, _ hex: String) -> NSAttributedString {
        let rgb = Settings.rgb(fromHex: hex)
        let color = NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        let font = NSFont.menuFont(ofSize: 0)
        let title = NSMutableAttributedString(string: "■■■", attributes: [
            .foregroundColor: color, .font: font,
            // Outline keeps white and black blocks visible on either menu theme.
            .strokeColor: NSColor.gray, .strokeWidth: -2,
        ])
        title.append(NSAttributedString(string: "  \(name)", attributes: [
            .foregroundColor: NSColor.labelColor, .font: font,
        ]))
        return title
    }

    @objc private func pickColor(_ sender: NSMenuItem) {
        guard let hex = sender.representedObject as? String else { return }
        settings.textColorHex = hex
        onChange()
    }

    @objc private func pickSize(_ sender: NSMenuItem) {
        guard let size = sender.representedObject as? Double else { return }
        settings.fontSize = size
        onChange()
    }

    @objc private func pickLockSize(_ sender: NSMenuItem) {
        guard let size = sender.representedObject as? Double else { return }
        settings.lockFontSize = size
        onChange()
    }

    @objc private func pickOpacity(_ sender: NSMenuItem) {
        guard let opacity = sender.representedObject as? Double else { return }
        settings.backgroundOpacity = opacity
        onChange()
    }

    @objc private func openColorPanel() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = style.color
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged(_:)))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorPanelChanged(_ panel: NSColorPanel) {
        guard let rgb = panel.color.usingColorSpace(.sRGB) else { return }
        let hex = String(format: "%02X%02X%02X",
                         Int((rgb.redComponent * 255).rounded()),
                         Int((rgb.greenComponent * 255).rounded()),
                         Int((rgb.blueComponent * 255).rounded()))
        settings.textColorHex = hex
        onChange()
    }
}
