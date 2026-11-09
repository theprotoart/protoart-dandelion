import SwiftUI
import AppKit

// MARK: - ProtoArt rack kit, drawn natively in SwiftUI.
// Mirrors the ProtoArt Studio skin: brushed faceplates, bakelite caps, lit keys, bat-handle toggles,
// knurled knobs, chicken-head switches, LEDs, amber readouts, VU meter, masking tape.

enum Rack {
    // theme-dependent (read from the current palette; the window is rebuilt when the look changes)
    static var amber: Color { Palette.current.amber }
    static var paint: Color { Palette.current.text }
    static var muted: Color { Palette.current.muted }
    static var ink: Color { Palette.current.ink }
    static var lit: Color { Palette.current.litMid }
    static var amberDeep: Color { Palette.current.litLo }
    // fixed
    static let green = Color(hex: 0x7dff5a)
    static let red = Color(hex: 0xff4a32)
    static let blue = Color(hex: 0x6fb0f0)
    static let card = Color(hex: 0xece4cf)
    static let cardInk = Color(hex: 0x1d1b16)
    static let cardRed = Color(hex: 0xa84a0c)
    static let capText = Color(hex: 0xece7da)
    static let marker = Color(red: 18 / 255, green: 20 / 255, blue: 44 / 255).opacity(0.9)
    static let tape = Color(hex: 0xeee1bb)

    static func engrave(_ size: CGFloat) -> Font { .custom("DIN Alternate", size: size).weight(.bold) }
    static func condensed(_ size: CGFloat) -> Font { .custom("DIN Condensed", size: size).weight(.bold) }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .custom("Menlo", size: size).weight(weight) }
    static func brand(_ size: CGFloat) -> Font { .custom("Futura-Bold", size: size) }
    static func serif(_ size: CGFloat) -> Font { .custom("American Typewriter", size: size) }
    static func marker(_ size: CGFloat) -> Font { .custom("Marker Felt", size: size) }
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 &+ 1 }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 1_000_000) / 1_000_000
    }
}

extension Color {
    func mix(with other: Color, by amount: Double) -> Color {
        let a = NSColor(self).usingColorSpace(.sRGB) ?? .white
        let b = NSColor(other).usingColorSpace(.sRGB) ?? .white
        let t = CGFloat(amount)
        return Color(red: a.redComponent * (1 - t) + b.redComponent * t,
                     green: a.greenComponent * (1 - t) + b.greenComponent * t,
                     blue: a.blueComponent * (1 - t) + b.blueComponent * t)
    }
}

// MARK: Faceplate surfaces

struct RackSurface: View {
    enum Kind { case plate, card, ear }
    var kind: Kind = .plate

    var body: some View {
        let p = Palette.current
        let base: (Double, Double, Double) = kind == .card ? p.metalCard : p.metal
        let seed: UInt64 = kind == .card ? 1176 : 1979
        ZStack {
            if let img = MetalTexture.image(base: base, seed: seed,
                                            brush: p.powder ? 0 : (p.dark ? 4 : 7),
                                            grain: p.powder ? 3.5 : (p.dark ? 3 : 5),
                                            scratches: p.powder ? 0.12 : (p.dark ? 0.6 : 1)) {
                Image(decorative: img, scale: 2).resizable(resizingMode: .tile)
            } else {
                Color(red: base.0 / 255, green: base.1 / 255, blue: base.2 / 255)
            }
        }
    }
}

/// Rack ear: anodised (dark) or painted in the theme colour (light), with a slot and a screw.
struct RackEar: View {
    /// Distance of the screw from the top (the top panel's ears keep clear of the window buttons).
    var screwTop: CGFloat = 12
    var body: some View {
        let p = Palette.current
        ZStack {
            if p.dark {
                LinearGradient(colors: [.black.opacity(0.06), .white.opacity(0.06), .black.opacity(0.1)],
                               startPoint: .leading, endPoint: .trailing)
            } else {
                LinearGradient(colors: [p.ear[0], p.ear[1], p.ear[2], p.ear[3]], startPoint: .leading, endPoint: .trailing)
                    .overlay(RackSurface().opacity(0.12).blendMode(.overlay))
            }
            VStack {
                Screw(size: 18).padding(.top, screwTop)
                Spacer()
                Capsule()
                    .fill(Color(white: 0.03))
                    .frame(width: 13, height: 26)
                    .shadow(color: p.groove, radius: 0, y: 1)
                    .padding(.bottom, 14)
            }
        }
        .frame(width: 40)
        .overlay(alignment: .leading) { Rectangle().fill(.black.opacity(0.35)).frame(width: 1) }
        .overlay(alignment: .trailing) { Rectangle().fill(.black.opacity(0.35)).frame(width: 1) }
    }
}

/// The orange (theme) stripe painted under panels on the light faceplate.
struct TrimStripe: View {
    var body: some View {
        let p = Palette.current
        if p.dark || p.stripe.isEmpty {
            Rectangle().fill(.black.opacity(p.powder ? 0.35 : 1)).frame(height: p.powder ? 1 : 2)
        } else {
            LinearGradient(colors: p.stripe, startPoint: .top, endPoint: .bottom).frame(height: 4)
        }
    }
}

// MARK: Lettering

struct Engraved: View {
    enum Tone { case normal, muted, lit, ink }
    let text: String
    var size: CGFloat
    var tone: Tone
    var color: Color?

    init(_ text: String, size: CGFloat = 12, tone: Tone = .normal, color: Color? = nil) {
        self.text = text; self.size = size; self.tone = tone; self.color = color
    }

    var body: some View {
        let p = Palette.current
        let c: Color = color ?? {
            switch tone {
            case .normal: return p.text
            case .muted: return p.muted
            case .lit: return p.dark ? p.amber : p.ink
            case .ink: return p.ink
            }
        }()
        Text(text.uppercased())
            .font(Rack.engrave(size))
            .tracking(size * 0.14)
            .foregroundStyle(c)
            .shadow(color: color == nil ? p.engraveShadow.0 : .black.opacity(0.8), radius: 0, x: 0,
                    y: color == nil ? p.engraveShadow.1 : -1)
            .lineLimit(1)
    }
}

// MARK: Hardware bits

struct Screw: View {
    var size: CGFloat = 11
    var angle: Double = 35
    var body: some View {
        if Palette.current.powder { phillips } else { slotted }
    }

