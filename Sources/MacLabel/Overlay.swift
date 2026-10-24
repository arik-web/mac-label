import AppKit

struct LabelStyle {
    var color: NSColor
    var fontSize: CGFloat
    var backgroundOpacity: CGFloat
}

/// One click-through label window per display, pinned to the top-left corner
/// just under the menu bar, visible on every Space and over full-screen apps.
final class Overlay {
    private static let margin: CGFloat = 12

    private var windows: [NSWindow] = []

    func show(text: String, style: LabelStyle) {
        hide()
        windows = NSScreen.screens.map { Overlay.makeWindow(text: text, style: style, screen: $0) }
        windows.forEach { $0.orderFrontRegardless() }
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
        windows = []
    }

    private static func makeWindow(text: String, style: LabelStyle, screen: NSScreen) -> NSWindow {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: style.fontSize, weight: .bold)
        label.textColor = style.color
        label.sizeToFit()
        // Keeps light text readable when the box behind it is fully transparent.
        let shadow = NSShadow()
        shadow.shadowColor = .black.withAlphaComponent(0.8)
        shadow.shadowBlurRadius = 3
        label.shadow = shadow

        let padding = NSSize(width: style.fontSize * 0.6, height: style.fontSize * 0.35)
        let size = NSSize(width: label.frame.width + padding.width * 2,
                          height: label.frame.height + padding.height * 2)
        label.frame.origin = NSPoint(x: padding.width, y: padding.height)

        let background = NSView(frame: NSRect(origin: .zero, size: size))
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.black.withAlphaComponent(style.backgroundOpacity).cgColor
        background.layer?.cornerRadius = style.fontSize * 0.45
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
        // Screen-saver level: over the screen saver. The secure lock
        // screen hides every app window at any level — there the label
        // is baked into the wallpaper instead (see LockWallpaper).
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary,
                                     .fullScreenAuxiliary, .ignoresCycle]
        return window
    }
}
