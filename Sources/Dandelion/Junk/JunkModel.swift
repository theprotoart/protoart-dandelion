import Foundation
import AppKit

struct JunkCategory: Identifiable, Sendable {
    let id: String
    let name: String
    let detail: String
    let symbol: String
    let roots: [URL]
    /// When set, only direct children with one of these file extensions count (e.g. disk images).
    var extensions: [String]? = nil
    /// Items in this category are always deleted outright (e.g. emptying the Trash).
    var alwaysPermanent = false
    /// Pre-select this category after a scan.
    var selectedByDefault = true

    static var all: [JunkCategory] {
        let lib = FS.library
        let home = FS.home
        let dev = lib.appendingPathComponent("Developer")
        return [
            JunkCategory(
                id: "caches", name: "User Caches",
                detail: "Temporary data apps rebuild on their own (~/Library/Caches)",
                symbol: "shippingbox", roots: [lib.appendingPathComponent("Caches")]),
            JunkCategory(
                id: "logs", name: "Logs & Crash Reports",
                detail: "App logs and diagnostic reports",
                symbol: "doc.plaintext",
                roots: [lib.appendingPathComponent("Logs")]),
            JunkCategory(
                id: "xcode", name: "Xcode Junk",
                detail: "DerivedData, old device support files and simulator caches",
                symbol: "hammer",
                roots: [
                    dev.appendingPathComponent("Xcode/DerivedData"),
                    dev.appendingPathComponent("Xcode/iOS DeviceSupport"),
                    dev.appendingPathComponent("Xcode/watchOS DeviceSupport"),
                    dev.appendingPathComponent("CoreSimulator/Caches")
                ]),
            JunkCategory(
                id: "devcaches", name: "Developer Caches",
                detail: "npm, Gradle and Swift package download caches",
                symbol: "cube.box",
                roots: [
                    home.appendingPathComponent(".npm/_cacache"),
                    home.appendingPathComponent(".gradle/caches"),
                    lib.appendingPathComponent("org.swift.swiftpm/cache")
                ]),
            JunkCategory(
                id: "mail", name: "Mail Attachments",
                detail: "Copies of attachments Mail saved when you opened them",
                symbol: "paperclip",
                roots: [lib.appendingPathComponent("Containers/com.apple.mail/Data/Library/Mail Downloads")]),
            JunkCategory(
                id: "installers", name: "Old Installers",
                detail: "Disk images and installer packages in Downloads",
                symbol: "opticaldiscdrive",
                roots: [home.appendingPathComponent("Downloads")],
                extensions: ["dmg", "pkg", "mpkg", "iso", "xip"],
                selectedByDefault: false),
            JunkCategory(
                id: "trash", name: "Trash",
                detail: "Files already in your Trash — these are deleted permanently",
                symbol: "trash", roots: [home.appendingPathComponent(".Trash")],
                alwaysPermanent: true, selectedByDefault: false)
        ]
    }
}

struct JunkItem: Identifiable, Hashable, Sendable {
    var id: URL { url }
    let url: URL
    let size: Int64
    let categoryID: String
    /// Belongs to an app that is running right now (left unticked, like CleanMyMac does).
    var inUse = false
}

@MainActor
final class JunkModel: ObservableObject {
    let categories = JunkCategory.all

    @Published var items: [String: [JunkItem]] = [:]
    @Published var selected: Set<URL> = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var hasScanned = false
    @Published var moveToTrash = true
    @Published var status: String?
    /// macOS is hiding protected folders (Trash, Mail, other apps' containers) from us.
    @Published var needsFullDiskAccess = false

    var totalFound: Int64 { allItems.reduce(0) { $0 + $1.size } }

    var allItems: [JunkItem] { categories.flatMap { items[$0.id] ?? [] } }

    var selectedSize: Int64 {
        allItems.filter { selected.contains($0.url) }.reduce(0) { $0 + $1.size }
    }

    func size(of category: JunkCategory) -> Int64 {
        (items[category.id] ?? []).reduce(0) { $0 + $1.size }
    }

