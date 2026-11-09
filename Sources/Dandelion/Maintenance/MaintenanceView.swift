import SwiftUI

struct MaintenanceView: View {
    @EnvironmentObject private var model: MaintenanceModel
    @EnvironmentObject private var monitor: SystemMonitor
    @State private var forceQuit: RunningAppInfo?

    var body: some View {
        HStack(spacing: 14) {
            RackModule(title: "Maintenance", subtitle: "Quick fixes · a lock means macOS asks for your password",
                       lamp: (Rack.lit, model.states.values.contains(.running), true)) {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(MaintenanceTask.all) { task in taskRow(task) }
                    }
                    .padding(.trailing, 4)
                }
            }
            .frame(width: 540)

            RackModule(title: "Memory", subtitle: "Apps using the most memory right now",
                       accessory: {
                           Button("Refresh") { model.refreshApps() }
                               .buttonStyle(RackButtonStyle(kind: .cap, height: 28, fontSize: 11))
                       }) {
                VStack(spacing: 12) {
                    HStack(spacing: 18) {
                        VUMeter(title: "Memory", value: monitor.memoryFraction,
                                caption: "\(FS.format(Int64(monitor.memoryUsed))) of \(FS.format(Int64(monitor.memoryTotal)))", width: 200)
                        Readout(caption: "Apps open", value: "\(model.apps.count)", unit: "", digits: 3, digitHeight: 26)
                    }
                    GlassWindow {
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(model.apps.prefix(15)) { info in appRow(info) }
                            }
                            .padding(12)
                        }
                    }
                }
            }
        }
        .onAppear { model.refreshApps() }
        .alert("Force quit \(forceQuit?.name ?? "")?",
               isPresented: Binding(get: { forceQuit != nil }, set: { if !$0 { forceQuit = nil } })) {
            Button("Force Quit", role: .destructive) {
                if let info = forceQuit { model.quit(info, force: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Any unsaved changes in this app will be lost.")
        }
    }

    private func taskRow(_ task: MaintenanceTask) -> some View {
        let state = model.state(task)
        let ledColor: Color = {
            switch state {
            case .failed: return Rack.red
            case .done: return Rack.green
            default: return Rack.lit
            }
        }()
        return HStack(alignment: .center, spacing: 12) {
            LED(color: ledColor, on: state != .idle, blink: state == .running, size: 13)
                .id("\(task.id)-\(String(describing: state))")
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Engraved(task.name, size: 12.5)
                    if task.needsAdmin {
                        Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(Rack.muted)
                    }
                }
                Text(task.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Rack.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if case .failed(let message) = state {
                    Text(message).font(.system(size: 10)).foregroundStyle(Rack.red).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Button(state == .running ? "Running" : state == .done ? "Again" : "Run") { Task { await model.run(task) } }
                .buttonStyle(RackButtonStyle(kind: state == .running ? .primary : .cap, height: 28, fontSize: 11))
                .disabled(state == .running)
                .frame(width: 92)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 3).fill(.black.opacity(Palette.current.dark ? 0.25 : 0.06)))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.25), lineWidth: 1))
        .shadow(color: Palette.current.groove, radius: 0, y: 1)
    }

    private func appRow(_ info: RunningAppInfo) -> some View {
        HStack(spacing: 10) {
            if let icon = info.icon {
                Image(nsImage: icon).resizable().frame(width: 20, height: 20)
            }
            AmberText(info.name, size: 12, weight: .semibold)
            Spacer()
            AmberText(FS.format(Int64(info.memory)), size: 12, weight: .bold)
                .frame(width: 80, alignment: .trailing)
            Button("Quit") { model.quit(info, force: false) }
                .buttonStyle(RackButtonStyle(kind: .cap, height: 22, fontSize: 10))
            Button("Force") { forceQuit = info }
                .buttonStyle(RackButtonStyle(kind: .dangerText, height: 22, fontSize: 10))
        }
        .padding(.vertical, 2)
    }
}