    /// Black Phillips screw, as on a powder-coated 500-series panel.
    private var phillips: some View {
        ZStack {
            Circle().fill(.black.opacity(0.35)).offset(y: 1).blur(radius: 0.8)
            Circle().fill(RadialGradient(colors: [Color(hex: 0x4a4b50), Color(hex: 0x17181a), Color(hex: 0x050506)],
                                         center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.7))
            ForEach([angle, angle + 90], id: \.self) { a in
                Capsule().fill(Color(hex: 0x000000)).frame(width: size * 0.62, height: max(1.4, size * 0.15))
                    .rotationEffect(.degrees(a))
            }
            Ellipse().fill(.white.opacity(0.28)).frame(width: size * 0.3, height: size * 0.16).offset(x: -size * 0.15, y: -size * 0.22)
        }
        .frame(width: size, height: size)
    }

    private var slotted: some View {
        ZStack {
            Circle().fill(.black.opacity(0.45)).offset(y: 1).blur(radius: 0.6)
            Circle().fill(RadialGradient(colors: [.white, Color(hex: 0x8a8d92), Color(hex: 0x3a3c40)],
                                         center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.75))
            Capsule().fill(Color(hex: 0x2a2b2e)).frame(width: size * 0.78, height: max(1.5, size * 0.14))
                .rotationEffect(.degrees(angle))
            Capsule().fill(.white.opacity(0.35)).frame(width: size * 0.78, height: 0.6)
                .offset(y: size * 0.08).rotationEffect(.degrees(angle))
        }
        .frame(width: size, height: size)
    }
}

struct LED: View {
    var color: Color = Rack.lit
    var on: Bool
    var blink: Bool = false
    var size: CGFloat = 13
    @State private var phase = false

    var body: some View {
        let lit = on && (!blink || phase)
        ZStack {
            Circle().fill(RadialGradient(colors: [Color(white: 0.92), Color(white: 0.55), Color(white: 0.25)],
                                         center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.7))
            Circle()
                .fill(lit
                      ? AnyShapeStyle(RadialGradient(colors: [.white, color, color.mix(with: .black, by: 0.3)],
                                                     center: .init(x: 0.4, y: 0.35), startRadius: 0, endRadius: size * 0.42))
                      : AnyShapeStyle(RadialGradient(colors: [color.mix(with: .black, by: 0.62), color.mix(with: .black, by: 0.85), .black],
                                                     center: .init(x: 0.4, y: 0.35), startRadius: 0, endRadius: size * 0.42)))
                .overlay(Circle().stroke(.black, lineWidth: 0.8))
                .padding(size * 0.17)
                .shadow(color: lit ? color : .clear, radius: size * 0.35)
                .shadow(color: lit ? color.opacity(0.5) : .clear, radius: size * 0.9)
            Ellipse().fill(.white.opacity(lit ? 0.7 : 0.45)).frame(width: size * 0.22, height: size * 0.13)
                .offset(x: -size * 0.12, y: -size * 0.16)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
        .onAppear {
            guard blink else { return }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { phase = true }
        }
    }
}

/// The dandelion emblem in its silver bezel (the badge on the brand plate).
struct DandelionEmblem: View {
    var size: CGFloat = 48
    var body: some View {
        let p = Palette.current
        ZStack {
            Circle().fill(Color(hex: 0x2b2c2f))
            Circle().fill(LinearGradient(colors: [Color(hex: 0xe9eaec), Color(hex: 0x8b8e93)], startPoint: .top, endPoint: .bottom))
                .padding(1)
            Circle().fill(RadialGradient(colors: [Color(hex: 0x24180f), Color(hex: 0x0b0806)], center: .init(x: 0.45, y: 0.4),
                                         startRadius: 0, endRadius: size * 0.5))
                .padding(size * 0.07)
            Canvas { ctx, s in
                let c = CGPoint(x: s.width / 2, y: s.height * 0.46)
                var stem = Path()
                stem.move(to: CGPoint(x: c.x, y: c.y + s.height * 0.06))
                stem.addQuadCurve(to: CGPoint(x: c.x - s.width * 0.05, y: s.height * 0.86),
                                  control: CGPoint(x: c.x + s.width * 0.04, y: s.height * 0.7))
                ctx.stroke(stem, with: .color(Color(hex: 0x6fae5a)), lineWidth: max(1, s.width * 0.035))
                let n = 22
                for i in 0..<n {
                    let a = Double(i) / Double(n) * 2 * .pi
                    let r = s.width * 0.27
                    let end = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                    var line = Path(); line.move(to: c); line.addLine(to: end)
                    ctx.stroke(line, with: .color(p.amber.opacity(0.85)), lineWidth: max(0.6, s.width * 0.014))
                    for j in -1...1 {
                        let b = a + Double(j) * 0.35
                        var hair = Path(); hair.move(to: end)
                        hair.addLine(to: CGPoint(x: end.x + cos(b) * s.width * 0.05, y: end.y + sin(b) * s.width * 0.05))
                        ctx.stroke(hair, with: .color(p.litHi.opacity(0.8)), lineWidth: 0.6)
                    }
                }
                let core = CGRect(x: c.x - s.width * 0.05, y: c.y - s.width * 0.05, width: s.width * 0.1, height: s.width * 0.1)
                ctx.fill(Path(ellipseIn: core), with: .color(p.litMid))
            }
            .padding(size * 0.07)
            .shadow(color: p.glow.opacity(0.6), radius: 3)
            Circle().fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .topLeading, endPoint: .center))
                .padding(size * 0.07)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.55), radius: 3, y: 2)
    }
}

/// Black anodised brand plate, screwed on: emblem + PROTOART / DANDELION · PD-1.
struct BrandPlate: View {
    var compact = false

    var body: some View {
        if Palette.current.powder { printed } else { plate }
    }

