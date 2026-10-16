import AppKit

/// One click-through label window per display, pinned to the top-left corner
/// just under the menu bar, visible on every Space and over full-screen apps.
final class Overlay {
    private static let margin: CGFloat = 12
    private static let fontSize: CGFloat = 22

    private var windows: [NSWindow] = []

    func show(text: String) {
        hide()
        windows = NSScreen.screens.map { Overlay.makeWindow(text: text, screen: $0) }
        windows.forEach { $0.orderFrontRegardless() }
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
        windows = []
    }

    private static func makeWindow(text: String, screen: NSScreen) -> NSWindow {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: fontSize, weight: .bold)
        label.textColor = .white
        label.sizeToFit()

        let padding = NSSize(width: 14, height: 8)
        let size = NSSize(width: label.frame.width + padding.width * 2,
                          height: label.frame.height + padding.height * 2)
        label.frame.origin = NSPoint(x: padding.width, y: padding.height)

        let background = NSView(frame: NSRect(origin: .zero, size: size))
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        background.layer?.cornerRadius = 10
        background.addSubview(label)

        // visibleFrame excludes the menu bar, so the label sits right under it.
        let visible = screen.visibleFrame
        let origin = NSPoint(x: visible.minX + margin,
                             y: visible.maxY - size.height - margin)

        let window = NSWindow(contentRect: NSRect(origin: origin, size: size),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = background
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary,
                                     .fullScreenAuxiliary, .ignoresCycle]
        return window
    }
}
