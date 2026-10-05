import AppKit

/// Square icon button with hover / selected states. Draws a color swatch instead of an icon when `swatch` is set.
final class ToolbarButton: NSView {
    static let size: CGFloat = 30

    var action: () -> Void
    var isSelected = false { didSet { updateLook() } }
    var swatch: NSColor? { didSet { needsDisplay = true } }
    /// Ring drawn around the swatch (palette uses it to mark the current color).
    var showsRing = false { didSet { needsDisplay = true } }
    var dotDiameter: CGFloat? { didSet { needsDisplay = true } }

    private let imageView = NSImageView()
    private var hovering = false
    private var pressed = false

    init(symbol: String?, tooltip: String, action: @escaping () -> Void) {
        self.action = action
        super.init(frame: NSRect(x: 0, y: 0, width: ToolbarButton.size, height: ToolbarButton.size))
        toolTip = tooltip
        if let symbol {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            imageView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)?
                .withSymbolConfiguration(config)
            imageView.contentTintColor = .white
            imageView.frame = bounds
            imageView.imageScaling = .scaleNone
            addSubview(imageView)
        }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate],
                                       owner: self, userInfo: nil))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func cursorUpdate(with event: NSEvent) { NSCursor.arrow.set() }
    override func mouseEntered(with event: NSEvent) { hovering = true; updateLook() }
    override func mouseExited(with event: NSEvent) { hovering = false; updateLook() }

    override func mouseDown(with event: NSEvent) {
        pressed = true
        updateLook()
    }

    override func mouseDragged(with event: NSEvent) {
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        if inside != pressed {
            pressed = inside
            updateLook()
        }
    }

    override func mouseUp(with event: NSEvent) {
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        pressed = false
        updateLook()
        if inside { action() }
    }

    private func updateLook() {
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let bg: NSColor?
        if isSelected {
            bg = .controlAccentColor
        } else if pressed {
            bg = NSColor.white.withAlphaComponent(0.28)
        } else if hovering {
            bg = NSColor.white.withAlphaComponent(0.16)
        } else {
            bg = nil
        }
        if let bg {
            bg.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
        }

        if let swatch {
            let r = bounds.insetBy(dx: 7, dy: 7)
            swatch.setFill()
            NSBezierPath(ovalIn: r).fill()
            NSColor.white.withAlphaComponent(0.9).setStroke()
            let ring = NSBezierPath(ovalIn: r.insetBy(dx: 0.75, dy: 0.75))
            ring.lineWidth = 1.5
            ring.stroke()
            if showsRing {
                let outer = NSBezierPath(ovalIn: bounds.insetBy(dx: 3, dy: 3))
                outer.lineWidth = 2
                NSColor.controlAccentColor.setStroke()
                outer.stroke()
            }
        } else if let d = dotDiameter {
            NSColor.white.setFill()
            NSBezierPath(ovalIn: CGRect(x: bounds.midX - d / 2, y: bounds.midY - d / 2, width: d, height: d)).fill()
        }
    }
}

/// Dark translucent rounded strip holding buttons.
final class ToolbarView: NSVisualEffectView {
    static let padding: CGFloat = 4
    static let spacing: CGFloat = 2

    init(items: [NSView], vertical: Bool) {
        super.init(frame: .zero)
        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        appearance = NSAppearance(named: .darkAqua)
        maskImage = ToolbarView.roundedMask(radius: 9)

        var offset = ToolbarView.padding
        let cross = ToolbarButton.size + ToolbarView.padding * 2
        // Vertical bars are laid out top-down (AppKit's y axis points up).
        let ordered = vertical ? items.reversed() : items
        for item in ordered {
            let length = item is ToolbarButton ? ToolbarButton.size : 9
            if vertical {
                item.frame = NSRect(x: ToolbarView.padding, y: offset, width: ToolbarButton.size, height: length)
            } else {
                item.frame = NSRect(x: offset, y: ToolbarView.padding, width: length, height: ToolbarButton.size)
            }
            addSubview(item)
            offset += length + ToolbarView.spacing
        }
        offset += ToolbarView.padding - ToolbarView.spacing
        setFrameSize(vertical ? NSSize(width: cross, height: offset) : NSSize(width: offset, height: cross))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {}   // swallow clicks between buttons
    override func mouseUp(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}

    static func separator() -> NSView {
        let v = SeparatorView()
        return v
    }

    static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

private final class SeparatorView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.25).setFill()
        if bounds.width > bounds.height {
            NSRect(x: bounds.minX + 4, y: bounds.midY - 0.5, width: bounds.width - 8, height: 1).fill(using: .sourceOver)
        } else {
            NSRect(x: bounds.midX - 0.5, y: bounds.minY + 4, width: 1, height: bounds.height - 8).fill(using: .sourceOver)
        }
    }
}
