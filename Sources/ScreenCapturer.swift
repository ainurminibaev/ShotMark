import AppKit
import ScreenCaptureKit

struct Shot {
    let screen: NSScreen
    let image: CGImage
}

enum CaptureError: LocalizedError {
    case noDisplays

    var errorDescription: String? {
        switch self {
        case .noDisplays: return "Не удалось найти ни одного экрана для снимка."
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

/// Grabs a frozen image of every screen via ScreenCaptureKit.
@MainActor
enum ScreenCapturer {
    private static var cachedContent: SCShareableContent?

    static func invalidate() {
        cachedContent = nil
    }

    /// Fetching the display list is the slowest part; do it ahead of the first hotkey press.
    static func warmUp() {
        Task { _ = try? await content(refresh: true) }
    }

    static func captureAll() async throws -> [Shot] {
        do {
            return try await capture(using: try await content(refresh: false))
        } catch {
            // Display list may be stale (monitor plugged in, resolution changed) — retry once with a fresh one.
            return try await capture(using: try await content(refresh: true))
        }
    }

    private static func content(refresh: Bool) async throws -> SCShareableContent {
        if !refresh, let cachedContent {
            return cachedContent
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        cachedContent = content
        return content
    }

    private static func capture(using content: SCShareableContent) async throws -> [Shot] {
        var shots: [Shot] = []
        for screen in NSScreen.screens {
            guard let id = screen.displayID,
                  let display = content.displays.first(where: { $0.displayID == id }) else {
                throw CaptureError.noDisplays
            }
            let scale = screen.backingScaleFactor
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = Int((screen.frame.width * scale).rounded())
            config.height = Int((screen.frame.height * scale).rounded())
            config.showsCursor = false
            config.captureResolution = .best
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            shots.append(Shot(screen: screen, image: image))
        }
        if shots.isEmpty {
            throw CaptureError.noDisplays
        }
        return shots
    }

    /// Synthetic screenshot for `--demo`, so the editor can be tried without Screen Recording permission.
    static func demoShots() -> [Shot] {
        NSScreen.screens.compactMap { screen in
            let scale = screen.backingScaleFactor
            let w = Int(screen.frame.width * scale), h = Int(screen.frame.height * scale)
            guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
            let colors = [CGColor(red: 0.93, green: 0.95, blue: 0.98, alpha: 1),
                          CGColor(red: 0.80, green: 0.86, blue: 0.95, alpha: 1)] as CFArray
            let gradient = CGGradient(colorsSpace: nil, colors: colors, locations: [0, 1])!
            ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: w, y: h), options: [])
            ctx.scaleBy(x: scale, y: scale)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            let size = screen.frame.size
            for i in 0..<6 {
                let r = CGRect(x: 80 + CGFloat(i) * (size.width - 160) / 6, y: size.height * 0.35,
                               width: (size.width - 160) / 6 - 24, height: size.height * 0.3)
                NSColor.white.setFill()
                NSBezierPath(roundedRect: r, xRadius: 12, yRadius: 12).fill()
                ("Карточка \(i + 1)" as NSString).draw(at: CGPoint(x: r.minX + 16, y: r.maxY - 36),
                                                     withAttributes: [.font: NSFont.systemFont(ofSize: 18, weight: .semibold),
                                                                      .foregroundColor: NSColor.darkGray])
            }
            ("ShotMark — демо-режим" as NSString).draw(at: CGPoint(x: 80, y: size.height * 0.75),
                                                       withAttributes: [.font: NSFont.systemFont(ofSize: 40, weight: .bold),
                                                                        .foregroundColor: NSColor.black])
            NSGraphicsContext.restoreGraphicsState()
            guard let image = ctx.makeImage() else { return nil }
            return Shot(screen: screen, image: image)
        }
    }
}