    /// Printed straight onto the powder coat: white logo, red-orange model name, emblem in a white ring.
    private var printed: some View {
        HStack(spacing: compact ? 8 : 12) {
            ZStack {
                Circle().fill(.white).frame(width: compact ? 36 : 54, height: compact ? 36 : 54)
                DandelionEmblem(size: compact ? 32 : 48)
            }
            VStack(alignment: .leading, spacing: compact ? 0 : 1) {
                Text("protoart")
                    .fixedSize()
                    .font(.custom("Futura-Medium", size: compact ? 20 : 30))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 0, y: 0.6)
                Text("DANDELION")
                    .fixedSize()
                    .font(Rack.engrave(compact ? 9 : 12))
                    .tracking(compact ? 3 : 4.5)
                    .foregroundStyle(Palette.current.dark ? Color(hex: 0xffe45c) : Color(hex: 0xff4f1f))
                    .shadow(color: .black.opacity(0.25), radius: 0, y: 0.6)
                if !compact {
                    Text("PD-1 · MAC CLEANING UNIT")
                        .fixedSize()
                        .font(Rack.engrave(8.5))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, compact ? 4 : 6)
    }

    private var plate: some View {
        let p = Palette.current
        return HStack(spacing: compact ? 8 : 12) {
            DandelionEmblem(size: compact ? 34 : 50)
            VStack(alignment: .leading, spacing: compact ? 3 : 5) {
                Text("PROTOART")
                    .fixedSize()
                    .font(Rack.engrave(compact ? 15 : 20))
                    .tracking(compact ? 3.4 : 4.8)
                    .foregroundStyle(Color(hex: 0xece6d6))
                    .shadow(color: .black, radius: 0, y: -1)
                Text("DANDELION · PD-1")
                    .fixedSize()
                    .font(Rack.engrave(compact ? 8 : 9.5))
                    .tracking(compact ? 2.4 : 3)
                    .foregroundStyle(p.skin == .slate ? p.litLo : p.amber.mix(with: Color(hex: 0xd0a35a), by: 0.4))
            }
        }
        .padding(.leading, compact ? 14 : 18)
        .padding(.trailing, compact ? 18 : 28)
        .padding(.vertical, compact ? 6 : 8)
        .background(
            ZStack {
                LinearGradient(colors: [Color(hex: 0x2c2d31), Color(hex: 0x161719), Color(hex: 0x0f1012)],
                               startPoint: .top, endPoint: .bottom)
                Canvas { ctx, s in
                    var rng = SeededRandom(seed: 11)
                    for _ in 0..<26 {
                        let x = rng.next() * s.width, y = rng.next() * s.height, a = (rng.next() - 0.5) * 1.4, l = 8 + rng.next() * 50
                        var path = Path(); path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + cos(a) * l, y: y + sin(a) * l))
                        ctx.stroke(path, with: .color(.white.opacity(0.04 + rng.next() * 0.05)), lineWidth: 0.5)
                    }
                }
            }
        )
        .overlay(alignment: .leading) { Screw(size: 9, angle: 20).padding(.leading, 5) }
        .overlay(alignment: .trailing) { Screw(size: 9, angle: 80).padding(.trailing, 6) }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.black, lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.14), lineWidth: 1).padding(1).mask(
            VStack { Rectangle().frame(height: 2); Spacer() }))
        .shadow(color: p.groove, radius: 0, y: 1)
        .shadow(color: .black.opacity(0.35), radius: 3, y: 3)
    }
}

// MARK: Buttons

/// Every push button on the rack.
///  .cap      bakelite cap (default)          .primary  lit key in the theme's lamp colour
///  .danger   red key                         .ghost    silver key
///  .tab      illuminated tab with a lamp; `active` presses it in and lights the lamp
struct RackButtonStyle: ButtonStyle {
    enum Kind: Equatable { case cap, primary, danger, ghost, tab(active: Bool), dangerText }
    var kind: Kind = .cap
    var height: CGFloat = 32
    var fontSize: CGFloat = 12
    var fill = false

    init(kind: Kind = .cap, height: CGFloat = 32, fontSize: CGFloat = 12, fill: Bool = false) {
        self.kind = kind; self.height = height; self.fontSize = fontSize; self.fill = fill
    }

    /// `lit` = primary key.
    init(lit: Bool, height: CGFloat = 32, fontSize: CGFloat = 12) {
        self.kind = lit ? .primary : .cap
        self.height = height; self.fontSize = fontSize
    }

    /// Red tint: a lit red key, or red lettering on a bakelite cap when not lit.
    init(lit: Bool = false, tint: Color, height: CGFloat = 32, fontSize: CGFloat = 12) {
        let red = tint == Rack.red
        self.kind = red ? (lit ? .danger : .dangerText) : (lit ? .primary : .cap)
        self.height = height; self.fontSize = fontSize
    }

    func makeBody(configuration: Configuration) -> some View {
        KeyBody(configuration: configuration, kind: kind, height: height, fontSize: fontSize, fill: fill)
    }

    private struct KeyBody: View {
        let configuration: Configuration
        let kind: Kind
        let height: CGFloat
        let fontSize: CGFloat
        let fill: Bool
        @Environment(\.isEnabled) private var isEnabled
        @State private var hover = false

        var body: some View {
            let p = Palette.current
            let pressed = configuration.isPressed
            let tabActive: Bool = { if case .tab(let a) = kind { return a } else { return false } }()
            let isTab: Bool = { if case .tab = kind { return true } else { return false } }()

            HStack(spacing: 7) {
                if isTab { LED(on: tabActive, size: 8) }
                configuration.label
            }
            .font(Rack.engrave(fontSize))
            .tracking(fontSize * 0.12)
            .textCase(.uppercase)
            .lineLimit(1)
            .foregroundStyle(textColor(p, tabActive: tabActive))
            .shadow(color: textShadow(p), radius: 0, y: kind == .primary || kind == .ghost ? 1 : -1)
            .padding(.horizontal, 14)
            .frame(maxWidth: fill ? .infinity : nil, minHeight: height)
            .background(background(p, pressed: pressed, tabActive: tabActive))
            .brightness(hover && isEnabled && !pressed ? 0.06 : 0)
            .offset(y: pressed || tabActive ? (tabActive ? 2 : 1) : 0)
            .opacity(isEnabled ? 1 : (kind == .primary ? 0.75 : 0.5))
            .saturation(isEnabled ? 1 : 0.3)
            .contentShape(Rectangle())
            .onHover { hover = $0 }
        }

        private func textColor(_ p: Palette, tabActive: Bool) -> Color {
            switch kind {
            case .primary: return p.litInk
            case .danger: return Color(hex: 0xfff3ef)
            case .ghost: return Color(hex: 0x1c1d20)
            case .dangerText: return Color(hex: 0xff8a75)
            case .tab: return tabActive ? Color(hex: 0xfff2d2) : Rack.capText
            case .cap: return Rack.capText
            }
        }

        private func textShadow(_ p: Palette) -> Color {
            switch kind {
            case .primary: return .white.opacity(0.45)
            case .ghost: return .white.opacity(0.7)
            default: return .black
            }
        }

