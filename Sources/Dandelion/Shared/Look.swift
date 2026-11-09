import SwiftUI
import AppKit

// MARK: - Colour themes and faceplates, following the ProtoArt Studio rack skin.
// Four themes (Amber, Cream, Slate, Ember), each in a Light (brushed aluminium, painted trim)
// or Dark (black anodised) faceplate. Whatever is switched on lights up in the theme's lamp colour.

enum Skin: String, CaseIterable, Identifiable {
    case powder, amber, cream, slate, ember
    var id: Self { self }
    var title: String {
        switch self {
        case .powder: return "Powder"
        case .amber: return "Amber"
        case .cream: return "Cream"
        case .slate: return "Slate"
        case .ember: return "Ember"
        }
    }
    var blurb: String {
        switch self {
        case .powder: return "powder coat: blue on the Light faceplate, burnt orange on the Dark one; white printing, coloured knobs"
        case .amber: return "charcoal and amber, the classic look"
        case .cream: return "warm cream, yellow lamps, deep red"
        case .slate: return "blue-grey steel, ivory lamps"
        case .ember: return "black and red-orange"
        }
    }
}

enum Faceplate: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: Self { self }
    var title: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "Match macOS"
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: alpha)
    }
}

struct Palette {
    let skin: Skin
    let dark: Bool

    // lamps & lit controls
    let litHi: Color, litMid: Color, litLo: Color, litInk: Color, litEdge: Color
    let glow: Color
    let amber: Color          // readouts, amber windows
    // lettering
    let text: Color, muted: Color, ink: Color
    // painted trim (light faceplate)
    let ear: [Color], earEdge: Color, stripe: [Color]
    // metal tone for the textures
    let metal: (Double, Double, Double)
    let metalCard: (Double, Double, Double)
    /// Powder-coated finish: fine grain instead of brushing, white silkscreen instead of engraving.
    let powder: Bool
    /// Knob cap colours, used in order (powder skin: blue, yellow, orange, red, green, black).
    let knobs: [Color]

    static var current = Palette(skin: .powder, dark: false)

