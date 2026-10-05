// Renders Resources/AppIcon.icns: run `swift tools/make_icon.swift`.
import AppKit

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024
    let body = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(colors: [NSColor(srgbRed: 0.16, green: 0.20, blue: 0.33, alpha: 1),
                        NSColor(srgbRed: 0.07, green: 0.09, blue: 0.16, alpha: 1)])!.draw(in: shape, angle: -90)

    // Viewfinder corners
    let f = body.insetBy(dx: 170 * s, dy: 170 * s)
    let corner = 120 * s
    let vf = NSBezierPath()
    for (p, dx, dy) in [(CGPoint(x: f.minX, y: f.maxY), 1.0, -1.0), (CGPoint(x: f.maxX, y: f.maxY), -1.0, -1.0),
                        (CGPoint(x: f.minX, y: f.minY), 1.0, 1.0), (CGPoint(x: f.maxX, y: f.minY), -1.0, 1.0)] {
        vf.move(to: CGPoint(x: p.x, y: p.y + dy * corner))
        vf.line(to: p)
        vf.line(to: CGPoint(x: p.x + dx * corner, y: p.y))
    }
    vf.lineWidth = 40 * s
    vf.lineCapStyle = .round
    vf.lineJoinStyle = .round
    NSColor.white.setStroke()
    vf.stroke()

    // Red arrow pointing into the frame
    let a = CGPoint(x: f.minX + 70 * s, y: f.minY + 70 * s), b = CGPoint(x: f.maxX - 60 * s, y: f.maxY - 60 * s)
    let dx = b.x - a.x, dy = b.y - a.y, len = hypot(dx, dy)
    let u = CGPoint(x: dx / len, y: dy / len), n = CGPoint(x: -u.y, y: u.x)
    func pt(_ o: CGPoint, _ al: CGFloat, _ ac: CGFloat) -> CGPoint { CGPoint(x: o.x + u.x * al + n.x * ac, y: o.y + u.y * al + n.y * ac) }
    let head = 190 * s
    let arrow = NSBezierPath()
    arrow.move(to: pt(a, 0, 14 * s))
    arrow.line(to: pt(b, -head * 0.72, 30 * s))
    arrow.line(to: pt(b, -head, head * 0.55))
    arrow.line(to: b)
    arrow.line(to: pt(b, -head, -head * 0.55))
    arrow.line(to: pt(b, -head * 0.72, -30 * s))
    arrow.line(to: pt(a, 0, -14 * s))
    arrow.close()
    arrow.lineJoinStyle = .round
    NSColor(srgbRed: 1, green: 0.27, blue: 0.23, alpha: 1).setFill()
    arrow.fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try! render(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try! render(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