        @ViewBuilder
        private func background(_ p: Palette, pressed: Bool, tabActive: Bool) -> some View {
            let shape = RoundedRectangle(cornerRadius: 3)
            switch kind {
            case .primary:
                shape.fill(RadialGradient(colors: [p.litHi, p.litMid, p.litLo], center: .init(x: 0.5, y: 0.25),
                                          startRadius: 0, endRadius: max(height * 1.6, 60)))
                    .overlay(shape.strokeBorder(p.litEdge, lineWidth: 1))
                    .overlay(shape.inset(by: 1).stroke(.white.opacity(0.7), lineWidth: 1).mask(topEdge))
                    .shadow(color: p.glow.opacity(pressed ? 0.25 : 0.45), radius: 9)
                    .shadow(color: p.litEdge.mix(with: .black, by: 0.4), radius: 0, y: pressed ? 1 : 2)
            case .danger:
                shape.fill(RadialGradient(colors: [Color(hex: 0xff9a85), Color(hex: 0xe0402c), Color(hex: 0xa8180c)],
                                          center: .init(x: 0.5, y: 0.25), startRadius: 0, endRadius: max(height * 1.6, 60)))
                    .overlay(shape.strokeBorder(Color(hex: 0x4a0905), lineWidth: 1))
                    .overlay(shape.inset(by: 1).stroke(.white.opacity(0.45), lineWidth: 1).mask(topEdge))
                    .shadow(color: Color(hex: 0xff3c1e).opacity(0.35), radius: 7)
                    .shadow(color: Color(hex: 0x3c0602), radius: 0, y: pressed ? 1 : 2)
            case .ghost:
                shape.fill(LinearGradient(colors: [Color(hex: 0xeceef0), Color(hex: 0xc9ccd0), Color(hex: 0xb3b6ba)],
                                          startPoint: .top, endPoint: .bottom))
                    .overlay(shape.strokeBorder(Color(hex: 0x6a6d72), lineWidth: 1))
                    .overlay(shape.inset(by: 1).stroke(.white, lineWidth: 1).mask(topEdge))
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            case .tab(let active) where active:
                shape.fill(LinearGradient(colors: [Color(hex: 0x1d1e21), Color(hex: 0x2b2c30)], startPoint: .top, endPoint: .bottom))
                    .overlay(shape.strokeBorder(Color(hex: 0x0a0a0b), lineWidth: 1))
                    .overlay(shape.inset(by: 1).stroke(.black.opacity(0.75), lineWidth: 3).blur(radius: 2).mask(shape))
                    .shadow(color: p.groove, radius: 0, y: 1)
            default:
                shape.fill(LinearGradient(stops: [.init(color: Color(hex: pressed ? 0x343539 : 0x47484c), location: 0),
                                                  .init(color: Color(hex: 0x2a2b2e), location: 0.55),
                                                  .init(color: Color(hex: 0x1d1e20), location: 1)],
                                          startPoint: .top, endPoint: .bottom))
                    .overlay(shape.strokeBorder(Color(hex: 0x0a0a0b), lineWidth: 1))
                    .overlay(shape.inset(by: 1).stroke(.white.opacity(0.17), lineWidth: 1).mask(topEdge))
                    .shadow(color: p.groove, radius: 0, y: 1)
                    .shadow(color: .black.opacity(pressed ? 0.2 : 0.45), radius: 2, y: pressed ? 0 : 2)
            }
        }

        private var topEdge: some View {
            VStack(spacing: 0) { Rectangle().frame(height: 2); Spacer(minLength: 0) }
        }
    }
}

/// Recessed tray of latching segment buttons; the selected one lights up.
struct RackSelector<T: Hashable>: View {
    let options: [(label: String, value: T)]
    @Binding var selection: T
    var height: CGFloat = 26
    var fontSize: CGFloat = 11

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options.indices, id: \.self) { i in
                Button(options[i].label) { selection = options[i].value }
                    .buttonStyle(RackButtonStyle(kind: selection == options[i].value ? .primary : .cap,
                                                 height: height, fontSize: fontSize))
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0x0d0d0e))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.black, lineWidth: 1).blur(radius: 1.5).mask(RoundedRectangle(cornerRadius: 4)))
            .shadow(color: Palette.current.groove, radius: 0, y: 1))
    }
}

// MARK: Bat-handle toggle

/// Chrome bat-handle lever toggle. Up = on.
struct BatHandle: View {
    var isOn: Bool
    var scale: CGFloat = 1

    var body: some View {
        ZStack {
            // mounting nut & bushing
            Circle().fill(.black.opacity(0.45)).frame(width: 16 * scale, height: 16 * scale).offset(y: 1)
            Circle().fill(LinearGradient(colors: [Color(hex: 0xe9eaec), Color(hex: 0x55585d)], startPoint: .top, endPoint: .bottom))
                .frame(width: 14 * scale, height: 14 * scale)
            Circle().fill(Color(hex: 0x6d7075)).frame(width: 9 * scale, height: 9 * scale)
            Circle().fill(Color(hex: 0xc7cace)).frame(width: 6 * scale, height: 6 * scale)
            // lever
            RoundedRectangle(cornerRadius: 1)
                .fill(LinearGradient(colors: [Color(hex: 0x5d6065), Color(hex: 0xf6f7f9), Color(hex: 0x9ea1a6), Color(hex: 0x4a4d52)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 4.5 * scale, height: 13 * scale)
                .offset(y: (isOn ? -6.5 : 6.5) * scale)
            // bat tip
            Ellipse()
                .fill(RadialGradient(colors: [.white, Color(hex: 0xc4c7cb), Color(hex: 0x6d7075)], center: .init(x: 0.35, y: 0.3),
                                     startRadius: 0, endRadius: 7 * scale))
                .frame(width: 11 * scale, height: 9 * scale)
                .shadow(color: .black.opacity(0.55), radius: 1.2, y: isOn ? -1 : 2)
                .offset(y: (isOn ? -13 : 13) * scale)
        }
        .frame(width: 24 * scale, height: 36 * scale)
        .animation(.easeIn(duration: 0.09), value: isOn)
    }
}

/// Panel toggle: engraved name above, bat handle, ON / OFF below (like TIPS in the Studio).
struct PanelToggle: View {
    let name: String
    @Binding var isOn: Bool
    var onLabel = "On"
    var offLabel = "Off"

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            VStack(spacing: 2) {
                Engraved(name, size: 10.5).fixedSize()
                BatHandle(isOn: isOn, scale: 1.1)
                Engraved(isOn ? onLabel : offLabel, size: 9, tone: isOn ? .lit : .muted).fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Toggle style with a small bat handle and the label beside it (for settings rows).
struct BatToggleStyle: ToggleStyle {
    var scale: CGFloat = 0.8
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                BatHandle(isOn: configuration.isOn, scale: scale)
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Glass windows & readouts

/// Black glass display window (amber screens) with glare and scanlines.
struct GlassWindow<Content: View>: View {
    var scanlines = true
    var cornerRadius: CGFloat = 4
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(LinearGradient(colors: [Color(hex: 0x170c03), Color(hex: 0x0d0701)], startPoint: .top, endPoint: .bottom))
            .overlay { if scanlines { Scanlines().allowsHitTesting(false) } }
            .overlay(LinearGradient(colors: [.white.opacity(0.07), .clear], startPoint: .topLeading, endPoint: .init(x: 0.4, y: 0.4))
                .allowsHitTesting(false))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(.black, lineWidth: 4).blur(radius: 3)
                .mask(RoundedRectangle(cornerRadius: cornerRadius)).allowsHitTesting(false))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.black, lineWidth: 1))
            .shadow(color: Palette.current.groove, radius: 0, y: 1)
    }
}

struct Scanlines: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black.opacity(0.2)))
                y += 3
            }
        }
    }
}

