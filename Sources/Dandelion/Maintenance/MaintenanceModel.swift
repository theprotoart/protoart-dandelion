import Foundation
import AppKit
import Darwin

struct MaintenanceTask: Identifiable, Sendable {
    let id: String
    let name: String
    let detail: String
    let symbol: String
    let command: String
    let needsAdmin: Bool

    static let all: [MaintenanceTask] = [
        MaintenanceTask(id: "dns", name: "Flush DNS Cache",
                        detail: "Fixes websites that won't load after network or DNS changes.",
                        symbol: "network", command: "dscacheutil -flushcache; killall -HUP mDNSResponder",
                        needsAdmin: true),
        MaintenanceTask(id: "ram", name: "Free Up Memory",
                        detail: "Clears inactive memory macOS is holding on to. Apps may feel slower for a moment.",
                        symbol: "memorychip", command: "purge", needsAdmin: true),
        MaintenanceTask(id: "snapshots", name: "Thin Time Machine Snapshots",
                        detail: "Removes local backup snapshots that show up as “purgeable” space.",
                        symbol: "clock.arrow.circlepath",
                        command: "tmutil thinlocalsnapshots / 999999999999 4", needsAdmin: true),
        MaintenanceTask(id: "spotlight", name: "Reindex Spotlight",
                        detail: "Rebuilds the search index when Spotlight misses files. Takes a while in the background.",
                        symbol: "magnifyingglass", command: "mdutil -E /", needsAdmin: true),
        MaintenanceTask(id: "launchservices", name: "Rebuild Launch Services",
                        detail: "Fixes duplicate apps in “Open With” and wrong default apps.",
                        symbol: "square.stack.3d.up",
                        command: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -r -domain local -domain system -domain user",
                        needsAdmin: false),
        MaintenanceTask(id: "quicklook", name: "Reset Quick Look",
                        detail: "Clears thumbnail and preview caches when previews look wrong.",
                        symbol: "eye", command: "qlmanage -r cache; qlmanage -r", needsAdmin: false),
        MaintenanceTask(id: "dock", name: "Restart Dock & Finder",
                        detail: "Unsticks a frozen Dock, Finder or desktop.",
                        symbol: "dock.rectangle", command: "killall Dock; killall Finder", needsAdmin: false)
    ]
}

struct RunningAppInfo: Identifiable {
    var id: pid_t { pid }
    let pid: pid_t
    let name: String
    let icon: NSImage?
    let memory: UInt64
    let app: NSRunningApplication
}

@MainActor
final class MaintenanceModel: ObservableObject {
    enum TaskState: Equatable { case idle, running, done, failed(String) }

    @Published var states: [String: TaskState] = [:]
    @Published var apps: [RunningAppInfo] = []

    func state(_ task: MaintenanceTask) -> TaskState { states[task.id] ?? .idle }

    func run(_ task: MaintenanceTask) async {
        states[task.id] = .running
        let result = await Task.detached(priority: .userInitiated) { Self.execute(task) }.value
        states[task.id] = result
    }

    /// Runs the command; admin tasks go through osascript so macOS shows its own password prompt.
    nonisolated static func execute(_ task: MaintenanceTask) -> TaskState {
        let process = Process()
        if task.needsAdmin {
            let escaped = task.command
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "do shell script \"\(escaped)\" with administrator privileges"]
        } else {
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", task.command]
        }
        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failed(error.localizedDescription)
        }
        if process.terminationStatus == 0 { return .done }
        let message = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if message.contains("-128") { return .idle } // user cancelled the password prompt
        // killall exits non-zero when a process wasn't running; that's fine.
        if task.id == "dock" { return .done }
        return .failed(message.isEmpty ? "Exited with code \(process.terminationStatus)" : message)
    }

    // MARK: Heavy apps

    func refreshApps() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ownPID }
            .map { app in
                RunningAppInfo(pid: app.processIdentifier,
                               name: app.localizedName ?? "App",
                               icon: app.icon,
                               memory: Self.footprint(of: app.processIdentifier),
                               app: app)
            }
            .sorted { $0.memory > $1.memory }
    }

    func quit(_ info: RunningAppInfo, force: Bool) {
        if force { info.app.forceTerminate() } else { info.app.terminate() }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            refreshApps()
        }
    }

    /// Physical memory footprint, the same number Activity Monitor shows in its Memory column.
    nonisolated static func footprint(of pid: pid_t) -> UInt64 {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? info.ri_phys_footprint : 0
    }
}
