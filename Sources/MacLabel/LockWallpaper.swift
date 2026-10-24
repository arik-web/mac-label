import AppKit

/// The lock screen cannot show any app window — loginwindow hides the
/// whole session. What it does show is the desktop wallpaper. So the lock
/// label is baked, centered, into a copy of the current wallpaper at the
/// chosen lock size and the on-screen color; the copy is swapped in on
/// lock and the original restored on unlock.
enum LockWallpaper {
    private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacLabel", isDirectory: true)
    }

    /// Bakes the lock wallpaper files only when an input changed.
    /// Does not switch the desktop wallpaper — see activate/deactivate.
    static func applyIfNeeded(settings: Settings, name: String) {
        let screens = NSScreen.screens
        let sources = screens.map { sourcePath(for: $0, settings: settings) }
        let key = "center1|" + Settings.lockWallpaperKey(name: name, colorHex: settings.textColorHex,
                                            backgroundOpacity: settings.backgroundOpacity,
                                            effectiveLockFontSize: settings.effectiveLockFontSize,
                                            sourcePaths: sources)
        guard key != settings.lockWallpaperHash else { return }
        guard bake(settings: settings, name: name, screens: screens, sources: sources) else { return }
        settings.lockWallpaperHash = key
    }

    /// While locked: swap each screen to its baked wallpaper.
    static func activate(settings: Settings) {
        for (index, screen) in NSScreen.screens.enumerated() {
            let baked = directory.appendingPathComponent("lock-wallpaper-\(index).jpg")
            guard FileManager.default.fileExists(atPath: baked.path),
                  NSWorkspace.shared.desktopImageURL(for: screen)?.path != baked.path else { continue }
            try? NSWorkspace.shared.setDesktopImageURL(baked, for: screen, options: [:])
        }
    }

    /// While unlocked: back to the original wallpaper, if a baked one
    /// is currently showing. Keeps the bake fingerprint for next lock.
    static func deactivate(settings: Settings) {
        for (index, screen) in NSScreen.screens.enumerated() {
            guard NSWorkspace.shared.desktopImageURL(for: screen)?.path.hasPrefix(directory.path) == true,
                  settings.wallpaperOriginals.indices.contains(index) else { continue }
            let original = settings.wallpaperOriginals[index]
            if !original.isEmpty {
                try? NSWorkspace.shared.setDesktopImageURL(URL(fileURLWithPath: original), for: screen, options: [:])
            }
        }
    }

    /// Puts back the original wallpapers and forgets the bake.
    static func restore(settings: Settings) {
        deactivate(settings: settings)
        settings.lockWallpaperHash = ""
    }

    /// The wallpaper to draw on: the stored original when the current one
    /// is already our baked copy.
    private static func sourcePath(for screen: NSScreen, settings: Settings) -> String {
        guard let current = NSWorkspace.shared.desktopImageURL(for: screen)?.path else { return "" }
        if current.hasPrefix(directory.path),
           let index = NSScreen.screens.firstIndex(of: screen),
           settings.wallpaperOriginals.indices.contains(index) {
            return settings.wallpaperOriginals[index]
        }
        return current
    }

    private static func bake(settings: Settings, name: String, screens: [NSScreen], sources: [String]) -> Bool {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Remember the pre-bake wallpaper once, for restore on disable.
        if settings.wallpaperOriginals.count != screens.count {
            settings.wallpaperOriginals = sources
        }
        var allOK = true
        for (index, screen) in screens.enumerated() {
            let source = sources[index]
            guard !source.isEmpty, let image = NSImage(contentsOfFile: source),
                  let png = rendered(image: image, screen: screen, settings: settings, name: name) else {
                allOK = false
                continue
            }
            let out = directory.appendingPathComponent("lock-wallpaper-\(index).jpg")
            do {
                try png.write(to: out)
            } catch { allOK = false }
        }
        return allOK
    }

    /// Draws the label box centered on the wallpaper, scaled from points
    /// to wallpaper pixels. Centered, so the fill-crop the lock screen
    /// applies at the edges can never cut it off. Returns JPEG data.
    private static func rendered(image: NSImage, screen: NSScreen, settings: Settings, name: String) -> Data? {
        guard let bitmap = NSBitmapImageRep(data: image.tiffRepresentation ?? Data()) else { return nil }
        let pixelSize = NSSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        guard pixelSize.width > 0, screen.frame.height > 0 else { return nil }
        let scale = pixelSize.height / screen.frame.height

        let rgb = Settings.rgb(fromHex: settings.textColorHex)
        let fontSize = settings.effectiveLockFontSize * scale
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let color = NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        let textSize = (name as NSString).size(withAttributes: [.font: font])
        let padding = NSSize(width: fontSize * 0.6, height: fontSize * 0.35)
        let boxSize = NSSize(width: textSize.width + padding.width * 2,
                             height: textSize.height + padding.height * 2)

        let origin = Settings.centeredOrigin(container: pixelSize, box: boxSize)
        let boxRect = NSRect(origin: origin, size: boxSize)

        let canvas = NSImage(size: pixelSize)
        canvas.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: pixelSize))
        NSColor.black.withAlphaComponent(settings.backgroundOpacity).setFill()
        NSBezierPath(roundedRect: boxRect, xRadius: fontSize * 0.45, yRadius: fontSize * 0.45).fill()
        (name as NSString).draw(at: NSPoint(x: boxRect.minX + padding.width,
                                            y: boxRect.minY + padding.height),
                                withAttributes: [.font: font, .foregroundColor: color])
        canvas.unlockFocus()
        guard let tiff = canvas.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
    }
}
