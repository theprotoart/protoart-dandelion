import Foundation
import AppKit

struct AppInfo: Identifiable, Hashable, Sendable {
    var id: URL { url }
    let url: URL
    let name: String
    let bundleID: String?
    let version: String?
    var size: Int64
}

struct Leftover: Identifiable, Hashable, Sendable {
    var id: URL { url }
    let url: URL
    let size: Int64
    let location: String
}

@MainActor
final class UninstallerModel: ObservableObject {
    @Published var apps: [AppInfo] = []
    @Published var isLoading = false
    @Published var search = ""
    @Published var selectedAppID: URL?
    @Published var leftovers: [Leftover] = []
    @Published var selectedLeftovers: Set<URL> = []
    @Published var isFindingLeftovers = false
    @Published var status: String?
    /// The last removal left something behind: show the Settings buttons.
    @Published var needsPermissions = false

    enum Mode: String, CaseIterable { case apps = "Applications", orphans = "Leftovers of Removed Apps" }
    @Published var mode: Mode = .apps
    @Published var orphans: [Leftover] = []
    @Published var selectedOrphans: Set<URL> = []
    @Published var isScanningOrphans = false
    @Published var hasScannedOrphans = false

    var orphanTotal: Int64 { orphans.reduce(0) { $0 + $1.size } }
    var selectedOrphanSize: Int64 { orphans.filter { selectedOrphans.contains($0.url) }.reduce(0) { $0 + $1.size } }

    private var leftoverTask: Task<Void, Never>?

    var filteredApps: [AppInfo] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var selectedApp: AppInfo? { apps.first { $0.url == selectedAppID } }

    var totalRemovalSize: Int64 {
        (selectedApp?.size ?? 0) + leftovers.filter { selectedLeftovers.contains($0.url) }.reduce(0) { $0 + $1.size }
    }

    func loadApps() async {
        isLoading = true
        let found = await Task.detached(priority: .userInitiated) { Self.discoverApps() }.value
        apps = found
        isLoading = false

        // Fill in sizes in the background; the list is usable right away.
        for app in found {
            let size = await Task.detached(priority: .utility) { FS.allocatedSize(of: app.url) }.value
            if let i = apps.firstIndex(where: { $0.url == app.url }) { apps[i].size = size }
        }
    }

    func select(_ id: URL?) {
        selectedAppID = id
        leftovers = []
        selectedLeftovers = []
        status = nil
        isFindingLeftovers = false
        leftoverTask?.cancel()
        guard let app = selectedApp else { return }
        isFindingLeftovers = true
        leftoverTask = Task {
            let found = await Task.detached(priority: .userInitiated) { Self.findLeftovers(for: app) }.value
            guard !Task.isCancelled, selectedAppID == app.url else { return }
            leftovers = found
            selectedLeftovers = Set(found.map(\.url))
            isFindingLeftovers = false
        }
    }

    func uninstall() async {
        guard let app = selectedApp else { return }
        if let bid = app.bundleID, !NSRunningApplication.runningApplications(withBundleIdentifier: bid).isEmpty {
            status = "\(app.name) is running. Quit it first, then try again."
            return
        }
        let targets = [(url: app.url, size: app.size)]
            + leftovers.filter { selectedLeftovers.contains($0.url) }.map { (url: $0.url, size: $0.size) }
        let result = await Task.detached(priority: .userInitiated) { FS.remove(targets, permanently: false) }.value

        if !FS.exists(app.url) {
            apps.removeAll { $0.url == app.url }
            selectedAppID = nil
            leftovers = []
            selectedLeftovers = []
        }
        needsPermissions = !result.failures.isEmpty && !result.cancelled
        status = result.failures.isEmpty
            ? result.summary + " Everything went to the Trash, so you can still put it back."
            : result.summary
    }