    /// Categories still being read (one can wait on a macOS permission dialog without holding up the rest).
    @Published var pendingCategories: Set<String> = []

    func scan() async {
        isScanning = true
        status = "Scanning…"
        let cats = categories
        let ownCache = Bundle.main.bundleIdentifier
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier?.lowercased() })
        let fda = FS.hasFullDiskAccess()
        needsFullDiskAccess = !fda
        items = [:]
        pendingCategories = Set(cats.map(\.id))

        // If a folder is waiting on a macOS permission dialog (Downloads, for example), say so.
        let watchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard let self, !Task.isCancelled, self.isScanning, !self.pendingCategories.isEmpty else { return }
            let names = self.categories.filter { self.pendingCategories.contains($0.id) }.map(\.name).joined(separator: ", ")
            self.status = "Waiting for macOS permission to read \(names). If a dialog asks, choose Allow."
        }

        await withTaskGroup(of: (String, [JunkItem]).self) { group in
            for cat in cats {
                group.addTask(priority: .userInitiated) {
                    (cat.id, Self.scan(cat, fullDiskAccess: fda, running: running, ownCache: ownCache))
                }
            }
            for await (id, list) in group {
                items[id] = list
                pendingCategories.remove(id)
            }
        }
        watchdog.cancel()

        selected = Set(categories.filter(\.selectedByDefault).flatMap { items[$0.id] ?? [] }.filter { !$0.inUse }.map(\.url))
        isScanning = false
        hasScanned = true
        status = "Found \(FS.format(totalFound)) of junk."
    }

    nonisolated static func scan(_ cat: JunkCategory, fullDiskAccess fda: Bool, running: Set<String>, ownCache: String?) -> [JunkItem] {
        var list: [JunkItem] = []
        for root in cat.roots {
            // Mail's folder lives in its private container: only with Full Disk Access (no prompt, no stall).
            if !fda && FS.isOtherAppData(root) { continue }
            for child in FS.children(of: root) {
                if let ownCache, child.lastPathComponent == ownCache { continue }
                if let exts = cat.extensions, !exts.contains(child.pathExtension.lowercased()) { continue }
                let size = FS.allocatedSize(of: child)
                let name = child.lastPathComponent.lowercased()
                let inUse = cat.id == "caches" && running.contains { name == $0 || name.hasPrefix($0 + ".") }
                if size > 0 { list.append(JunkItem(url: child, size: size, categoryID: cat.id, inUse: inUse)) }
            }
        }
        return list.sorted { $0.size > $1.size }
    }

    func clean() async {
        let chosen = allItems.filter { selected.contains($0.url) }
        guard !chosen.isEmpty else { return }
        isCleaning = true
        let permanentCats = Set(categories.filter(\.alwaysPermanent).map(\.id))
        let trashFirst = moveToTrash

        let result = await Task.detached(priority: .userInitiated) { () -> FS.RemovalResult in
            let permanent = chosen.filter { permanentCats.contains($0.categoryID) || !trashFirst }
            let toTrash = chosen.filter { !permanentCats.contains($0.categoryID) && trashFirst }
            var r = FS.remove(permanent.map { (url: $0.url, size: $0.size) }, permanently: true)
            let t = FS.remove(toTrash.map { (url: $0.url, size: $0.size) }, permanently: false)
            r.removed += t.removed
            r.bytes += t.bytes
            r.failures += t.failures
            return r
        }.value

        isCleaning = false
        await scan()
        status = result.summary + (trashFirst ? " Empty the Trash to get the space back." : "")
    }

    // MARK: Selection helpers

    func isSelected(_ category: JunkCategory) -> Bool {
        let list = items[category.id] ?? []
        return !list.isEmpty && list.allSatisfy { selected.contains($0.url) }
    }

    func setSelected(_ category: JunkCategory, _ on: Bool) {
        for item in items[category.id] ?? [] {
            if on { selected.insert(item.url) } else { selected.remove(item.url) }
        }
    }

    func toggle(_ url: URL, _ on: Bool) {
        if on { selected.insert(url) } else { selected.remove(url) }
    }
}