struct AmberText: View {
    let text: String
    var size: CGFloat
    var weight: Font.Weight
    var color: Color?

    init(_ text: String, size: CGFloat = 12, weight: Font.Weight = .regular, color: Color? = nil) {
        self.text = text; self.size = size; self.weight = weight; self.color = color
    }

    var body: some View {
        let c = color ?? Rack.amber
        Text(text)
            .font(Rack.mono(size, weight))
            .foregroundStyle(c)
            .shadow(color: c.opacity(0.5), radius: 3)
            .lineLimit(1)
    }
}

struct SevenSegment: View {
    let text: String
    var digitHeight: CGFloat = 26
    var color: Color? = nil

    private enum Seg: CaseIterable { case a, b, c, d, e, f, g }
    private static let map: [Character: Set<Seg>] = [
        "0": [.a, .b, .c, .d, .e, .f], "1": [.b, .c], "2": [.a, .b, .g, .e, .d], "3": [.a, .b, .g, .c, .d],
        "4": [.f, .g, .b, .c], "5": [.a, .f, .g, .c, .d], "6": [.a, .f, .g, .e, .d, .c], "7": [.a, .b, .c],
        "8": Set(Seg.allCases), "9": [.a, .b, .c, .d, .f, .g], "-": [.g], " ": [],
        "E": [.a, .d, .e, .f, .g], "r": [.e, .g], "o": [.c, .d, .e, .g]
    ]

    private var digitWidth: CGFloat { digitHeight * 0.52 }
    private var gap: CGFloat { digitHeight * 0.2 }
    private var totalWidth: CGFloat {
        text.reduce(CGFloat(8)) { $0 + (($1 == "." || $1 == ":") ? gap * 1.1 : digitWidth + gap) }
    }

    var body: some View {
        let col = color ?? Rack.amber
        Canvas { ctx, _ in
            let h = digitHeight, w = digitWidth, t = h * 0.12
            let skew = CGAffineTransform(a: 1, b: 0, c: -0.1, d: 1, tx: 0.1 * h, ty: 0)
            var x: CGFloat = 4
            for ch in text {
                if ch == "." || ch == ":" {
                    let dots: [CGFloat] = ch == "." ? [h - t] : [h * 0.3, h * 0.7]
                    for dy in dots {
                        let r = CGRect(x: x, y: dy - t / 2 + 2, width: t, height: t)
                        ctx.fill(Path(ellipseIn: r).applying(skew), with: .color(col))
                    }
                    x += gap * 1.1
                    continue
                }
                let on = Self.map[ch] ?? []
                for seg in Seg.allCases {
                    let rect: CGRect
                    switch seg {
                    case .a: rect = CGRect(x: x + t * 0.7, y: 2, width: w - t * 1.4, height: t)
                    case .g: rect = CGRect(x: x + t * 0.7, y: 2 + h / 2 - t / 2, width: w - t * 1.4, height: t)
                    case .d: rect = CGRect(x: x + t * 0.7, y: 2 + h - t, width: w - t * 1.4, height: t)
                    case .f: rect = CGRect(x: x, y: 2 + t * 0.7, width: t, height: h / 2 - t * 1.1)
                    case .b: rect = CGRect(x: x + w - t, y: 2 + t * 0.7, width: t, height: h / 2 - t * 1.1)
                    case .e: rect = CGRect(x: x, y: 2 + h / 2 + t * 0.4, width: t, height: h / 2 - t * 1.1)
                    case .c: rect = CGRect(x: x + w - t, y: 2 + h / 2 + t * 0.4, width: t, height: h / 2 - t * 1.1)
                    }
                    let path = Path(roundedRect: rect, cornerRadius: t / 2).applying(skew)
                    ctx.fill(path, with: .color(on.contains(seg) ? col : col.opacity(0.08)))
                }
                x += w + gap
            }
        }
        .frame(width: totalWidth, height: digitHeight + 4)
        .shadow(color: col.opacity(0.85), radius: 2.5)
        .shadow(color: col.opacity(0.4), radius: 8)
    }
}

/// Engraved caption above an amber seven-segment window, e.g. DISK FREE [ 28.6 ] GB.
struct Readout: View {
    let caption: String
    let value: String
    let unit: String
    var digits = 4
    var digitHeight: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Engraved(caption, size: 9.5).fixedSize()
            HStack(spacing: 6) {
                GlassWindow(scanlines: false, cornerRadius: 2) {
                    SevenSegment(text: String(String(repeating: " ", count: max(0, digits - value.filter { $0 != "." }.count)) + value),
                                 digitHeight: digitHeight)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                }
                Engraved(unit, size: 10, tone: .muted).frame(width: 22, alignment: .leading)
            }
        }
    }
}

extension FS {
    /// A byte count as a seven-segment friendly number and unit, e.g. ("12.4", "GB").
    static func readout(_ bytes: Int64) -> (value: String, unit: String) {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var v = Double(max(bytes, 0)), i = 0
        while v >= 1000 && i < units.count - 1 { v /= 1000; i += 1 }
        let s = v >= 100 || i == 0 ? String(format: "%.0f", v) : String(format: "%.1f", v)
        return (s, units[i])
    }
}

// MARK: VU meter

struct VUMeter: View {
    let title: String
    let value: Double
    var caption: String = ""
    var width: CGFloat = 200
    var lit = true
    var showLabels = true