    func scanOrphans() async {
        isScanningOrphans = true
        let installed = Set(apps.compactMap { $0.bundleID?.lowercased() })
        let found = await Task.detached(priority: .userInitiated) { Self.findOrphans(installed: installed) }.value
        orphans = found
        selectedOrphans = []   // never pre-selected: the user decides
        isScanningOrphans = false
        hasScannedOrphans = true
    }

    func removeOrphans() async {
        let targets = orphans.filter { selectedOrphans.contains($0.url) }.map { (url: $0.url, size: $0.size) }
        let result = await Task.detached(priority: .userInitiated) { FS.remove(targets, permanently: false) }.value
        orphans.removeAll { !FS.exists($0.url) }
        selectedOrphans = []
        needsPermissions = !result.failures.isEmpty && !result.cancelled
        status = result.failures.isEmpty ? result.summary + " Everything went to the Trash." : result.summary
    }

    /// Support folders named after a bundle ID that nothing installed on this Mac uses any more.
    /// Only looks in folders macOS names strictly by bundle ID, so matches are reliable.
    nonisolated static func findOrphans(installed: Set<String>) -> [Leftover] {
        let known = installed.union(installedBundleIDs())
        let fda = FS.hasFullDiskAccess()
        let folders = ["Containers", "Saved Application State", "Application Scripts"]
        var result: [Leftover] = []
        for folder in folders {
            for child in FS.children(of: FS.library.appendingPathComponent(folder)) {
                var id = child.lastPathComponent
                if id.hasSuffix(".savedState") { id = String(id.dropLast(".savedState".count)) }
                var parts = id.split(separator: ".").map(String.init)
                // Drop a Team ID prefix such as "S8EX82NJP6."
                if let first = parts.first, first.count == 10,
                   first.allSatisfy({ $0.isUppercase || $0.isNumber }) { parts.removeFirst() }
                let lower = parts.joined(separator: ".").lowercased()
                guard parts.count >= 3,
                      !lower.hasPrefix("com.apple."),
                      !lower.hasPrefix("group.") else { continue }
                if known.contains(lower) || known.contains(where: { lower.hasPrefix($0 + ".") }) { continue }
                if NSWorkspace.shared.urlForApplication(withBundleIdentifier: parts.joined(separator: ".")) != nil { continue }
                result.append(Leftover(url: child, size: FS.safeSize(of: child, fullDiskAccess: fda), location: folder))
            }
        }
        return result.sorted { $0.size > $1.size }
    }

