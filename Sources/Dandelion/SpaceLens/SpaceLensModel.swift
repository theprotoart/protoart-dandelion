import Foundation
import AppKit

struct LensNode: Identifiable, Hashable, Sendable {
    var id: URL { url }
    let url: URL
    let isDirectory: Bool
    var size: Int64?   // nil while measuring
    var name: String { url.lastPathComponent }
}

@MainActor
final class SpaceLensModel: ObservableObject {
    @Published var path: [URL] = []
    @Published var nodes: [LensNode] = []
    @Published var isMeasuring = false
    @Published var status: String?
    /// Items ticked for removal (like CleanMyMac's Space Lens checkboxes).
    @Published var selection: Set<URL> = []

    var selectedSize: Int64 { nodes.filter { selection.contains($0.url) }.compactMap(\.size).reduce(0, +) }

    func toggle(_ node: LensNode) {
        if selection.contains(node.url) { selection.remove(node.url) } else { selection.insert(node.url) }
    }

    func trashSelected() async {
        let targets = nodes.filter { selection.contains($0.url) }.map { (url: $0.url, size: $0.size ?? 0) }
        guard !targets.isEmpty else { return }
        let result = await Task.detached(priority: .userInitiated) { FS.remove(targets, permanently: false) }.value
        let gone = Set(targets.map(\.url).filter { !FS.exists($0) })
        nodes.removeAll { gone.contains($0.url) }
        for url in gone { cache.removeValue(forKey: url) }
        for ancestor in path { cache.removeValue(forKey: ancestor) }
        selection.subtract(gone)
        status = result.summary + " Everything went to the Trash."
    }

    /// Sizes already measured this session, so going back up is instant.
    private var cache: [URL: Int64] = [:]
    private var task: Task<Void, Never>?

    var current: URL? { path.last }
    var total: Int64 { nodes.compactMap(\.size).reduce(0, +) }
    var largest: Int64 { nodes.compactMap(\.size).max() ?? 0 }

    func startIfNeeded() {
        if path.isEmpty { setRoot(FS.home) }
    }

    func setRoot(_ url: URL) {
        path = [url]
        load()
    }

    func open(_ node: LensNode) {
        guard node.isDirectory else { FS.reveal([node.url]); return }
        path.append(node.url)
        load()
    }

    func goTo(_ index: Int) {
        guard index < path.count else { return }
        path = Array(path.prefix(index + 1))
        load()
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Explore"
        // Non-blocking: the window keeps running while the panel is open.
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in self?.setRoot(url) }
        }
    }

    func rescan() {
        cache.removeAll()
        load()
    }

    func load() {
        task?.cancel()
        guard let dir = current else { return }
        status = nil
        selection = []

        nodes = FS.children(of: dir).map { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey])
            let isDir = values?.isDirectory == true && values?.isPackage != true && values?.isSymbolicLink != true
            return LensNode(url: url, isDirectory: isDir, size: cache[url])
        }
        sortNodes()

        let pending = nodes.filter { $0.size == nil }.map(\.url)
        guard !pending.isEmpty else { isMeasuring = false; return }
        isMeasuring = true

        task = Task {
            await withTaskGroup(of: (URL, Int64).self) { group in
                for url in pending {
                    group.addTask(priority: .userInitiated) { (url, FS.allocatedSize(of: url)) }
                }
                var updates = 0
                for await (url, size) in group {
                    if Task.isCancelled { group.cancelAll(); break }
                    cache[url] = size
                    if let i = nodes.firstIndex(where: { $0.url == url }) { nodes[i].size = size }
                    updates += 1
                    if updates % 8 == 0 { sortNodes() }
                }
            }
            guard !Task.isCancelled else { return }
            sortNodes()
            isMeasuring = false
        }
    }

    func trash(_ node: LensNode) async {
        let target = [(url: node.url, size: node.size ?? 0)]
        let result = await Task.detached(priority: .userInitiated) { FS.remove(target, permanently: false) }.value
        if result.failures.isEmpty {
            nodes.removeAll { $0.url == node.url }
            // Parent folders are now smaller; forget their cached sizes.
            for ancestor in path { cache.removeValue(forKey: ancestor) }
            cache.removeValue(forKey: node.url)
        }
        status = result.summary
    }

    private func sortNodes() {
        nodes.sort { ($0.size ?? -1) > ($1.size ?? -1) }
    }
}
