import SwiftUI
import Charts

struct SpaceLensView: View {
    @EnvironmentObject private var model: SpaceLensModel
    @State private var pendingTrash: LensNode?
    @State private var confirmRemove = false

    private enum Root: Hashable { case home, disk, apps, other }

    private var root: Binding<Root> {
        Binding(
            get: {
                switch model.path.first?.path {
                case FS.home.path: return .home
                case "/": return .disk
                case "/Applications": return .apps
                case nil: return .home
                default: return .other
                }
            },
            set: { new in
                switch new {
                case .home: model.setRoot(FS.home)
                case .disk: model.setRoot(URL(fileURLWithPath: "/"))
                case .apps: model.setRoot(URL(fileURLWithPath: "/Applications"))
                case .other: model.chooseFolder()
                }
            })
    }

    private var palette: [Color] {
        let p = Palette.current
        return [p.litMid, p.litLo, Color(hex: 0x7fb069), Color(hex: 0x6fa8dc), Color(hex: 0xd8664a),
                Color(hex: 0xe6d8a8), Color(hex: 0xa98bd8)]
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 14) {
                RackModule(title: "Location", subtitle: "Turn to choose where to look") {
                    ChickenHeadSwitch(title: "Root",
                                      options: [(label: "Home", value: Root.home), (label: "Disk", value: .disk),
                                                (label: "Apps", value: .apps), (label: "Other…", value: .other)],
                                      selection: root, skipOnStep: [.other])
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 250)

                RackModule(title: "Map", subtitle: model.current?.lastPathComponent ?? "") {
                    GlassWindow(scanlines: false) {
                        donut.padding(16)
                    }
                }
            }
            .frame(width: 320)

            RackModule(title: "Space Lens",
                       subtitle: model.isMeasuring ? "Measuring…" : "\(model.nodes.count) items · \(FS.format(model.total))",
                       lamp: (Rack.lit, model.isMeasuring, true),
                       accessory: {
                           HStack(spacing: 8) {
                               Button("Up") { model.goTo(max(model.path.count - 2, 0)) }
                                   .buttonStyle(RackButtonStyle(kind: .cap, height: 30))
                                   .disabled(model.path.count < 2)
                               Button("Rescan") { model.rescan() }
                                   .buttonStyle(RackButtonStyle(kind: .cap, height: 30))
                           }
                       }) {
                VStack(spacing: 10) {
                    breadcrumb
                    GlassWindow { list }
                    StatusStrip(message: model.status ?? (model.selection.isEmpty
                                ? "Press a folder to open it. Light a lamp to select items to remove."
                                : "\(model.selection.count) selected · \(FS.format(model.selectedSize))")) {
                        Button("Reveal") { FS.reveal(Array(model.selection)) }
                            .buttonStyle(RackButtonStyle(kind: .cap, height: 40, fontSize: 13))
                            .disabled(model.selection.isEmpty)
                        Button("Remove \(FS.format(model.selectedSize))") { confirmRemove = true }
                            .buttonStyle(RackButtonStyle(kind: .primary, height: 40, fontSize: 14))
                            .disabled(model.selection.isEmpty)
                    }
                }
            }
        }
        .onAppear { model.startIfNeeded() }
        .alert("Move \(model.selection.count) items to the Trash?", isPresented: $confirmRemove) {
            Button("Move to Trash", role: .destructive) { Task { await model.trashSelected() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(FS.format(model.selectedSize)) will go to the Trash, so you can still put it back.")
        }
        .alert("Move “\(pendingTrash?.name ?? "")” to the Trash?",
               isPresented: Binding(get: { pendingTrash != nil }, set: { if !$0 { pendingTrash = nil } })) {
            Button("Move to Trash", role: .destructive) {
                if let node = pendingTrash { Task { await model.trash(node) } }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var breadcrumb: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(model.path.enumerated()), id: \.offset) { index, url in
                    if index > 0 {
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Rack.muted)
                    }
                    Button { model.goTo(index) } label: {
                        Engraved(url.path == "/" ? "Macintosh HD" : url.lastPathComponent, size: 12,
                                 tone: index == model.path.count - 1 ? .lit : .muted)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private struct Slice: Identifiable {
        let id: String
        let name: String
        let size: Int64
        let color: Color
    }

    private var slices: [Slice] {
        let sized = model.nodes.filter { ($0.size ?? 0) > 0 }
        let colors = palette
        var result: [Slice] = []
        for (i, node) in sized.prefix(7).enumerated() {
            result.append(Slice(id: node.url.path, name: node.name, size: node.size ?? 0, color: colors[i]))
        }
        let rest = sized.dropFirst(7).compactMap(\.size).reduce(0, +)
        if rest > 0 { result.append(Slice(id: "~other", name: "Everything else", size: rest, color: Rack.amber.opacity(0.18))) }
        return result
    }

    private var donut: some View {
        VStack(spacing: 14) {
            ZStack {
                Chart(slices) { slice in
                    SectorMark(angle: .value("Size", slice.size), innerRadius: .ratio(0.62), angularInset: 1.5)
                        .cornerRadius(2)
                        .foregroundStyle(slice.color)
                }
                .chartLegend(.hidden)
                .shadow(color: Rack.amber.opacity(0.35), radius: 6)
                VStack(spacing: 3) {
                    SevenSegment(text: FS.readout(model.total).value, digitHeight: 18)
                    AmberText(FS.readout(model.total).unit, size: 10).opacity(0.8)
                }
            }
            .frame(height: 170)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(slices) { slice in
                    HStack(spacing: 8) {
                        Circle().fill(slice.color).frame(width: 7, height: 7)
                        AmberText(slice.name, size: 10)
                        Spacer()
                        AmberText(FS.format(slice.size), size: 10).opacity(0.7)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(model.nodes) { node in
                    HStack(spacing: 0) {
                    Button { model.toggle(node) } label: {
                        LED(on: model.selection.contains(node.url), size: 12)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                    .help("Select for removal")
                    Button {
                        if node.isDirectory { model.open(node) } else { model.toggle(node) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(nsImage: FS.icon(for: node.url)).resizable().frame(width: 18, height: 18)
                            VStack(alignment: .leading, spacing: 3) {
                                AmberText(node.name, size: 12, weight: .semibold)
                                GeometryReader { geo in
                                    let fraction = model.largest > 0 ? Double(node.size ?? 0) / Double(model.largest) : 0
                                    Capsule()
                                        .fill(Rack.amber.opacity(0.8))
                                        .shadow(color: Rack.amber.opacity(0.6), radius: 3)
                                        .frame(width: max(2, geo.size.width * fraction))
                                }
                                .frame(height: 3)
                            }
                            Spacer(minLength: 12)
                            AmberText(node.size.map(FS.format) ?? "…", size: 12, weight: .bold)
                                .frame(width: 84, alignment: .trailing)
                            Image(systemName: "chevron.right").font(.caption)
                                .foregroundStyle(Rack.amber.opacity(node.isDirectory ? 0.6 : 0))
                        }
                        .padding(.trailing, 14)
                        .padding(.leading, 4)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    }
                    .contextMenu {
                        Button("Show in Finder") { FS.reveal([node.url]) }
                        Button("Move to Trash…", role: .destructive) { pendingTrash = node }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}
