import SwiftUI

struct JunkView: View {
    @EnvironmentObject private var model: JunkModel
    @State private var confirmClean = false
    @State private var expanded: Set<String> = []

    var body: some View {
        RackModule(title: "Cleanup",
                   subtitle: model.isScanning ? "Scanning…"
                             : model.hasScanned ? "\(FS.format(model.totalFound)) found in \(model.allItems.count) items"
                             : "Caches · logs · developer data · Mail attachments · installers · Trash",
                   lamp: (Rack.lit, model.isScanning || model.isCleaning, true),
                   accessory: {
                       HStack(spacing: 14) {
                           Engraved("Disposal", size: 10, tone: .muted)
                           RackSelector(options: [(label: "To Trash", value: true), (label: "Delete", value: false)],
                                        selection: $model.moveToTrash)
                           Button(model.hasScanned ? "Rescan" : "Scan") { Task { await model.scan() } }
                               .buttonStyle(RackButtonStyle(kind: model.hasScanned ? .cap : .primary, height: 32))
                               .disabled(model.isScanning || model.isCleaning)
                       }
                   }) {
            VStack(spacing: 12) {
                GlassWindow {
                    if !model.hasScanned && !model.isScanning {
                        AmberEmpty(title: "FIND JUNK",
                                   message: "Dandelion checks caches, logs, developer data, Mail attachments, old installers and your Trash. Nothing is removed until you review it and press CLEAN.")
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(model.categories) { category in
                                    categoryRow(category)
                                    if expanded.contains(category.id) {
                                        ForEach(model.items[category.id] ?? []) { item in itemRow(item) }
                                    }
                                }
                            }
                            .padding(14)
                        }
                    }
                }
                StatusStrip(message: model.needsFullDiskAccess
                            ? "Trash & Mail are hidden by macOS. Grant Full Disk Access to clean them."
                            : model.status ?? "Lit lamps are cleaned. Press a row's arrow to see each item.") {
                    if model.needsFullDiskAccess {
                        Button("Grant Access") { FS.openFullDiskAccessSettings() }
                            .buttonStyle(RackButtonStyle(kind: .ghost, height: 40, fontSize: 12))
                    }
                    Button("Clean \(FS.format(model.selectedSize))") { confirmClean = true }
                        .buttonStyle(RackButtonStyle(kind: .primary, height: 40, fontSize: 14))
                        .disabled(model.selected.isEmpty || model.isScanning || model.isCleaning)
                }
            }
        }
        .alert("Clean \(model.selected.count) items?", isPresented: $confirmClean) {
            Button("Clean", role: .destructive) { Task { await model.clean() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(model.moveToTrash
                 ? "The selected items will be moved to the Trash. Items already in the Trash are deleted permanently."
                 : "The selected items will be deleted permanently. This can't be undone.")
        }
    }

    private func categoryRow(_ category: JunkCategory) -> some View {
        let list = model.items[category.id] ?? []
        let open = expanded.contains(category.id)
        return HStack(spacing: 10) {
            Toggle(isOn: Binding(get: { model.isSelected(category) },
                                 set: { model.setSelected(category, $0) })) {
                AmberRow(name: category.name.uppercased(), detail: category.detail, value: FS.format(model.size(of: category)))
            }
            .toggleStyle(LEDToggleStyle())
            .disabled(list.isEmpty)
            Button {
                if open { expanded.remove(category.id) } else { expanded.insert(category.id) }
            } label: {
                Image(systemName: open ? "chevron.down" : "chevron.right")
                    .foregroundStyle(Rack.amber.opacity(list.isEmpty ? 0.2 : 0.7))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(list.isEmpty)
        }
        .padding(.vertical, 4)
    }

    private func itemRow(_ item: JunkItem) -> some View {
        Toggle(isOn: Binding(get: { model.selected.contains(item.url) },
                             set: { model.toggle(item.url, $0) })) {
            HStack {
                AmberText(item.url.lastPathComponent, size: 11).opacity(0.85)
                if item.inUse {
                    AmberText("IN USE", size: 9, weight: .bold, color: Rack.red).opacity(0.85)
                        .help("This app is running, so its cache is left unticked. You can still tick it.")
                }
                Spacer()
                AmberText(FS.format(item.size), size: 11).opacity(0.7)
            }
        }
        .toggleStyle(LEDToggleStyle())
        .padding(.leading, 26)
        .padding(.trailing, 34)
        .contextMenu { Button("Show in Finder") { FS.reveal([item.url]) } }
    }
}
