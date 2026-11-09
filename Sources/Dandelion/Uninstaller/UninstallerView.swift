import SwiftUI

struct UninstallerView: View {
    @EnvironmentObject private var model: UninstallerModel
    @State private var confirm = false

    var body: some View {
        RackModule(title: "Uninstaller",
                   subtitle: model.mode == .apps
                       ? "\(model.apps.count) apps · removes each app with its support files"
                       : "Support folders left behind by apps you already deleted",
                   lamp: (Rack.lit, model.isLoading || model.isScanningOrphans, true),
                   accessory: {
                       HStack(spacing: 14) {
                           RackSelector(options: [(label: "Apps", value: UninstallerModel.Mode.apps),
                                                  (label: "Leftovers", value: .orphans)],
                                        selection: $model.mode)
                           Button("Refresh") {
                               Task { if model.mode == .apps { await model.loadApps() } else { await model.scanOrphans() } }
                           }
                           .buttonStyle(RackButtonStyle(kind: .cap, height: 32))
                           .disabled(model.isLoading || model.isScanningOrphans)
                       }
                   }) {
            if model.mode == .apps {
                HStack(spacing: 16) {
                    appList.frame(width: 360)
                    detail
                }
            } else {
                OrphansView()
            }
        }
        .task { if model.apps.isEmpty { await model.loadApps() } }
        .alert("Uninstall \(model.selectedApp?.name ?? "app")?", isPresented: $confirm) {
            Button("Uninstall", role: .destructive) { Task { await model.uninstall() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The app and \(model.selectedLeftovers.count) related item(s) will be moved to the Trash.")
        }
    }

    private var appList: some View {
        GlassWindow {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Rack.amber.opacity(0.6))
                    TextField("", text: $model.search, prompt: Text("SEARCH").foregroundColor(Rack.amber.opacity(0.35)))
                        .textFieldStyle(.plain)
                        .font(Rack.mono(12))
                        .foregroundStyle(Rack.amber)
                }
                .padding(10)
                Rectangle().fill(Rack.amber.opacity(0.15)).frame(height: 1)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.filteredApps) { app in
                            let selected = model.selectedAppID == app.url
                            Button {
                                model.select(app.url)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(nsImage: FS.icon(for: app.url)).resizable().frame(width: 22, height: 22)
                                    AmberText(app.name, size: 12, weight: selected ? .bold : .regular)
                                    Spacer()
                                    AmberText(app.size > 0 ? FS.format(app.size) : "…", size: 10).opacity(0.6)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selected ? Rack.amber.opacity(0.14) : .clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let app = model.selectedApp {
            VStack(spacing: 14) {
                CreamCard {
                    HStack(spacing: 14) {
                        Image(nsImage: FS.icon(for: app.url)).resizable().frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.name).font(.custom("Marker Felt", size: 26).weight(.bold)).foregroundStyle(Rack.cardInk)
                            Text([app.version.map { "Version \($0)" }, app.bundleID].compactMap { $0 }.joined(separator: " · "))
                                .font(Rack.serif(12)).foregroundStyle(Rack.cardInk.opacity(0.75))
                        }
                    }
                    Divider().overlay(Rack.cardInk.opacity(0.3))
                    CardHeading(text: "App bundle")
                    cardLine(app.url.path, FS.format(app.size))
                    CardHeading(text: "Related files in your Library").padding(.top, 6)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 7) {
                            if model.isFindingLeftovers {
                                Text("Looking for leftovers…").font(Rack.serif(13)).foregroundStyle(Rack.cardInk.opacity(0.7))
                            } else if model.leftovers.isEmpty {
                                Text("No leftover files found.").font(Rack.serif(13)).foregroundStyle(Rack.cardInk.opacity(0.7))
                            }
                            ForEach(model.leftovers) { item in
                                Toggle(isOn: Binding(
                                    get: { model.selectedLeftovers.contains(item.url) },
                                    set: { on in
                                        if on { model.selectedLeftovers.insert(item.url) } else { model.selectedLeftovers.remove(item.url) }
                                    })) {
                                    cardLine("~/Library/\(item.location)/\(item.url.lastPathComponent)", FS.format(item.size))
                                }
                                .toggleStyle(CardCheckboxStyle())
                                .contextMenu { Button("Show in Finder") { FS.reveal([item.url]) } }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                StatusStrip(message: model.status ?? "Everything goes to the Trash, so you can put it back.") {
                    if model.needsPermissions { PermissionButtons() }
                    Button("Uninstall · \(FS.format(model.totalRemovalSize))") { confirm = true }
                        .buttonStyle(RackButtonStyle(kind: .danger, height: 40, fontSize: 14))
                        .disabled(model.isFindingLeftovers)
                }
            }
        } else {
            CreamCard(title: "Operator's Card") {
                Text("Pick an app on the left. Dandelion shows its size and every support file it keeps in your Library — preferences, caches, containers, saved state, logs and launch agents.")
                    .font(Rack.serif(14)).foregroundStyle(Rack.cardInk)
                Text("Tick or untick each file, then press UNINSTALL. Everything goes to the Trash. Apple's own apps are never listed.")
                    .font(Rack.serif(14)).foregroundStyle(Rack.cardInk)
                if let status = model.status {
                    Text(status).font(Rack.serif(13)).foregroundStyle(Rack.cardRed)
                }
            }
        }
    }

    private func cardLine(_ text: String, _ value: String) -> some View {
        HStack {
            Text(text).font(Rack.serif(12.5)).foregroundStyle(Rack.cardInk).lineLimit(1).truncationMode(.middle)
            Spacer()
            Text(value).font(Rack.serif(12.5)).foregroundStyle(Rack.cardInk.opacity(0.7))
        }
    }
}

struct OrphansView: View {
    @EnvironmentObject private var model: UninstallerModel
    @State private var confirm = false

    var body: some View {
        VStack(spacing: 16) {
            GlassWindow {
                if !model.hasScannedOrphans && !model.isScanningOrphans {
                    AmberEmpty(title: "LEFTOVERS OF REMOVED APPS",
                               message: "Apps dragged to the Trash leave their containers and saved state behind. Dandelion only lists folders named after an app that is no longer installed. Nothing is selected for you.")
                } else if model.orphans.isEmpty && !model.isScanningOrphans {
                    AmberEmpty(title: "ALL TIDY", message: "No leftovers from removed apps were found.")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(model.orphans) { item in
                                Toggle(isOn: Binding(
                                    get: { model.selectedOrphans.contains(item.url) },
                                    set: { on in
                                        if on { model.selectedOrphans.insert(item.url) } else { model.selectedOrphans.remove(item.url) }
                                    })) {
                                    AmberRow(name: item.url.lastPathComponent, detail: "~/Library/\(item.location)",
                                             value: FS.format(item.size))
                                }
                                .toggleStyle(LEDToggleStyle())
                                .contextMenu { Button("Show in Finder") { FS.reveal([item.url]) } }
                            }
                        }
                        .padding(14)
                    }
                }
            }
            StatusStrip(message: model.status ?? (model.hasScannedOrphans
                                                  ? "\(model.orphans.count) leftovers, \(FS.format(model.orphanTotal)) total. Light the ones to remove."
                                                  : "Scanning…")) {
                if model.needsPermissions { PermissionButtons() }
                Button("Remove · \(FS.format(model.selectedOrphanSize))") { confirm = true }
                    .buttonStyle(RackButtonStyle(kind: .primary, height: 40, fontSize: 14))
                    .disabled(model.selectedOrphans.isEmpty)
            }
        }
        .task { if !model.hasScannedOrphans { await model.scanOrphans() } }
        .alert("Move \(model.selectedOrphans.count) leftovers to the Trash?", isPresented: $confirm) {
            Button("Move to Trash", role: .destructive) { Task { await model.removeOrphans() } }
            Button("Cancel", role: .cancel) {}
        }
    }
}

/// Shortcuts to the two System Settings switches an uninstaller needs. macOS has no pop-up for these.
struct PermissionButtons: View {
    var body: some View {
        HStack(spacing: 6) {
            Button("Full Disk Access") { FS.openFullDiskAccessSettings() }
                .buttonStyle(RackButtonStyle(kind: .ghost, height: 40, fontSize: 11))
                .help("Opens System Settings and shows Dandelion in Finder: drag it into the list and switch it on.")
            Button("App Management") { FS.openAppManagementSettings() }
                .buttonStyle(RackButtonStyle(kind: .ghost, height: 40, fontSize: 11))
                .help("Lets Dandelion remove other apps. Click +, choose ProtoArt Dandelion, switch it on.")
        }
    }
}