    init(skin: Skin, dark: Bool) {
        self.skin = skin
        self.dark = dark
        powder = skin == .powder
        knobs = skin != .powder ? []
            : dark
            ? [0x4d7cc7, 0xf3df45, 0x26272b, 0xeee8d6, 0x5cc28e, 0x9c2f1a].map { Color(hex: $0) }   // on orange
            : [0x4d7cc7, 0xf3df45, 0xf28b3c, 0xd4542e, 0x5cc28e, 0x26272b].map { Color(hex: $0) }   // on blue
        switch skin {
        case .powder:
            litHi = Color(hex: 0xfffbe0); litMid = Color(hex: 0xf6e35a); litLo = Color(hex: 0xd9b52a)
            litInk = Color(hex: 0x2a2300); litEdge = Color(hex: 0x6e5a00)
            glow = Color(red: 1, green: 228 / 255, blue: 90 / 255); amber = Color(hex: 0xffd84a)
            ear = dark ? [0xa8441a, 0xd8662c, 0xc75824, 0x9a3c16].map { Color(hex: $0) }
                       : [0x4a78c8, 0x6f9ae6, 0x5f8bdc, 0x426ebd].map { Color(hex: $0) }
            earEdge = dark ? Color(hex: 0x5a2208) : Color(hex: 0x2c3f78)
            stripe = []
            metal = dark ? (196, 88, 34) : (90, 140, 230)   // burnt orange / cornflower blue
            ink = Color(hex: 0xffe45c)
            text = Color(hex: 0xf7f8fc)
            muted = Color(hex: 0xf7f8fc).opacity(0.78)
        case .amber:
            litHi = Color(hex: 0xfff1c4); litMid = Color(hex: 0xffbf55); litLo = Color(hex: 0xee9222)
            litInk = Color(hex: 0x2a1600); litEdge = Color(hex: 0x6e3c00)
            glow = Color(red: 1, green: 160 / 255, blue: 30 / 255); amber = Color(hex: 0xffae2b)
            ear = [0xb9520e, 0xf08a2c, 0xe2761c, 0xa9490b].map { Color(hex: $0) }; earEdge = Color(hex: 0x5c2a05)
            stripe = [0xf39a3e, 0xe06b14, 0xa94a09].map { Color(hex: $0) }
            metal = dark ? (40, 41, 44) : (204, 202, 198)
            ink = dark ? Color(hex: 0xf3b552) : Color(hex: 0x763a00)
            text = dark ? Color(hex: 0xefeadc) : Color(hex: 0x16171a)
            muted = dark ? Color(hex: 0xa8a59b) : Color(hex: 0x404348)
        case .cream:
            litHi = Color(hex: 0xfff8de); litMid = Color(hex: 0xffd36b); litLo = Color(hex: 0xe0a02a)
            litInk = Color(hex: 0x2b1a00); litEdge = Color(hex: 0x7a5200)
            glow = Color(red: 1, green: 196 / 255, blue: 80 / 255); amber = Color(hex: 0xffc94a)
            ear = [0x6e2018, 0xb8463a, 0x9c3326, 0x651c14].map { Color(hex: $0) }; earEdge = Color(hex: 0x3a0f0a)
            stripe = [0xc95a4b, 0x9c3326, 0x651c14].map { Color(hex: $0) }
            metal = dark ? (54, 47, 40) : (224, 213, 192)
            ink = dark ? Color(hex: 0xffc94a) : Color(hex: 0x7a2c1f)
            text = dark ? Color(hex: 0xf1e9d6) : Color(hex: 0x1f1a14)
            muted = dark ? Color(hex: 0xb3a892) : Color(hex: 0x5b5143)
        case .slate:
            litHi = Color(hex: 0xfffdf3); litMid = Color(hex: 0xf1e2b4); litLo = Color(hex: 0xcdb57a)
            litInk = Color(hex: 0x26200f); litEdge = Color(hex: 0x7a683a)
            glow = Color(red: 1, green: 232 / 255, blue: 170 / 255); amber = Color(hex: 0xffe7ad)
            ear = [0x34495a, 0x6d8ea5, 0x56778e, 0x2f4252].map { Color(hex: $0) }; earEdge = Color(hex: 0x18242e)
            stripe = [0x7f9fb5, 0x56778e, 0x2f4252].map { Color(hex: $0) }
            metal = dark ? (46, 54, 64) : (180, 190, 199)
            ink = dark ? Color(hex: 0xcfe0ec) : Color(hex: 0x1f4d68)
            text = dark ? Color(hex: 0xe8edf1) : Color(hex: 0x121820)
            muted = dark ? Color(hex: 0x9eabb6) : Color(hex: 0x3f4a55)
        case .ember:
            litHi = Color(hex: 0xffdcc6); litMid = Color(hex: 0xff7d42); litLo = Color(hex: 0xd63c14)
            litInk = Color(hex: 0x280700); litEdge = Color(hex: 0x7a1d00)
            glow = Color(red: 1, green: 84 / 255, blue: 34 / 255); amber = Color(hex: 0xff6a2c)
            ear = [0x3a1610, 0xa3341a, 0x7c2410, 0x2c100b].map { Color(hex: $0) }; earEdge = Color(hex: 0x120604)
            stripe = [0xff6232, 0xd2380e, 0x7c2410].map { Color(hex: $0) }
            metal = dark ? (26, 21, 21) : (196, 186, 182)
            ink = dark ? Color(hex: 0xff7d42) : Color(hex: 0x8a2306)
            text = dark ? Color(hex: 0xeee3df) : Color(hex: 0x1b1212)
            muted = dark ? Color(hex: 0xaa9a95) : Color(hex: 0x4c4140)
        }
        metalCard = skin == .powder
            ? (metal.0 + 3, metal.1 + 4, metal.2 + 3)
            : dark ? (metal.0 + 4, metal.1 + 4, metal.2 + 4) : (metal.0 - 10, metal.1 - 10, metal.2 - 10)
    }

    /// Engraving: dark plates get paint with a shadow above; light plates get a white highlight below.
    var engraveShadow: (Color, CGFloat) {
        if powder { return (.black.opacity(0.22), 0.6) }   // printed, not engraved
        return dark ? (.black.opacity(0.85), -1) : (.white.opacity(0.62), 1)
    }
    /// The thin highlight line under recessed parts.
    var groove: Color { powder ? .white.opacity(0.25) : dark ? .white.opacity(0.07) : .white.opacity(0.6) }
}

@MainActor
final class Look: ObservableObject {
    @Published var skin: Skin { didSet { persist(); refresh() } }
    @Published var faceplate: Faceplate { didSet { persist(); refresh() } }
    @Published private(set) var palette: Palette

    private var observer: NSObjectProtocol?

