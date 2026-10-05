import AppKit

enum Tool: CaseIterable {
    case pen, line, arrow, rectangle, ellipse, marker, text

    var symbol: String {
        switch self {
        case .pen: return "pencil"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .marker: return "highlighter"
        case .text: return "textformat"
        }
    }

    var title: String {
        switch self {
        case .pen: return "Карандаш (P)"
        case .line: return "Линия (L)"
        case .arrow: return "Стрелка (A)"
        case .rectangle: return "Прямоугольник (R)"
        case .ellipse: return "Круг / овал (E)"
        case .marker: return "Маркер (M)"
        case .text: return "Текст (T)"
        }
    }

    /// Physical key codes, so shortcuts work on the Russian layout too.
    static func forKeyCode(_ code: UInt16) -> Tool? {
        switch code {
        case 35: return .pen        // P
        case 37: return .line       // L
        case 0: return .arrow       // A
        case 15: return .rectangle  // R
        case 14, 31: return .ellipse // E, O
        case 46: return .marker     // M
        case 17: return .text       // T
        default: return nil
        }
    }
}

enum Palette {
    static let colors: [NSColor] = [
        NSColor(srgbRed: 1.00, green: 0.23, blue: 0.19, alpha: 1), // red
        NSColor(srgbRed: 1.00, green: 0.58, blue: 0.00, alpha: 1), // orange
        NSColor(srgbRed: 1.00, green: 0.84, blue: 0.00, alpha: 1), // yellow
        NSColor(srgbRed: 0.20, green: 0.78, blue: 0.35, alpha: 1), // green
        NSColor(srgbRed: 0.00, green: 0.48, blue: 1.00, alpha: 1), // blue
        NSColor(srgbRed: 0.69, green: 0.32, blue: 0.87, alpha: 1), // purple
        NSColor(srgbRed: 0.00, green: 0.00, blue: 0.00, alpha: 1), // black
        NSColor(srgbRed: 1.00, green: 1.00, blue: 1.00, alpha: 1), // white
    ]
    static let widths: [CGFloat] = [2, 4, 8]
}

/// Last used color and thickness survive between screenshots.
enum Settings {
    private static let defaults = UserDefaults.standard

    static var color: NSColor {
        get {
            guard let c = defaults.array(forKey: "color") as? [Double], c.count == 4 else { return Palette.colors[0] }
            return NSColor(srgbRed: c[0], green: c[1], blue: c[2], alpha: c[3])
        }
        set {
            guard let c = newValue.usingColorSpace(.sRGB) else { return }
            defaults.set([c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent].map(Double.init), forKey: "color")
        }
    }

    static var lineWidth: CGFloat {
        get {
            let w = defaults.double(forKey: "lineWidth")
            return w > 0 ? CGFloat(w) : 4
        }
        set { defaults.set(Double(newValue), forKey: "lineWidth") }
    }
}

struct Annotation {
    enum Kind {
        case pen([CGPoint])
        case marker([CGPoint])
        case line(CGPoint, CGPoint)
        case arrow(CGPoint, CGPoint)
        case rectangle(CGRect)
        case ellipse(CGRect)
        case text(String, CGRect, CGFloat) // text, frame (top-left anchored), font size
    }

    var kind: Kind
    var color: NSColor
    var width: CGFloat

    /// Whether the shape is big enough to keep (a stray click shouldn't leave an invisible object).
    var isMeaningful: Bool {
        switch kind {
        case .pen(let pts), .marker(let pts): return !pts.isEmpty
        case .line(let a, let b), .arrow(let a, let b): return hypot(b.x - a.x, b.y - a.y) >= 3
        case .rectangle(let r), .ellipse(let r): return r.width >= 3 || r.height >= 3
        case .text(let s, _, _): return !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    static func markerWidth(_ w: CGFloat) -> CGFloat { w * 3 + 8 }
    static func fontSize(_ w: CGFloat) -> CGFloat { 14 + w * 2 }

    static func textAttributes(size: CGFloat, color: NSColor) -> [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: size, weight: .semibold), .foregroundColor: color]
    }

