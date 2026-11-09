import SwiftUI
import AppKit

@main
struct DandelionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var look = Look()
    @StateObject private var state = AppState()
    @StateObject private var junk = JunkModel()
    @StateObject private var uninstaller = UninstallerModel()
    @StateObject private var largeFiles = LargeFilesModel()
    @StateObject private var spaceLens = SpaceLensModel()
    @StateObject private var maintenance = MaintenanceModel()
    @StateObject private var loginItems = LoginItemsModel()
    @StateObject private var monitor = SystemMonitor()

    var body: some Scene {
        Window("Dandelion", id: "main") {
            ContentView()
                .id(look.signature)          // rebuild the faceplate when the look changes
                .environmentObject(look)
                .environmentObject(state)
                .environmentObject(junk)
                .environmentObject(uninstaller)
                .environmentObject(largeFiles)
                .environmentObject(spaceLens)
                .environmentObject(maintenance)
                .environmentObject(loginItems)
                .environmentObject(monitor)
                .frame(minWidth: 1220, minHeight: 860)
                .tint(look.palette.litMid)
        }
        .defaultSize(width: 1240, height: 880)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)

        Window("Set-up Card", id: "setup") {
            SetupCard()
                .environmentObject(look)
                .environmentObject(junk)
                .preferredColorScheme(look.palette.dark ? .dark : .light)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Window("Operator's Card", id: "about") {
            OperatorsCard()
                .id(look.signature)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            MenuBarView()
                .id(look.signature)
                .environmentObject(look)
                .environmentObject(state)
                .environmentObject(junk)
                .environmentObject(monitor)
                .environmentObject(maintenance)
        } label: {
            Image(systemName: "camera.macro")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Gives the app a Dock icon and menus even when launched straight from `swift run`.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

enum Theme {
    /// Dandelion yellow.
    static let accent = Color(red: 0.96, green: 0.72, blue: 0.10)
    static let leaf = Color(red: 0.36, green: 0.66, blue: 0.38)
    static let seed = Color(red: 0.55, green: 0.62, blue: 0.72)
}

enum Pane: String, CaseIterable, Identifiable, Hashable {
    case smartScan, cleanup, uninstaller, spaceLens, largeFiles, maintenance, loginItems

    var id: Self { self }

    var title: String {
        switch self {
        case .smartScan: return "Smart Scan"
        case .cleanup: return "Cleanup"
        case .uninstaller: return "Uninstaller"
        case .spaceLens: return "Space Lens"
        case .largeFiles: return "Large & Old Files"
        case .maintenance: return "Maintenance"
        case .loginItems: return "Login Items"
        }
    }

    var symbol: String {
        switch self {
        case .smartScan: return "sparkles"
        case .cleanup: return "trash.circle"
        case .uninstaller: return "xmark.app"
        case .spaceLens: return "circle.grid.cross"
        case .largeFiles: return "doc.text.magnifyingglass"
        case .maintenance: return "wrench.and.screwdriver"
        case .loginItems: return "power.circle"
        }
    }

    var short: String {
        switch self {
        case .smartScan: return "Smart Scan"
        case .cleanup: return "Cleanup"
        case .uninstaller: return "Uninstall"
        case .spaceLens: return "Space Lens"
        case .largeFiles: return "Large Files"
        case .maintenance: return "Maintenance"
        case .loginItems: return "Login Items"
        }
    }

    var group: String {
        switch self {
        case .smartScan: return ""
        case .cleanup, .uninstaller: return "Clean"
        case .spaceLens, .largeFiles: return "Space"
        case .maintenance, .loginItems: return "Speed"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var section: Pane? = .smartScan
}

struct ContentView: View {
    @EnvironmentObject private var look: Look
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var junk: JunkModel
    @EnvironmentObject private var uninstaller: UninstallerModel
    @EnvironmentObject private var largeFiles: LargeFilesModel
    @EnvironmentObject private var spaceLens: SpaceLensModel
    @EnvironmentObject private var maintenance: MaintenanceModel
    @EnvironmentObject private var monitor: SystemMonitor

    @Environment(\.openWindow) private var openWindow

    private var busy: Bool {
        junk.isScanning || junk.isCleaning || uninstaller.isScanningOrphans || uninstaller.isLoading
            || spaceLens.isMeasuring || largeFiles.isScanning || maintenance.states.values.contains(.running)
    }

    private var fault: Bool {
        [junk.status, uninstaller.status, largeFiles.status, spaceLens.status].contains { $0?.contains("could not") == true }
            || maintenance.states.values.contains { if case .failed = $0 { return true } else { return false } }
    }

    private var ticker: String {
        if junk.isCleaning { return "Cleaning…" }
        if junk.isScanning { return "Scanning caches, logs and installers…" }
        if uninstaller.isScanningOrphans { return "Looking for leftovers of removed apps…" }
        if largeFiles.isScanning { return "Searching · \(largeFiles.scannedCount.formatted()) files checked" }
        if spaceLens.isMeasuring { return "Measuring \(spaceLens.current?.lastPathComponent ?? "folders")…" }
        if maintenance.states.values.contains(.running) { return "Running a maintenance task…" }
        if junk.hasScanned { return "Ready · \(FS.format(junk.selectedSize)) selected to clean" }
        return "Idle · press SMART SCAN to check your Mac"
    }

    var body: some View {
        VStack(spacing: 0) {
            rackHead
            TrimStripe()
            HStack(spacing: 0) {
                RackEar()
                module
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                RackEar()
            }
        }
        .background(RackSurface())
        .ignoresSafeArea()
        .preferredColorScheme(look.palette.dark ? .dark : .light)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    // MARK: the top panel: brand plate, status, lamps, safety lever, readouts, VU, tabs

    private var rackHead: some View {
        HStack(spacing: 0) {
            RackEar(screwTop: 44)
            VStack(spacing: 12) {
                HStack(alignment: .center, spacing: 20) {
                    BrandPlate()
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Engraved("Unit", size: 9.5)
                            Engraved(busy ? "working" : "standing by", size: 9.5, tone: .muted)
                        }
                        GlassWindow(scanlines: false, cornerRadius: 2) {
                            Text(ticker)
                                .font(Rack.condensed(14))
                                .tracking(0.5)
                                .foregroundStyle(Rack.amber)
                                .shadow(color: Rack.amber.opacity(0.75), radius: 4)
                                .lineLimit(1)
                                .frame(width: 300, height: 24, alignment: .leading)
                                .padding(.horizontal, 8)
                        }
                        HStack(spacing: 6) {
                            Button("Setup") { openWindow(id: "setup") }
                                .buttonStyle(RackButtonStyle(kind: .cap, height: 24, fontSize: 10))
                            Button("About") { openWindow(id: "about") }
                                .buttonStyle(RackButtonStyle(kind: .cap, height: 24, fontSize: 10))
                        }
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .leading, spacing: 7) {
                        lamp("Power", Rack.green, on: true)
                        lamp("Busy", Rack.lit, on: busy, blink: true)
                        lamp("Fault", Rack.red, on: fault)
                    }
                    PanelToggle(name: "Safe", isOn: $junk.moveToTrash, onLabel: "Trash", offLabel: "Delete")
                        .help("SAFE up: cleaned items go to the Trash so you can put them back. Down: they are deleted at once.")
                    HStack(alignment: .top, spacing: 10) {
                        let disk = FS.readout(monitor.diskFree)
                        Readout(caption: "Disk free", value: disk.value, unit: disk.unit)
                        let found = FS.readout(junk.totalFound)
                        Readout(caption: "Junk found", value: junk.hasScanned ? found.value : "--", unit: junk.hasScanned ? found.unit : "")
                    }
                    VUMeter(title: "CPU", value: monitor.cpu, caption: "\(Int(monitor.cpu * 100))%", width: 128, lit: busy, showLabels: false)
                }
                HStack(spacing: 6) {
                    ForEach(Pane.allCases) { pane in
                        Button(pane.short) { state.section = pane }
                            .buttonStyle(RackButtonStyle(kind: .tab(active: (state.section ?? .smartScan) == pane),
                                                         height: 30, fontSize: 11, fill: true))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 30)
            .padding(.bottom, 12)
            RackEar(screwTop: 44)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(RackSurface())
        .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0x0b0b0c)).frame(height: 2) }
        .shadow(color: .black.opacity(0.45), radius: 6, y: 4)
        .zIndex(1)
    }

    private func lamp(_ label: String, _ color: Color, on: Bool, blink: Bool = false) -> some View {
        HStack(spacing: 8) {
            LED(color: color, on: on, blink: blink, size: 11)
                .id("\(label)-\(on)")
            Engraved(label, size: 10).fixedSize()
        }
    }

    @ViewBuilder
    private var module: some View {
        switch state.section ?? .smartScan {
        case .smartScan: SmartScanView()
        case .cleanup: JunkView()
        case .uninstaller: UninstallerView()
        case .spaceLens: SpaceLensView()
        case .largeFiles: LargeFilesView()
        case .maintenance: MaintenanceView()
        case .loginItems: LoginItemsView()
        }
    }
}