    var body: some View {
        VStack(spacing: 5) {
            face
                .frame(width: width, height: width * 0.55)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0x161617)))
                .padding(1)
                .background(RoundedRectangle(cornerRadius: 7).fill(LinearGradient(colors: [Color(hex: 0xd7d9dc), Color(hex: 0x7d8085)],
                                                                                 startPoint: .top, endPoint: .bottom)))
                .padding(1)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0x2b2c2f)))
                .shadow(color: Palette.current.groove, radius: 0, y: 1)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 3)
            if showLabels {
                HStack {
                    Engraved(title, size: 10.5)
                    Spacer()
                    Engraved(caption, size: 10, tone: .muted)
                }
                .frame(width: width + 8)
            }
        }
    }

    private var face: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let pivot = CGPoint(x: w / 2, y: h * 1.12)
            let radius = h * 0.9
            ZStack {
                Rectangle().fill(RadialGradient(colors: lit
                                                ? [Color(hex: 0xfbe7b4), Color(hex: 0xe9cc8a), Color(hex: 0xc9a868)]
                                                : [Color(hex: 0xb2a37b), Color(hex: 0x9f9170), Color(hex: 0x85785a)],
                                                center: .init(x: 0.5, y: 1.1), startRadius: 4, endRadius: w * 0.9))
                Canvas { ctx, _ in
                    for i in 0...20 {
                        let f = Double(i) / 20
                        let ang = Angle.degrees(-46 + f * 92).radians - .pi / 2
                        let long = i % 5 == 0
                        let r1 = radius - (long ? 10 : 6), r2 = radius
                        var p = Path()
                        p.move(to: CGPoint(x: pivot.x + cos(ang) * r1, y: pivot.y + sin(ang) * r1))
                        p.addLine(to: CGPoint(x: pivot.x + cos(ang) * r2, y: pivot.y + sin(ang) * r2))
                        ctx.stroke(p, with: .color(f > 0.79 ? Color(hex: 0xb4200c) : .black.opacity(0.8)), lineWidth: long ? 1.5 : 0.9)
                    }
                    var arc = Path()
                    arc.addArc(center: pivot, radius: radius, startAngle: .degrees(-136), endAngle: .degrees(-44), clockwise: false)
                    ctx.stroke(arc, with: .color(.black.opacity(0.7)), lineWidth: 0.9)
                    var red = Path()
                    red.addArc(center: pivot, radius: radius + 2, startAngle: .degrees(-62.5), endAngle: .degrees(-44), clockwise: false)
                    ctx.stroke(red, with: .color(Color(hex: 0xb4200c)), lineWidth: 3.5)
                }
                Text("VU")
                    .font(.custom("Futura-Bold", size: h * 0.17))
                    .foregroundStyle(.black.opacity(0.65))
                    .position(x: w / 2, y: h * 0.66)
                Rectangle()
                    .fill(Color(white: 0.08))
                    .frame(width: 1.4, height: radius + 4)
                    .position(x: pivot.x, y: pivot.y - (radius + 4) / 2)
                    .rotationEffect(.degrees(-46 + min(max(value, 0), 1) * 92), anchor: UnitPoint(x: pivot.x / w, y: pivot.y / h))
                    .animation(.interpolatingSpring(stiffness: 60, damping: 9), value: value)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 1, y: 1)
                LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .topLeading, endPoint: .center)
            }
        }
    }
}

// MARK: Knob & rotary switch

/// Chunky bakelite knob with a knurled skirt and a printed scale.
struct RackKnob<T: Hashable>: View {
    let title: String
    let options: [(label: String, value: T)]
    @Binding var selection: T
    var size: CGFloat = 64
    /// Which colour cap to use on the powder skin (0 blue, 1 yellow, 2 orange, 3 red, 4 green, 5 black).
    var colorIndex = 0

    @State private var dragStartIndex: Int?

    private var index: Int { options.firstIndex { $0.value == selection } ?? 0 }
    private func angle(_ i: Int) -> Double {
        options.count > 1 ? -135 + 270 * Double(i) / Double(options.count - 1) : 0
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                ForEach(options.indices, id: \.self) { i in
                    let a = Angle.degrees(angle(i) - 90).radians
                    Rectangle()
                        .fill(Rack.paint.opacity(0.85))
                        .frame(width: 1.6, height: 7)
                        .rotationEffect(.degrees(angle(i)))
                        .offset(x: cos(a) * size * 0.68, y: sin(a) * size * 0.68)
                    Button {
                        selection = options[i].value
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                    } label: {
                        Engraved(options[i].label, size: 9.5, tone: i == index ? .lit : .muted)
                            .fixedSize()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())   // a comfortable click target, not just the letters
                    }
                    .buttonStyle(.plain)
                    .offset(x: cos(a) * size * 1.0, y: sin(a) * size * 0.98)
                }
                KnobCap(size: size, cap: Palette.current.knobs.isEmpty ? nil
                                         : Palette.current.knobs[colorIndex % Palette.current.knobs.count])
                    .rotationEffect(.degrees(angle(index)))
                    .animation(.interpolatingSpring(stiffness: 180, damping: 14), value: index)
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { g in
                                if dragStartIndex == nil { dragStartIndex = index }
                                let steps = Int((-g.translation.height + g.translation.width) / 18)
                                let new = min(max((dragStartIndex ?? 0) + steps, 0), options.count - 1)
                                if new != index {
                                    selection = options[new].value
                                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                                }
                            }
                            .onEnded { _ in dragStartIndex = nil }
                    )
            }
            .frame(width: size * 2.5, height: size * 2.25)
            Engraved(title, size: 11)
        }
    }
}

struct KnobCap: View {
    var size: CGFloat
    /// Coloured cap (powder skin). nil = brown bakelite.
    var cap: Color? = nil
    var body: some View {
        ZStack {
            Circle().fill(.black.opacity(0.55)).blur(radius: 5).offset(x: 2, y: 6)
            // knurled skirt
            Circle().fill(AngularGradient(gradient: Gradient(stops: knurl), center: .center))
            Circle().fill(RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center,
                                         startRadius: size * 0.3, endRadius: size * 0.5))
            Circle().stroke(.black, lineWidth: 1)
            // top
            Circle()
                .fill(RadialGradient(colors: cap.map { [$0.mix(with: .white, by: 0.45), $0, $0.mix(with: .black, by: 0.18)] }
                                     ?? [Color(hex: 0x5e4134), Color(hex: 0x2c1c15), Color(hex: 0x130c08)],
                                     center: .init(x: 0.38, y: 0.3), startRadius: 0, endRadius: size * 0.42))
                .padding(size * (cap == nil ? 0.13 : 0.16))
                .shadow(color: .black.opacity(0.7), radius: 1.5, y: 1)
            Capsule().fill(Color(hex: 0xfbfbf8)).frame(width: cap == nil ? 3 : 3.6, height: size * 0.3).offset(y: -size * 0.22)
                .shadow(color: .black, radius: 0.5)
            Ellipse().fill(RadialGradient(colors: [.white.opacity(0.32), .clear], center: .center, startRadius: 0, endRadius: size * 0.2))
                .frame(width: size * 0.4, height: size * 0.28).offset(x: -size * 0.1, y: -size * 0.18)
        }
        .frame(width: size, height: size)
        .shadow(color: Palette.current.groove.opacity(0.6), radius: 0, y: 1)
        .contentShape(Circle())
    }

    private var knurl: [Gradient.Stop] {
        var stops: [Gradient.Stop] = []
        let n = 36
        let dark = cap == nil ? Color(hex: 0x1a110c) : Color(hex: 0x0c0c0e)
        let rib = cap == nil ? Color(hex: 0x43302a) : Color(hex: 0x3a3b40)
        for i in 0..<n {
            let f = Double(i) / Double(n), step = 1.0 / Double(n)
            stops.append(.init(color: dark, location: f))
            stops.append(.init(color: rib, location: f + step * 0.5))
            stops.append(.init(color: dark, location: f + step * 0.75))
        }
        stops.append(.init(color: dark, location: 1))
        return stops
    }
}

