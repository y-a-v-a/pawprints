// Turns a square illustration into a macOS app icon: a rounded square on the
// standard 1024 grid (824 points of art, soft shadow), saved as PNG.
//   swift scripts/make-icon.swift input.jpg Resources/AppIcon.png
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let art = NSImage(contentsOfFile: args[1]) else {
    print("usage: make-icon.swift input output.png"); exit(1)
}
let canvas = 1024.0, inset = 100.0, side = canvas - inset * 2, radius = 185.0
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let rect = NSRect(x: inset, y: inset + 10, width: side, height: side)
let shape = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor(srgbRed: 0.96, green: 0.92, blue: 0.84, alpha: 1).setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState()
shape.addClip()
// Crop a touch so the painting's own edges don't show.
art.draw(in: rect.insetBy(dx: -side * 0.04, dy: -side * 0.04))
NSGraphicsContext.restoreGraphicsState()
NSColor.black.withAlphaComponent(0.12).setStroke()
shape.lineWidth = 2
shape.stroke()
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("wrote \(args[2])")
