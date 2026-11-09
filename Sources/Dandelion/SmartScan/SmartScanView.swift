import SwiftUI

/// One button that runs every scanner, like a one-touch service check.
struct SmartScanView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var junk: JunkModel
    @EnvironmentObject private var uninstaller: UninstallerModel
    @EnvironmentObject private var loginItems: LoginItemsModel
    @EnvironmentObject private var monitor: SystemMonitor

    @State private var running = false
    @State private var confirm = false

    private var brokenLoginItems: [LaunchItem] { loginItems.items.filter(\.programMissing) }
    private var scanned: Bool { junk.hasScanned }
    private var active: Bool { running || junk.isCleaning }

    private var headline: String {
        if running { return "Scanning" }
        if junk.isCleaning { return "Cleaning" }
        return scanned ? "Ready" : "Standby"
    }

    private var subline: String {
        if running { return "Checking junk, leftovers and startup items" }
        if scanned { return "\(FS.format(junk.selectedSize)) selected to clean" }
        return "Press the button to check your Mac"
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                RackModule(title: "Smart Scan", subtitle: "One-touch check of the whole Mac",
                           lamp: (Rack.lit, active, true)) {
                    HStack(spacing: 26) {
                        BigRoundButton(symbol: "power", active: active, size: 124) {
                            guard !running else { return }
                            Task { await runScan() }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Engraved(headline, size: 44, tone: active ? .lit : .normal)
                            Engraved(subline, size: 12, tone: .muted)
                            TapeLabel(text: "Nothing goes until you press CLEAN", size: 14)
                                .padding(.top, 6)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 8)
                }

                RackModule(title: "Meters", subtitle: "Live, only while the window is open") {
                    HStack(spacing: 18) {
                        VUMeter(title: "CPU", value: monitor.cpu, caption: "\(Int(monitor.cpu * 100))%", width: 172, lit: active)
                        VUMeter(title: "Memory", value: monitor.memoryFraction,
                                caption: FS.format(Int64(monitor.memoryUsed)), width: 172, lit: active)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(width: 430)
            }
            .frame(height: 214)

            RackModule(title: "Findings", subtitle: scanned ? "Press a row to review it" : "Run a scan to fill this in",
                       lamp: (Rack.green, scanned && !running, false)) {
                VStack(spacing: 12) {
                    GlassWindow {
                        if !scanned && !running {
                            AmberEmpty(title: "NO SCAN YET",
                                       message: "Smart Scan checks caches, logs, developer data, Mail attachments, old installers, the Trash, leftovers of removed apps and broken startup items. Nothing is removed until you press CLEAN.")
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(junk.categories) { cat in
                                        let size = junk.size(of: cat)
                                        resultRow(name: cat.name, detail: cat.detail,
                                                  value: running && size == 0 ? "…" : FS.format(size),
                                                  lit: size > 0, color: Rack.lit) { state.section = .cleanup }
                                    }
                                    resultRow(name: "Leftovers of removed apps",
                                              detail: "\(uninstaller.orphans.count) folders · review before removing",
                                              value: uninstaller.orphanTotal > 0 ? FS.format(uninstaller.orphanTotal)
                                                     : uninstaller.orphans.isEmpty ? "none" : "\(uninstaller.orphans.count)",
                                              lit: !uninstaller.orphans.isEmpty, color: Rack.lit) {
                                        uninstaller.mode = .orphans
                                        state.section = .uninstaller
                                    }
                                    resultRow(name: "Broken login items",
                                              detail: "Startup helpers whose program no longer exists",
                                              value: brokenLoginItems.isEmpty ? "none" : "\(brokenLoginItems.count)",
                                              lit: !brokenLoginItems.isEmpty, color: Rack.red) { state.section = .loginItems }
                                }
                                .padding(14)
                            }
                        }
                    }
                    StatusStrip(message: junk.needsFullDiskAccess && scanned
                                ? "Trash & Mail are hidden by macOS. Grant Full Disk Access to include them."
                                : junk.status ?? (scanned ? "Total found: \(FS.format(junk.totalFound)). Lit rows are worth a look."
                                                          : "Standing by.")) {
                        if junk.needsFullDiskAccess && scanned {
                            Button("Grant Access") { FS.openFullDiskAccessSettings() }
                                .buttonStyle(RackButtonStyle(kind: .ghost, height: 40, fontSize: 12))
                        }
                        Button("Clean \(FS.format(junk.selectedSize))") { confirm = true }
                            .buttonStyle(RackButtonStyle(kind: .primary, height: 40, fontSize: 14))
                            .disabled(!scanned || junk.selected.isEmpty || running || junk.isCleaning)
                    }
                }
            }
        }
        .alert("Clean \(FS.format(junk.selectedSize))?", isPresented: $confirm) {
            Button("Clean", role: .destructive) { Task { await junk.clean() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(junk.moveToTrash
                 ? "Selected junk is moved to the Trash. Items already in the Trash are deleted permanently. Leftovers and login items are never removed from here."
                 : "SAFE is off: selected junk is deleted permanently. Leftovers and login items are never removed from here.")
        }
    }

    private func runScan() async {
        running = true
        async let a: Void = junk.scan()
        async let b: Void = uninstaller.scanOrphans()
        async let c: Void = loginItems.load()
        _ = await (a, b, c)
        running = false
    }

    private func resultRow(name: String, detail: String, value: String, lit: Bool, color: Color,
                           review: @escaping () -> Void) -> some View {
        Button(action: review) {
            HStack(spacing: 12) {
                LED(color: color, on: lit, size: 12)
                AmberRow(name: name, detail: detail, value: value)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Rack.amber.opacity(0.5))
            }
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