/// Detented rotary switch with a "chicken-head" pointer and a lamp at each position.
/// Drag to turn (it snaps to the nearest position), click a label to jump there,
/// or click the knob to step to the next position. `skipOnStep` positions are only reached on purpose.
struct ChickenHeadSwitch<T: Hashable>: View {
    let title: String
    let options: [(label: String, value: T)]
    @Binding var selection: T
    var sweep: Double = 150
    var skipOnStep: Set<T> = []

    @State private var dragAngle: Double?

    private let size = CGSize(width: 250, height: 160)
    private var center: CGPoint { CGPoint(x: size.width / 2, y: 104) }
    private var index: Int { options.firstIndex { $0.value == selection } ?? 0 }
    private func angle(_ i: Int) -> Double {
        options.count > 1 ? -sweep / 2 + sweep * Double(i) / Double(options.count - 1) : 0
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(options.indices, id: \.self) { i in
                    let a = Angle.degrees(angle(i) - 90).radians
                    // detent tick
                    Rectangle().fill(Rack.paint.opacity(0.85)).frame(width: 2, height: 8)
                        .rotationEffect(.degrees(angle(i)))
                        .position(x: center.x + cos(a) * 42, y: center.y + sin(a) * 42)
                    // lamp + label, a generous click target
                    Button {
                        select(i)
                    } label: {
                        VStack(spacing: 3) {
                            LED(on: i == index, size: 8)
                            Engraved(options[i].label, size: 10, tone: i == index ? .lit : .normal).fixedSize()
                        }
                        .padding(6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: center.x + cos(a) * 84, y: center.y + sin(a) * 76)
                }

                // the knob: skirt + chicken-head bar
                ZStack {
                    Circle().fill(AngularGradient(colors: [Color(hex: 0x1d1410), Color(hex: 0x3b2a22), Color(hex: 0x1d1410)],
                                                  center: .center))
                        .overlay(Circle().stroke(.black, lineWidth: 1))
                        .frame(width: 54, height: 54)
                        .shadow(color: .black.opacity(0.55), radius: 4, y: 4)
                    ChickenBar()
                        .rotationEffect(.degrees(dragAngle ?? angle(index)))
                        .animation(dragAngle == nil ? .interpolatingSpring(stiffness: 260, damping: 15) : nil,
                                   value: dragAngle ?? angle(index))
                }
                .frame(width: 76, height: 76)
                .contentShape(Circle())
                .gesture(turn)          // before .position, so the drag is measured in the knob's own 76×76 frame
                .help("Drag to turn, or click a position")
                .position(center)
            }
            .frame(width: size.width, height: size.height)
            Engraved(title, size: 11)
        }
    }

    /// Turning: follow the pointer around the centre, snap on release. A plain click steps once.
    private var turn: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { g in
                let travel = hypot(g.translation.width, g.translation.height)
                guard travel > 3 else { return }
                // knob frame is 76x76; its centre is (38, 38)
                let dx = g.location.x - 38, dy = g.location.y - 38
                var deg = atan2(dx, -dy) * 180 / .pi
                deg = min(max(deg, -sweep / 2 - 8), sweep / 2 + 8)
                dragAngle = deg
                let nearest = nearestIndex(deg)
                if nearest != index, !skipOnStep.contains(options[nearest].value) {
                    selection = options[nearest].value
                    detentFeedback()
                }
            }
            .onEnded { g in
                let travel = hypot(g.translation.width, g.translation.height)
                if travel <= 3 { step() } else {
                    let nearest = nearestIndex(dragAngle ?? angle(index))
                    if options[nearest].value != selection { select(nearest) }
                }
                dragAngle = nil
            }
    }

    private func nearestIndex(_ deg: Double) -> Int {
        options.indices.min { abs(angle($0) - deg) < abs(angle($1) - deg) } ?? index
    }

    private func step() {
        guard options.count > 1 else { return }
        var next = index
        for _ in 0..<options.count {
            next = (next + 1) % options.count
            if !skipOnStep.contains(options[next].value) { break }
        }
        select(next)
    }

    private func select(_ i: Int) {
        selection = options[i].value
        detentFeedback()
    }

    private func detentFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private struct ChickenBar: View {
        var body: some View {
            ZStack {
                UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 8, bottomTrailingRadius: 8, topTrailingRadius: 10)
                    .fill(LinearGradient(colors: [Color(hex: 0x120b08), Color(hex: 0x3e2b22), Color(hex: 0x2a1c15), Color(hex: 0x0f0907)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 19, height: 58)
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 3)
                Capsule().fill(Color(hex: 0xf2ede0)).frame(width: 3, height: 21).offset(y: -15)
            }
            .offset(y: -6)
        }
    }
}

// MARK: Modules & cards

/// A screwed-on rack module: textured card plate, screws in the corners, engraved title strip.
struct RackModule<Content: View, Accessory: View>: View {
    let title: String
    var subtitle: String? = nil
    var lamp: (Color, Bool, Bool)? = nil
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var content: () -> Content

    var body: some View {
        let p = Palette.current
        VStack(alignment: .leading, spacing: 0) {
            if !p.dark { TrimStripe() }
            HStack(spacing: 10) {
                if let lamp { LED(color: lamp.0, on: lamp.1, blink: lamp.2, size: 11) }
                VStack(alignment: .leading, spacing: 2) {
                    Engraved(title, size: 13)
                    if let subtitle { Engraved(subtitle, size: 9, tone: .muted) }
                }
                Spacer(minLength: 8)
                accessory()
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 10)
            content()
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(RackSurface(kind: .card))
        .overlay(alignment: .topLeading) { Screw(size: 9, angle: 30).padding(6) }
        .overlay(alignment: .topTrailing) { Screw(size: 9, angle: 75).padding(6) }
        .overlay(alignment: .bottomLeading) { Screw(size: 9, angle: 120).padding(6) }
        .overlay(alignment: .bottomTrailing) { Screw(size: 9, angle: 10).padding(6) }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.85), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 3).inset(by: 1).stroke(.white.opacity(p.dark ? 0.07 : 0.5), lineWidth: 1)
            .mask(VStack { Rectangle().frame(height: 2); Spacer() }))
        .shadow(color: .black.opacity(p.dark ? 0.6 : 0.3), radius: 4, y: 3)
    }
}