    /// Every bundle ID that ships inside an installed app — the app itself, its extensions, XPC services,
    /// login items, privileged helpers and the XPC services of its frameworks — plus all app extensions
    /// macOS has registered. Anything named after one of these still belongs to something installed.
    nonisolated static func installedBundleIDs() -> Set<String> {
        var ids = Set<String>()
        let fm = FileManager.default
        let nested: Set<String> = ["appex", "xpc", "app", "systemextension", "qlgenerator", "mdimporter", "saver", "prefPane"]

        func add(_ url: URL) {
            if let id = Bundle(url: url)?.bundleIdentifier { ids.insert(id.lowercased()) }
        }
        func scanBundle(_ bundle: URL, depth: Int) {
            add(bundle)
            guard depth < 4 else { return }
            let contents = bundle.appendingPathComponent("Contents")
            for sub in ["PlugIns", "XPCServices", "Library/LoginItems", "Library/SystemExtensions", "Helpers",
                        "MacOS", "Library/QuickLook", "Library/Spotlight", "Resources"] {
                for child in FS.children(of: contents.appendingPathComponent(sub)) where nested.contains(child.pathExtension) {
                    scanBundle(child, depth: depth + 1)
                }
            }
            // Privileged helpers are plain executables named after their bundle ID.
            for child in FS.children(of: contents.appendingPathComponent("Library/LaunchServices")) {
                ids.insert(child.lastPathComponent.lowercased())
            }
            for fw in FS.children(of: contents.appendingPathComponent("Frameworks")) where fw.pathExtension == "framework" {
                for base in [fw, fw.appendingPathComponent("Versions/A"), fw.appendingPathComponent("Versions/B")] {
                    for child in FS.children(of: base.appendingPathComponent("XPCServices")) where child.pathExtension == "xpc" {
                        scanBundle(child, depth: depth + 1)
                    }
                    for child in FS.children(of: base.appendingPathComponent("Resources")) where child.pathExtension == "app" {
                        add(child)
                    }
                }
            }
        }
        func walk(_ folder: URL, depth: Int) {
            for url in FS.children(of: folder) {
                if url.pathExtension == "app" {
                    scanBundle(url, depth: 0)
                } else if depth < 3, (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    walk(url, depth: depth + 1)
                }
            }
        }
        walk(URL(fileURLWithPath: "/Applications"), depth: 0)
        walk(FS.home.appendingPathComponent("Applications"), depth: 0)
        _ = fm

        // App extensions registered with macOS, wherever their app lives.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        p.arguments = ["-m", "-A", "-v"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        if (try? p.run()) != nil {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
                let trimmed = line.drop { $0 == " " || $0 == "+" || $0 == "-" || $0 == "!" || $0 == "=" || $0 == "\t" }
                if let paren = trimmed.firstIndex(of: "(") {
                    ids.insert(trimmed[..<paren].lowercased())
                }
            }
        }
        return ids
    }

    // MARK: - Discovery (runs off the main thread)

    nonisolated static func discoverApps() -> [AppInfo] {
        let roots = [URL(fileURLWithPath: "/Applications"), FS.home.appendingPathComponent("Applications")]
        var seen = Set<String>()
        var result: [AppInfo] = []

        func visit(_ folder: URL, depth: Int) {
            for url in FS.children(of: folder) {
                if url.pathExtension == "app" {
                    guard seen.insert(url.path).inserted, let bundle = Bundle(url: url) else { continue }
                    let bid = bundle.bundleIdentifier
                    if let bid, bid.hasPrefix("com.apple.") { continue } // never offer to remove Apple apps
                    let candidates = [bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
                                      bundle.object(forInfoDictionaryKey: "CFBundleName") as? String]
                    let name = candidates.compactMap { $0?.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty }
                        ?? url.deletingPathExtension().lastPathComponent
                    let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                    result.append(AppInfo(url: url, name: name, bundleID: bid, version: version, size: 0))
                } else if depth < 1, (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    visit(url, depth: depth + 1) // e.g. /Applications/Utilities or vendor folders
                }
            }
        }
        roots.forEach { visit($0, depth: 0) }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Looks for support files the app left in ~/Library, matched by bundle ID or exact app name.
    nonisolated static func findLeftovers(for app: AppInfo) -> [Leftover] {
        let folders = [
            "Application Support", "Caches", "Preferences", "Containers", "Group Containers",
            "Saved Application State", "Logs", "HTTPStorages", "WebKit", "Cookies",
            "LaunchAgents", "Application Scripts"
        ]
        let bid = app.bundleID?.lowercased()
        let appName = app.name.lowercased()
        let fileName = app.url.deletingPathExtension().lastPathComponent.lowercased()
        // Short or generic names would match unrelated folders, so only use names of 4+ characters.
        let names = Set([appName, fileName].filter { $0.count >= 4 })

        var result: [Leftover] = []
        let fda = FS.hasFullDiskAccess()
        for folder in folders {
            let dir = FS.library.appendingPathComponent(folder)
            for child in FS.children(of: dir) {
                let n = child.lastPathComponent.lowercased()
                var match = names.contains(n)
                if let bid {
                    match = match
                        || n == bid
                        || n.hasPrefix(bid + ".")      // com.foo.app.plist, com.foo.app.savedState, helpers
                        || n.hasSuffix("." + bid)      // TEAMID.com.foo.app group containers
                }
                if match {
                    result.append(Leftover(url: child, size: FS.safeSize(of: child, fullDiskAccess: fda), location: folder))
                }
            }
        }
        return result.sorted { $0.size > $1.size }
    }
}
