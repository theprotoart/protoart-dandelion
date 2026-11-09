import SwiftUI

struct LoginItemsView: View {
    @EnvironmentObject private var model: LoginItemsModel
    @State private var pendingRemoval: LaunchItem?

    private var brokenCount: Int { model.items.filter(\.programMissing).count }

    var body: some View {
        RackModule(title: "Login Items",
                   subtitle: "\(model.items.count) background helpers · \(brokenCount) broken",
                   lamp: (Rack.red, brokenCount > 0, false),
                   accessory: {
                       HStack(spacing: 8) {
                           Button("System Settings") { model.openSystemLoginItems() }
                               .buttonStyle(RackButtonStyle(kind: .ghost, height: 30, fontSize: 11))
                           Button("Refresh") { Task { await model.load() } }
                               .buttonStyle(RackButtonStyle(kind: .cap, height: 30, fontSize: 11))
                       }
                   }) {
            VStack(spacing: 12) {
                GlassWindow {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(LaunchItem.Scope.allCases, id: \.self) { scope in
                                let list = model.items(in: scope)
                                AmberText("▸ \(scope.rawValue.uppercased()) (\(list.count))", size: 11, weight: .bold)
                                    .opacity(0.75)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                                if list.isEmpty {
                                    AmberText("  none", size: 11).opacity(0.4)
                                }
                                ForEach(list) { item in row(item) }
                            }
                        }
                        .padding(14)
                    }
                }
                StatusStrip(message: model.status ?? "Green lamp: starts at login. Red: program missing. Flip a switch to turn your own helpers off.") {
                    EmptyView()
                }
            }
        }
        .task { if model.items.isEmpty { await model.load() } }
        .alert("Remove \(pendingRemoval?.label ?? "")?",
               isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } })) {
            Button("Remove", role: .destructive) {
                if let item = pendingRemoval { Task { await model.remove(item) } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Dandelion will stop this agent and move its file to the Trash. The app it belongs to may add it back the next time it runs.")
        }
    }

    private func row(_ item: LaunchItem) -> some View {
        HStack(spacing: 12) {
            LED(color: item.programMissing ? Rack.red : Rack.green,
                on: item.programMissing || (!item.disabled && (item.runAtLoad || item.keepAlive)), size: 12)
            if let app = item.owningApp, FS.exists(app) {
                Image(nsImage: FS.icon(for: app)).resizable().frame(width: 18, height: 18)
            }
            VStack(alignment: .leading, spacing: 1) {
                AmberText(item.label, size: 12, weight: .semibold)
                AmberText(item.program ?? "—", size: 10).opacity(0.55)
            }
            Spacer(minLength: 10)
            AmberText([item.runAtLoad ? "AT LOGIN" : nil, item.keepAlive ? "ALWAYS ON" : nil,
                       item.programMissing ? "MISSING" : nil].compactMap { $0 }.joined(separator: " · "),
                      size: 10, color: item.programMissing ? Rack.red : Rack.amber)
                .opacity(0.8)
            if item.removable {
                Button {
                    Task { await model.setEnabled(item, item.disabled) }
                } label: {
                    HStack(spacing: 4) {
                        BatHandle(isOn: !item.disabled, scale: 0.6)
                        AmberText(item.disabled ? "OFF" : "ON", size: 10, weight: .bold,
                                  color: item.disabled ? Rack.amber.opacity(0.5) : nil)
                            .frame(width: 26, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(item.disabled ? "Switch back on" : "Switch off (reversible, nothing is deleted)")
            }
            Button("Show") { FS.reveal([item.url]) }
                .buttonStyle(RackButtonStyle(kind: .cap, height: 22, fontSize: 10))
            if item.removable {
                Button("Remove") { pendingRemoval = item }
                    .buttonStyle(RackButtonStyle(kind: .dangerText, height: 22, fontSize: 10))
            }
        }
        .padding(.vertical, 3)
    }
}