    /// Draws into the current NSGraphicsContext (screen view and export share this code).
    func draw() {
        switch kind {
        case .pen(let pts):
            color.set()
            if pts.count == 1 {
                NSBezierPath(ovalIn: CGRect(x: pts[0].x - width / 2, y: pts[0].y - width / 2, width: width, height: width)).fill()
            } else {
                let path = Annotation.smoothPath(pts)
                path.lineWidth = width
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }

        case .marker(let pts):
            guard let ctx = NSGraphicsContext.current?.cgContext else { return }
            let mw = Annotation.markerWidth(width)
            ctx.saveGState()
            ctx.setBlendMode(.multiply)
            color.withAlphaComponent(0.5).set()
            if pts.count == 1 {
                NSBezierPath(ovalIn: CGRect(x: pts[0].x - mw / 2, y: pts[0].y - mw / 2, width: mw, height: mw)).fill()
            } else {
                let path = Annotation.smoothPath(pts)
                path.lineWidth = mw
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                path.stroke()
            }
            ctx.restoreGState()

        case .line(let a, let b):
            color.setStroke()
            let path = NSBezierPath()
            path.move(to: a)
            path.line(to: b)
            path.lineWidth = width
            path.lineCapStyle = .round
            path.stroke()

        case .arrow(let a, let b):
            color.setFill()
            Annotation.arrowPath(from: a, to: b, width: width).fill()

        case .rectangle(let r):
            color.setStroke()
            let path = NSBezierPath(rect: r)
            path.lineWidth = width
            path.lineJoinStyle = .miter
            path.stroke()

        case .ellipse(let r):
            color.setStroke()
            let path = NSBezierPath(ovalIn: r)
            path.lineWidth = width
            path.stroke()

        case .text(let s, let frame, let size):
            let str = NSAttributedString(string: s, attributes: Annotation.textAttributes(size: size, color: color))
            // Extra width so layout never wraps differently from the editor.
            str.draw(in: CGRect(x: frame.minX, y: frame.minY, width: frame.width + 1000, height: frame.height))
        }
    }

    /// Filled tapered arrow: thin tail, swept head.
    static func arrowPath(from a: CGPoint, to b: CGPoint, width w: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let dx = b.x - a.x, dy = b.y - a.y
        let len = hypot(dx, dy)
        guard len >= 1 else { return path }
        let u = CGPoint(x: dx / len, y: dy / len)
        let n = CGPoint(x: -u.y, y: u.x)
        let headLen = min(len, max(14, w * 3 + 10))
        let headHalf = headLen * 0.55
        let neck = headLen * 0.72
        let shaftHalf = max(w / 2, 1)
        let tailHalf = max(w * 0.3, 0.75)

        func pt(_ base: CGPoint, _ along: CGFloat, _ across: CGFloat) -> CGPoint {
            CGPoint(x: base.x + u.x * along + n.x * across, y: base.y + u.y * along + n.y * across)
        }

        path.move(to: pt(a, 0, tailHalf))
        path.line(to: pt(b, -neck, shaftHalf))
        path.line(to: pt(b, -headLen, headHalf))
        path.line(to: b)
        path.line(to: pt(b, -headLen, -headHalf))
        path.line(to: pt(b, -neck, -shaftHalf))
        path.line(to: pt(a, 0, -tailHalf))
        path.close()
        path.lineJoinStyle = .round
        return path
    }

    /// Freehand stroke smoothed with quadratic curves through midpoints.
    static func smoothPath(_ pts: [CGPoint]) -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = pts.first else { return path }
        path.move(to: first)
        guard pts.count > 2 else {
            pts.dropFirst().forEach { path.line(to: $0) }
            return path
        }
        for i in 1..<(pts.count - 1) {
            let mid = CGPoint(x: (pts[i].x + pts[i + 1].x) / 2, y: (pts[i].y + pts[i + 1].y) / 2)
            path.curve(to: mid, controlPoint: pts[i])
        }
        path.line(to: pts[pts.count - 1])
        return path
    }
}