    init() {
        let d = UserDefaults.standard
        let skin = Skin(rawValue: d.string(forKey: "look.skin") ?? "") ?? .powder
        let face = Faceplate(rawValue: d.string(forKey: "look.faceplate") ?? "") ?? .light
        self.skin = skin
        self.faceplate = face
        let p = Palette(skin: skin, dark: Look.resolveDark(face))
        palette = p
        Palette.current = p
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    var signature: String { "\(palette.skin.rawValue)-\(palette.dark)" }

    private func persist() {
        UserDefaults.standard.set(skin.rawValue, forKey: "look.skin")
        UserDefaults.standard.set(faceplate.rawValue, forKey: "look.faceplate")
    }

    private func refresh() {
        let p = Palette(skin: skin, dark: Look.resolveDark(faceplate))
        Palette.current = p
        palette = p
    }

    private static func resolveDark(_ face: Faceplate) -> Bool {
        switch face {
        case .dark: return true
        case .light: return false
        case .system: return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        }
    }
}

// MARK: - Brushed metal texture (same recipe as the Studio's rack.js, in Swift)

enum MetalTexture {
    nonisolated(unsafe) private static var cache: [String: CGImage] = [:]

    static func image(base: (Double, Double, Double), seed: UInt64, size: Int = 768,
                      brush: Double = 7, grain: Double = 5, scratches: Double = 1, wear: Int = 0) -> CGImage? {
        let key = "\(base.0)-\(base.1)-\(base.2)-\(seed)-\(size)-\(brush)-\(grain)-\(scratches)"
        if let hit = cache[key] { return hit }

        let w = size, h = size
        var rng = SeededRandom(seed: seed)
        func gauss() -> Double {
            let u = max(Double(rng.next()), 1e-6), v = Double(rng.next())
            return sqrt(-2 * log(u)) * cos(2 * .pi * v)
        }
        var pixels = [UInt8](repeating: 255, count: w * h * 4)
        var raw = [Double](repeating: 0, count: w)
        var row = [Double](repeating: 0, count: w)
        let r = 24 // streak length (horizontal blur radius)
        for y in 0..<h {
            for x in 0..<w { raw[x] = Double(rng.next()) - 0.5 }
            var acc = 0.0
            for k in -r...r { acc += raw[(k + w) % w] }
            for x in 0..<w {
                row[x] = acc / Double(2 * r + 1)
                acc += raw[(x + r + 1) % w] - raw[(x - r + w) % w]
            }
            let rowTone = brush > 0 ? gauss() * 2.2 + (rng.next() < 0.025 ? gauss() * 7 : 0) : 0
            let o = y * w * 4
            for x in 0..<w {
                let v = rowTone + row[x] * brush * 9 + (Double(rng.next()) - 0.5) * grain * 2
                pixels[o + x * 4] = UInt8(clamping: Int(base.0 + v))
                pixels[o + x * 4 + 1] = UInt8(clamping: Int(base.1 + v))
                pixels[o + x * 4 + 2] = UInt8(clamping: Int(base.2 + v * 1.05))
            }
        }
        let image: CGImage? = pixels.withUnsafeMutableBytes { buffer -> CGImage? in
        guard let ctx = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        // wear: grime in places, rubbed-bright patches in others
        for _ in 0..<wear {
            let x = Double(rng.next()) * Double(w), y = Double(rng.next()) * Double(h), rad = 40 + Double(rng.next()) * 150
            let darkSpot = rng.next() < 0.55
            let colors = [CGColor(red: darkSpot ? 0.16 : 1, green: darkSpot ? 0.14 : 1, blue: darkSpot ? 0.12 : 1,
                                  alpha: darkSpot ? 0.07 : 0.08),
                          CGColor(red: 0, green: 0, blue: 0, alpha: 0)] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.drawRadialGradient(g, startCenter: CGPoint(x: x, y: y), startRadius: 0,
                                       endCenter: CGPoint(x: x, y: y), endRadius: rad, options: [])
            }
        }
        // scratches: fine light hairlines with a darker twin
        let count = Int(Double(w * h) / 9000 * scratches)
        for _ in 0..<count {
            let x = Double(rng.next()) * Double(w), y = Double(rng.next()) * Double(h)
            let a = (Double(rng.next()) - 0.5) * 2.4, len = 15 + Double(rng.next()) * 140
            let bend = (Double(rng.next()) - 0.5) * 10
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: y))
            path.addQuadCurve(to: CGPoint(x: x + cos(a) * len, y: y + sin(a) * len),
                              control: CGPoint(x: x + cos(a) * len / 2 + bend, y: y + sin(a) * len / 2 - bend))
            ctx.addPath(path)
            ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.05 + Double(rng.next()) * 0.09))
            ctx.setLineWidth(0.5 + Double(rng.next()) * 0.6)
            ctx.strokePath()
            ctx.saveGState()
            ctx.translateBy(x: 0.6, y: -0.6)
            ctx.addPath(path)
            ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.05))
            ctx.setLineWidth(0.5)
            ctx.strokePath()
            ctx.restoreGState()
        }
        return ctx.makeImage()
        }
        if let image { cache[key] = image }
        return image
    }
}
