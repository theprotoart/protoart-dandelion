// Draws the ProtoArt Dandelion icon (1024×1024 PNG): a dandelion seed head on a black anodized plate.
// Usage: swift tools/make-icon.swift out.png
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Plate (macOS icon grid: ~824pt body with rounded corners)
let inset: CGFloat = 100
let plate = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let platePath = CGPath(roundedRect: plate, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor.black.withAlphaComponent(0.55).cgColor)
ctx.addPath(platePath); ctx.setFillColor(NSColor(white: 0.08, alpha: 1).cgColor); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(platePath); ctx.clip()
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [NSColor(white: 0.20, alpha: 1).cgColor, NSColor(white: 0.06, alpha: 1).cgColor] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
// brushing + scratches
var seed: UInt64 = 42
func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) % 100000) / 100000 }
for _ in 0..<900 {
    let y = plate.minY + rnd() * plate.height, x = plate.minX + rnd() * plate.width
    ctx.setStrokeColor(NSColor(white: 1, alpha: 0.015 + rnd() * 0.02).cgColor); ctx.setLineWidth(1)
    ctx.move(to: CGPoint(x: x, y: y)); ctx.addLine(to: CGPoint(x: x + 60 + rnd() * 300, y: y)); ctx.strokePath()
}
for _ in 0..<26 {
    let x = plate.minX + rnd() * plate.width, y = plate.minY + rnd() * plate.height, a = (rnd() - 0.5) * 1.2, l = 60 + rnd() * 260
    ctx.setStrokeColor(NSColor(white: 1, alpha: 0.05 + rnd() * 0.08).cgColor); ctx.setLineWidth(1.2)
    ctx.move(to: CGPoint(x: x, y: y)); ctx.addLine(to: CGPoint(x: x + cos(a) * l, y: y + sin(a) * l)); ctx.strokePath()
}
ctx.restoreGState()

// Bevel + silver ring
ctx.addPath(platePath); ctx.setStrokeColor(NSColor(white: 0.8, alpha: 0.55).cgColor); ctx.setLineWidth(6); ctx.strokePath()

// Screws
func screw(_ c: CGPoint) {
    let r: CGFloat = 22
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: [NSColor(white: 0.85, alpha: 1).cgColor, NSColor(white: 0.35, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)); ctx.clip()
    ctx.drawRadialGradient(g, startCenter: CGPoint(x: c.x - 7, y: c.y + 7), startRadius: 0, endCenter: c, endRadius: r, options: [])
    ctx.restoreGState()
    ctx.setStrokeColor(NSColor(white: 0.15, alpha: 1).cgColor); ctx.setLineWidth(5)
    ctx.move(to: CGPoint(x: c.x - 14, y: c.y - 6)); ctx.addLine(to: CGPoint(x: c.x + 14, y: c.y + 6)); ctx.strokePath()
}
for p in [CGPoint(x: 200, y: 200), CGPoint(x: 824, y: 200), CGPoint(x: 200, y: 824), CGPoint(x: 824, y: 824)] { screw(p) }

// Stem
let center = CGPoint(x: 512, y: 560)
ctx.setStrokeColor(NSColor(calibratedRed: 0.36, green: 0.66, blue: 0.38, alpha: 0.9).cgColor)
ctx.setLineWidth(12); ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: center.x, y: center.y - 30))
ctx.addCurve(to: CGPoint(x: 470, y: 200), control1: CGPoint(x: 520, y: 400), control2: CGPoint(x: 470, y: 300))
ctx.strokePath()

// Seed head: glowing amber filaments with tufts
let amber = NSColor(calibratedRed: 1.0, green: 0.69, blue: 0.165, alpha: 1)
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 22, color: amber.withAlphaComponent(0.8).cgColor)
let count = 46
for i in 0..<count {
    let a = CGFloat(i) / CGFloat(count) * .pi * 2 + (rnd() - 0.5) * 0.05
    let len: CGFloat = 215 + rnd() * 25
    let end = CGPoint(x: center.x + cos(a) * len, y: center.y + sin(a) * len)
    ctx.setStrokeColor(amber.withAlphaComponent(0.85).cgColor); ctx.setLineWidth(4)
    ctx.move(to: CGPoint(x: center.x + cos(a) * 40, y: center.y + sin(a) * 40)); ctx.addLine(to: end); ctx.strokePath()
    // tuft: small fan of hairs
    for j in -3...3 {
        let b = a + CGFloat(j) * 0.16
        ctx.setStrokeColor(NSColor(calibratedRed: 1, green: 0.85, blue: 0.55, alpha: 0.75).cgColor); ctx.setLineWidth(2)
        ctx.move(to: end); ctx.addLine(to: CGPoint(x: end.x + cos(b) * 38, y: end.y + sin(b) * 38)); ctx.strokePath()
    }
}
// core
let core = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [NSColor(calibratedRed: 1, green: 0.95, blue: 0.8, alpha: 1).cgColor, amber.cgColor,
                               NSColor(calibratedRed: 0.6, green: 0.3, blue: 0.05, alpha: 1).cgColor] as CFArray,
                      locations: [0, 0.45, 1])!
ctx.addEllipse(in: CGRect(x: center.x - 48, y: center.y - 48, width: 96, height: 96)); ctx.clip()
ctx.drawRadialGradient(core, startCenter: CGPoint(x: center.x - 14, y: center.y + 14), startRadius: 0,
                       endCenter: center, endRadius: 48, options: [])
ctx.restoreGState()

// A couple of seeds drifting away
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 12, color: amber.withAlphaComponent(0.7).cgColor)
for (p, a) in [(CGPoint(x: 800, y: 760), 0.9), (CGPoint(x: 760, y: 860), 0.5)] as [(CGPoint, CGFloat)] {
    ctx.setStrokeColor(amber.withAlphaComponent(0.8).cgColor); ctx.setLineWidth(3)
    let base = CGPoint(x: p.x - cos(a) * 50, y: p.y - sin(a) * 50)
    ctx.move(to: base); ctx.addLine(to: p); ctx.strokePath()
    for j in -3...3 {
        let b = a + CGFloat(j) * 0.18
        ctx.move(to: p); ctx.addLine(to: CGPoint(x: p.x + cos(b) * 26, y: p.y + sin(b) * 26)); ctx.strokePath()
    }
}
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("Wrote \(out)")