extension RackModule where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil, lamp: (Color, Bool, Bool)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.subtitle = subtitle; self.lamp = lamp
        self.accessory = { EmptyView() }
        self.content = content
    }
}

/// A strip of masking tape with a marker note on it.
struct TapeLabel: View {
    let text: String
    var size: CGFloat = 15
    var tilt: Double = -1.2

    var body: some View {
        Text(text)
            .font(Rack.marker(size))
            .foregroundStyle(Rack.marker)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(
                TapeShape()
                    .fill(LinearGradient(colors: [Rack.tape, Rack.tape.mix(with: Color(hex: 0xd8c79a), by: 0.5)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(TapeShape().fill(.white.opacity(0.12)).blendMode(.overlay))
                    .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
            )
            .rotationEffect(.degrees(tilt))
    }

    /// Tape with torn ends.
    struct TapeShape: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            var rng = SeededRandom(seed: UInt64(r.width.rounded()))
            p.move(to: CGPoint(x: r.minX + 2, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - 2, y: r.minY))
            var y = r.minY
            while y < r.maxY {
                y = min(r.maxY, y + 3)
                p.addLine(to: CGPoint(x: r.maxX - rng.next() * 3, y: y))
            }
            p.addLine(to: CGPoint(x: r.minX + 2, y: r.maxY))
            y = r.maxY
            while y > r.minY {
                y = max(r.minY, y - 3)
                p.addLine(to: CGPoint(x: r.minX + rng.next() * 3, y: y))
            }
            p.closeSubpath()
            return p
        }
    }
}

/// Cream operator's card held on with two strips of tape.
struct CreamCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title).font(Rack.marker(26).weight(.bold)).foregroundStyle(Rack.cardInk)
            }
            content()
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(hex: 0xf3ecda), Color(hex: 0xe6dcc3)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(alignment: .topLeading) {
            Rectangle().fill(Rack.tape.opacity(0.85)).frame(width: 74, height: 20).rotationEffect(.degrees(-3))
                .shadow(color: .black.opacity(0.2), radius: 1).offset(x: 34, y: -8)
        }
        .overlay(alignment: .topTrailing) {
            Rectangle().fill(Rack.tape.opacity(0.85)).frame(width: 74, height: 20).rotationEffect(.degrees(2.5))
                .shadow(color: .black.opacity(0.2), radius: 1).offset(x: -34, y: -8)
        }
        .shadow(color: .black.opacity(0.45), radius: 5, y: 3)
        .environment(\.colorScheme, .light)
    }
}

struct CardHeading: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(text.uppercased()).font(Rack.engrave(12.5)).tracking(2).foregroundStyle(Rack.cardRed)
            Rectangle().fill(Rack.cardRed.opacity(0.45)).frame(height: 2)
        }
    }
}

// MARK: Toggles for lists

struct LEDToggleStyle: ToggleStyle {
    var color: Color? = nil
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                LED(color: color ?? Rack.lit, on: configuration.isOn, size: 12)
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct CardCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Rectangle().strokeBorder(Rack.cardInk.opacity(0.85), lineWidth: 1.5).frame(width: 17, height: 17)
                    if configuration.isOn {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Rack.cardRed)
                    }
                }
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Module helpers used by the screens

struct ModuleHeader<Controls: View>: View {
    let title: String
    let status: String
    var led: (Color, Bool, Bool)? = nil
    @ViewBuilder var controls: () -> Controls

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let led { LED(color: led.0, on: led.1, blink: led.2, size: 14) }
            VStack(alignment: .leading, spacing: 3) {
                Engraved(title, size: 22)
                Engraved(status, size: 10, tone: .muted)
            }
            Spacer()
            controls()
        }
    }
}

struct AmberRow: View {
    let name: String
    var detail: String? = nil
    var value: String? = nil
    var valueColor: Color? = nil

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                AmberText(name, size: 12, weight: .semibold)
                if let detail { AmberText(detail, size: 10).opacity(0.6) }
            }
            Spacer(minLength: 10)
            if let value { AmberText(value, size: 12, weight: .bold, color: valueColor) }
        }
        .padding(.vertical, 3)
    }
}

struct AmberEmpty: View {
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            AmberText(title, size: 15, weight: .bold)
            Text(message)
                .font(Rack.mono(11))
                .foregroundStyle(Rack.amber.opacity(0.65))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}

/// Amber status strip + action buttons, at the foot of each screen.
struct StatusStrip<Actions: View>: View {
    let message: String
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        HStack(spacing: 12) {
            GlassWindow(scanlines: true, cornerRadius: 2) {
                Text(message)
                    .font(Rack.condensed(15))
                    .tracking(0.6)
                    .foregroundStyle(Rack.amber)
                    .shadow(color: Rack.amber.opacity(0.7), radius: 4)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
            }
            actions()
        }
    }
}

// MARK: Power button

/// Big round push button in a chrome bezel; the cap glows in the lamp colour while active.
struct BigRoundButton: View {
    let symbol: String
    var active: Bool
    var size: CGFloat = 120
    let action: () -> Void

    var body: some View {
        let p = Palette.current
        Button(action: action) {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(hex: 0x3a3b3f), Color(hex: 0x0c0c0d)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 5)
                Circle().strokeBorder(LinearGradient(colors: [Color(hex: 0xd7d9dc), Color(hex: 0x6d7075)], startPoint: .top, endPoint: .bottom),
                                      lineWidth: 2).padding(5)
                Circle().fill(Color(hex: 0x070708)).padding(9)
                Circle()
                    .fill(RadialGradient(colors: active ? [p.litHi, p.litMid, p.litLo.mix(with: .black, by: 0.35)]
                                                        : p.powder ? [Color(hex: 0x3a3b40), Color(hex: 0x141416), Color(hex: 0x050506)]
                                                        : [Color(hex: 0x5e4134), Color(hex: 0x2c1c15), Color(hex: 0x130c08)],
                                         center: .init(x: 0.42, y: 0.32), startRadius: 0, endRadius: size * 0.4))
                    .padding(size * 0.15)
                    .shadow(color: active ? p.glow.opacity(0.85) : .clear, radius: 20)
                Image(systemName: symbol)
                    .font(.system(size: size * 0.23, weight: .semibold))
                    .foregroundStyle(active ? p.litInk.opacity(0.85) : Color(hex: 0xf2ede0).opacity(0.5))
                Ellipse().fill(RadialGradient(colors: [.white.opacity(0.28), .clear], center: .center, startRadius: 0, endRadius: size * 0.2))
                    .frame(width: size * 0.42, height: size * 0.24).offset(x: -size * 0.08, y: -size * 0.2)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
}
