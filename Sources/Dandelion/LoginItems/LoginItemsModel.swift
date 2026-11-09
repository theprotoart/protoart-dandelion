import Foundation
import AppKit

struct LaunchItem: Identifiable, Hashable, Sendable {
    enum Scope: String, Sendable, CaseIterable {
        case userAgent = "Your launch agents"
        case systemAgent = "Launch agents for all users"
        case systemDaemon = "Background daemons"
    }

    var id: URL { url }
    let url: URL
    let label: String
    let program: String?
    let scope: Scope
    let runAtLoad: Bool
    let keepAlive: Bool
    /// Switched off with launchctl (reversible), like CleanMyMac's on/off switch.
    var disabled = false

    /// Only the current user's agents can be removed without an admin password.
    var removable: Bool { scope == .userAgent }

    /// The app a helper's program path lives inside, if any (e.g. /Applications/Foo.app).
    var owningApp: URL? {
        guard let program, let range = program.range(of: ".app/") else { return nil }
        return URL(fileURLWithPath: String(program[..<range.lowerBound]) + ".app")
    }

    var programMissing: Bool {
        guard let program, program.hasPrefix("/") else { return false }
        return !FileManager.default.fileExists(atPath: program)
    }
}

@MainActor
final class LoginItemsModel: ObservableObject {
    @Published var items: [LaunchItem] = []
    @Published var isLoading = false
    @Published var status: String?

    func items(in scope: LaunchItem.Scope) -> [LaunchItem] { items.filter { $0.scope == scope } }

    func load() async {
        isLoading = true
        items = await Task.detached(priority: .userInitiated) { Self.discover() }.value
        isLoading = false
    }

    /// Stops a user launch agent and moves its plist to the Trash.
    func remove(_ item: LaunchItem) async {
        guard item.removable else { return }
        let uid = getuid()
        let path = item.url.path
        let result = await Task.detached(priority: .userInitiated) { () -> FS.RemovalResult in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            p.arguments = ["bootout", "gui/\(uid)", path]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            try? p.run()
            p.waitUntilExit() // a failure here usually just means it wasn't loaded
            return FS.remove([(url: URL(fileURLWithPath: path), size: 0)], permanently: false)
        }.value
        status = result.failures.isEmpty
            ? "Stopped \(item.label) and moved its file to the Trash."
            : "Couldn't remove \(item.label)."
        await load()
    }

    /// Turns one of your own launch agents off or back on without deleting anything.
    func setEnabled(_ item: LaunchItem, _ on: Bool) async {
        guard item.removable else { return }
        let uid = getuid()
        let label = item.label, path = item.url.path
        await Task.detached(priority: .userInitiated) {
            func launchctl(_ args: [String]) {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                p.arguments = args
                p.standardOutput = FileHandle.nullDevice
                p.standardError = FileHandle.nullDevice
                try? p.run()
                p.waitUntilExit()
            }
            if on {
                launchctl(["enable", "gui/\(uid)/\(label)"])
                launchctl(["bootstrap", "gui/\(uid)", path])
            } else {
                launchctl(["bootout", "gui/\(uid)", path])
                launchctl(["disable", "gui/\(uid)/\(label)"])
            }
        }.value
        status = on ? "\(label) switched back on." : "\(label) switched off. Flip it back any time."
        await load()
    }

    func openSystemLoginItems() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Labels the user has switched off (launchctl print-disabled gui/<uid>).
    nonisolated static func disabledLabels() -> Set<String> {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = ["print-disabled", "gui/\(getuid())"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        var result = Set<String>()
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            // "com.example.agent" => disabled   (older macOS: => true)
            let parts = line.components(separatedBy: "=>")
            guard parts.count == 2 else { continue }
            let state = parts[1].trimmingCharacters(in: .whitespaces)
            guard state == "disabled" || state == "true" else { continue }
            result.insert(parts[0].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")))
        }
        return result
    }

    nonisolated static func discover() -> [LaunchItem] {
        let off = disabledLabels()
        let sources: [(URL, LaunchItem.Scope)] = [
            (FS.library.appendingPathComponent("LaunchAgents"), .userAgent),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), .systemAgent),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), .systemDaemon)
        ]
        var result: [LaunchItem] = []
        for (dir, scope) in sources {
            for url in FS.children(of: dir) where url.pathExtension == "plist" {
                guard let data = try? Data(contentsOf: url),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
                else { continue }
                let label = plist["Label"] as? String ?? url.deletingPathExtension().lastPathComponent
                let program = (plist["Program"] as? String) ?? (plist["ProgramArguments"] as? [String])?.first
                let keepAlive: Bool
                if let b = plist["KeepAlive"] as? Bool { keepAlive = b } else { keepAlive = plist["KeepAlive"] != nil }
                result.append(LaunchItem(url: url, label: label, program: program, scope: scope,
                                         runAtLoad: plist["RunAtLoad"] as? Bool ?? false,
                                         keepAlive: keepAlive,
                                         disabled: scope == .userAgent && off.contains(label)))
            }
        }
        return result.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }
}
