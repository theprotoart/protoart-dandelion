import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var junk: JunkModel
    @EnvironmentObject private var monitor: SystemMonitor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 14) {
            BrandPlate(compact: true)

            HStack(spacing: 10) {
                VUMeter(title: "CPU", value: monitor.cpu, caption: "\(Int(monitor.cpu * 100))%", width: 140)
                VUMeter(title: "MEM", value: monitor.memoryFraction, caption: "\(Int(monitor.memoryFraction * 100))%", width: 140)
            }

            let disk = FS.readout(monitor.diskFree)
            HStack(spacing: 10) {
                Engraved("Disk free", size: 11)
                Spacer()
                GlassWindow(scanlines: false, cornerRadius: 4) {
                    SevenSegment(text: disk.value, digitHeight: 18)
                        .padding(.horizontal, 6)
                        .frame(height: 30)
                }
                Engraved(disk.unit, size: 11)
            }

            if junk.hasScanned {
                GlassWindow {
                    AmberText("\(FS.format(junk.totalFound)) junk found in last scan", size: 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
            }

            HStack(spacing: 0) {
                Button("Smart Scan") { open(.smartScan) }
                    .buttonStyle(RackButtonStyle(kind: .primary, height: 28, fontSize: 11))
                Button("Open") { open(nil) }
                    .buttonStyle(RackButtonStyle(kind: .cap, height: 28, fontSize: 11))
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(RackButtonStyle(kind: .cap, height: 28, fontSize: 11))
            }
        }
        .padding(16)
        .frame(width: 330)
        .background(RackSurface())
        .preferredColorScheme(Palette.current.dark ? .dark : .light)
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    private func open(_ pane: Pane?) {
        if let pane { state.section = pane }
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
