import AppKit
import Foundation

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = directory.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let p = CGFloat(pixels)
        let background = NSBezierPath(roundedRect: NSRect(x: p * 0.06, y: p * 0.06, width: p * 0.88, height: p * 0.88), xRadius: p * 0.2, yRadius: p * 0.2)
        NSGradient(starting: NSColor(red: 0.10, green: 0.20, blue: 0.46, alpha: 1), ending: NSColor(red: 0.03, green: 0.40, blue: 0.44, alpha: 1))!.draw(in: background, angle: -45)
        // Original workflow-node mark; no Apple logo or Shortcuts icon artwork.
        let route = NSBezierPath()
        route.move(to: NSPoint(x: p * 0.30, y: p * 0.28))
        route.curve(to: NSPoint(x: p * 0.70, y: p * 0.50), controlPoint1: NSPoint(x: p * 0.30, y: p * 0.50), controlPoint2: NSPoint(x: p * 0.70, y: p * 0.28))
        route.curve(to: NSPoint(x: p * 0.30, y: p * 0.72), controlPoint1: NSPoint(x: p * 0.70, y: p * 0.72), controlPoint2: NSPoint(x: p * 0.30, y: p * 0.50))
        route.lineWidth = p * 0.065; route.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.9).setStroke(); route.stroke()
        for (x, y) in [(0.30, 0.28), (0.70, 0.50), (0.30, 0.72)] {
            let radius = p * 0.085
            NSColor.white.setFill(); NSBezierPath(ovalIn: NSRect(x: p * x - radius, y: p * y - radius, width: radius * 2, height: radius * 2)).fill()
            NSColor(red: 0.04, green: 0.38, blue: 0.45, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: p * x - radius * 0.42, y: p * y - radius * 0.42, width: radius * 0.84, height: radius * 0.84)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(filename))
    }
}
let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil"); process.arguments = ["-c", "icns", iconset.path, "-o", directory.appendingPathComponent("AppIcon.icns").path]
try process.run(); process.waitUntilExit(); guard process.terminationStatus == 0 else { exit(1) }
try FileManager.default.removeItem(at: iconset)
