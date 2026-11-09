import SwiftUI

struct LargeFilesView: View {
    @EnvironmentObject private var model: LargeFilesModel
    @State private var confirm = false

    private let sizeOptions: [(label: String, value: Double)] = [
        ("10M", 10), ("50M", 50), ("100M", 100), ("500M", 500), ("1G", 1000), ("5G", 5000)
    ]
    private let ageOptions: [(label: String, value: Int)] = [
        ("Any", 0), ("1 Mo", 30), ("6 Mo", 182), ("1 Yr", 365), ("2 Yr", 730)
    ]

    var body: some View {
        HStack(spacing: 14) {
            RackModule(title: "Filters", subtitle: "Set the knobs, then press SCAN") {
                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        RackKnob(title: "Larger than", options: sizeOptions, selection: $model.minSizeMB, size: 62, colorIndex: 1)
                        RackKnob(title: "Not opened in", options: ageOptions, selection: $model.olderThanDays, size: 62, colorIndex: 2)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Engraved("Search in", size: 10)
                        Button {
                            model.chooseFolder()
                        } label: {
                            Text(model.root.path.replacingOccurrences(of: FS.home.path, with: "~"))
                                .lineLimit(1).truncationMode(.middle)
                        }
                        .buttonStyle(RackButtonStyle(kind: .ghost, height: 30, fontSize: 11, fill: true))
                        Toggle(isOn: $model.includeHidden) {
                            Engraved("Include hidden files", size: 10)
                        }
                        .toggleStyle(BatToggleStyle())
                        .padding(.top, 4)
                    }
                    Spacer(minLength: 8)
                    if model.isScanning {
                        Button("Stop") { model.cancel() }
                            .buttonStyle(RackButtonStyle(kind: .danger, height: 40, fontSize: 14, fill: true))
                    } else {
                        Button("Scan") { model.scan() }
                            .buttonStyle(RackButtonStyle(kind: .primary, height: 40, fontSize: 14, fill: true))
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .disabled(false)
            }
            .frame(width: 360)

            RackModule(title: "Large & Old Files",
                       subtitle: model.isScanning ? "\(model.scannedCount.formatted()) files checked…"
                                 : model.hasScanned ? "\(model.files.count) files found" : "Find the big files you forgot about",
                       lamp: (Rack.lit, model.isScanning, true),
                       accessory: {
                           HStack(spacing: 10) {
                               Engraved("Sort", size: 10, tone: .muted)
                               RackSelector(options: [(label: "Size", value: LargeFilesModel.SortKey.size),
                                                      (label: "Name", value: .name), (label: "Oldest", value: .lastOpened)],
                                            selection: $model.sortKey)
                           }
                       }) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Engraved("Kind", size: 10, tone: .muted)
                        RackSelector(options: FileKind.allCases.map { (label: $0.rawValue, value: $0) },
                                     selection: $model.kind, height: 24, fontSize: 10)
                        Spacer(minLength: 0)
                    }
                    GlassWindow {
                        if model.visibleFiles.isEmpty {
                            AmberEmpty(title: model.hasScanned ? (model.files.isEmpty ? "NOTHING THAT BIG" : "NONE OF THAT KIND") : "SET THE KNOBS, PRESS SCAN",
                                       message: model.hasScanned
                                       ? "No files matched. Try a smaller size or a different folder."
                                       : "Turn the knobs to choose a minimum size and age, then press SCAN. App bundles count as single items.")
                        } else {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 1) {
                                    ForEach(model.visibleFiles) { file in row(file) }
                                }
                                .padding(12)
                            }
                        }
                    }
                    StatusStrip(message: model.status ?? "Light a lamp to select a file. Right-click to show it in Finder.") {
                        Button("Reveal") { FS.reveal(Array(model.selection)) }
                            .buttonStyle(RackButtonStyle(kind: .cap, height: 40, fontSize: 13))
                            .disabled(model.selection.isEmpty)
                        Button("Trash \(FS.format(model.selectedSize))") { confirm = true }
                            .buttonStyle(RackButtonStyle(kind: .primary, height: 40, fontSize: 14))
                            .disabled(model.selection.isEmpty || model.isScanning)
                    }
                }
            }
        }
        .alert("Move \(model.selection.count) files to the Trash?", isPresented: $confirm) {
            Button("Move to Trash", role: .destructive) { Task { await model.removeSelected() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func row(_ file: FoundFile) -> some View {
        Toggle(isOn: Binding(get: { model.selection.contains(file.url) },
                             set: { on in
                                 if on { model.selection.insert(file.url) } else { model.selection.remove(file.url) }
                             })) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    AmberText(file.name, size: 12, weight: .semibold)
                    AmberText(file.folder, size: 10).opacity(0.55)
                }
                Spacer(minLength: 10)
                AmberText(file.lastOpened == .distantPast ? "—" : "opened " + file.lastOpened.formatted(date: .abbreviated, time: .omitted), size: 10)
                    .opacity(0.6)
                    .frame(width: 140, alignment: .trailing)
                AmberText(FS.format(file.size), size: 12, weight: .bold)
                    .frame(width: 80, alignment: .trailing)
            }
        }
        .toggleStyle(LEDToggleStyle())
        .padding(.vertical, 3)
        .contextMenu { Button("Show in Finder") { FS.reveal([file.url]) } }
    }
}
