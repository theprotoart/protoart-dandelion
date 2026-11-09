import SwiftUI

/// Set-up Card: faceplate, colour theme and cleaning safety. Everything takes effect at once.
struct SetupCard: View {
    @EnvironmentObject private var look: Look
    @EnvironmentObject private var junk: JunkModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CreamCard(title: "Set-up Card") {
            Text("Fill in the boxes. Everything takes effect at once.")
                .font(Rack.serif(14)).foregroundStyle(Rack.cardInk)

            CardHeading(text: "Faceplate").padding(.top, 6)
            RackSelector(options: Faceplate.allCases.map {
                             (label: look.skin == .powder && $0 != .system ? ($0 == .light ? "Light · Blue" : "Dark · Orange") : $0.title,
                              value: $0)
                         },
                         selection: $look.faceplate, height: 28, fontSize: 11)
            Text(look.skin == .powder
                 ? "Light is cornflower-blue powder coat; Dark is burnt orange. Match macOS follows your system."
                 : "Light is brushed aluminium with painted trim; Dark is black anodised. Match macOS follows your system.")
                .font(Rack.serif(12.5)).foregroundStyle(Rack.cardInk.opacity(0.75))

            CardHeading(text: "Colour theme").padding(.top, 6)
            HStack(spacing: 8) {
                ForEach(Skin.allCases) { skin in
                    Button {
                        look.skin = skin
                    } label: {
                        HStack(spacing: 7) {
                            swatch(skin)
                            Text(skin.title)
                        }
                    }
                    .buttonStyle(RackButtonStyle(kind: look.skin == skin ? .primary : .cap, height: 30, fontSize: 11.5))
                }
            }
            Text("\(look.skin.title): \(look.skin.blurb). Whatever is switched on lights up in the theme's lamp colour; what's off stays dark.")
                .font(Rack.serif(12.5)).foregroundStyle(Rack.cardInk.opacity(0.75))

            CardHeading(text: "Cleaning").padding(.top, 6)
            Toggle(isOn: $junk.moveToTrash) {
                Text("Move cleaned items to the Trash, so they can be put back (the SAFE lever)")
                    .font(Rack.serif(14)).foregroundStyle(Rack.cardInk)
            }
            .toggleStyle(CardCheckboxStyle())

            Spacer(minLength: 8)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(RackButtonStyle(kind: .primary, height: 32, fontSize: 12))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 620, height: 560)
        .padding(14)
        .padding(.top, 14)
        .background(RackSurface().ignoresSafeArea())
        .ignoresSafeArea()
        .id(look.signature)
    }

    private func swatch(_ skin: Skin) -> some View {
        let colors: [Color] = {
            switch skin {
            case .powder: return [Color(hex: 0x5a8ce6), Color(hex: 0xc45822), Color(hex: 0xf3df45)]
            case .amber: return [Color(hex: 0x2a2b2e), Color(hex: 0xffb94a)]
            case .cream: return [Color(hex: 0xd8ccb3), Color(hex: 0xffd36b), Color(hex: 0x9c3326)]
            case .slate: return [Color(hex: 0x5d6b78), Color(hex: 0xf1e2b4)]
            case .ember: return [Color(hex: 0x1a1414), Color(hex: 0xff6232)]
            }
        }()
        return HStack(spacing: 0) {
            ForEach(colors.indices, id: \.self) { i in
                Rectangle().fill(colors[i]).frame(width: i == 0 ? 13 : 5)
            }
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(.black.opacity(0.7), lineWidth: 1))
    }
}

/// Operator's Card: what each control does.
struct OperatorsCard: View {
    @Environment(\.dismiss) private var dismiss

    private let rows: [(String, String)] = [
        ("Smart Scan", "Press the round button. Dandelion checks junk, leftovers of removed apps and broken startup items in one go."),
        ("Cleanup", "Every kind of junk on its own row. A lit lamp means it will be cleaned; press a row's arrow to see each item."),
        ("Uninstall", "Removes an app together with the files it keeps in your Library. LEFTOVERS finds what deleted apps left behind."),
        ("Space Lens", "Turn the LOCATION switch, then press folders to dig in. Right-click anything to reveal or trash it."),
        ("Large Files", "Turn the knobs for size and age, press SCAN, light the lamps of files to remove."),
        ("Maintenance", "Quick fixes: DNS, memory, snapshots, Spotlight, Launch Services, Quick Look, Dock. A lock means macOS asks for your password."),
        ("Login Items", "Everything that starts by itself. A red lamp means its program is gone."),
        ("SAFE lever", "Up: cleaned items go to the Trash. Down: they are deleted at once."),
        ("Lamps", "POWER is on while Dandelion runs, BUSY blinks while it works, FAULT lights if something couldn't be removed.")
    ]

    var body: some View {
        CreamCard(title: "Operator's Card") {
            Text("ProtoArt Dandelion · Model PD-1 · Mac cleaning unit. Native, about 4 MB, no network connections, nothing uploaded.")
                .font(Rack.serif(13)).foregroundStyle(Rack.cardInk.opacity(0.8))
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(rows, id: \.0) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            CardHeading(text: row.0)
                            Text(row.1).font(Rack.serif(13.5)).foregroundStyle(Rack.cardInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.trailing, 6)
            }
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(RackButtonStyle(kind: .primary, height: 32, fontSize: 12))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 600, height: 620)
        .padding(14)
        .padding(.top, 14)
        .background(RackSurface().ignoresSafeArea())
        .ignoresSafeArea()
    }
}
