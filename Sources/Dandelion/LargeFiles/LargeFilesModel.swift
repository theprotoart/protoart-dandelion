import Foundation
import UniformTypeIdentifiers
import CoreServices
import AppKit

enum FileKind: String, CaseIterable, Sendable {
    case all = "All", video = "Video", audio = "Audio", images = "Images", archives = "Archives", docs = "Docs", other = "Other"

    static func of(_ url: URL) -> FileKind {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return .other }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .image) { return .images }
        if type.conforms(to: .archive) || type.conforms(to: .diskImage)
            || ["dmg", "pkg", "iso", "xip", "zip", "rar", "7z"].contains(url.pathExtension.lowercased()) { return .archives }
        if type.conforms(to: .pdf) || type.conforms(to: .presentation) || type.conforms(to: .spreadsheet)
            || type.conforms(to: .text) || type.conforms(to: .compositeContent) { return .docs }
        return .other
    }
}

struct FoundFile: Identifiable, Hashable, Sendable {
    var id: URL { url }
    let url: URL
    let size: Int64
    let modified: Date
    /// When you last opened it (Spotlight's "Last opened" date), or when it last changed if macOS never recorded an open.
    let lastOpened: Date
    let kind: FileKind

    var name: String { url.lastPathComponent }
    var folder: String { url.deletingLastPathComponent().path.replacingOccurrences(of: FS.home.path, with: "~") }
}

@MainActor
final class LargeFilesModel: ObservableObject {
    @Published var root: URL = FS.home
    @Published var minSizeMB: Double = 100
    /// 0 means "any age".
    @Published var olderThanDays: Int = 0
    @Published var includeHidden = false
    @Published var files: [FoundFile] = []
    @Published var kind: FileKind = .all
    var visibleFiles: [FoundFile] { kind == .all ? files : files.filter { $0.kind == kind } }
    @Published var selection: Set<URL> = []
    enum SortKey: Hashable { case size, name, lastOpened }
    @Published var sortKey: SortKey = .size { didSet { resort() } }
    @Published var isScanning = false
    @Published var hasScanned = false
    @Published var scannedCount = 0
    @Published var status: String?

    private var scanTask: Task<Void, Never>?

    var selectedSize: Int64 {
        files.filter { selection.contains($0.url) }.reduce(0) { $0 + $1.size }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = root
        panel.prompt = "Choose"
        // Non-blocking: the window keeps running while the panel is open.
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in self?.root = url }
        }
    }

    func scan() {
        scanTask?.cancel()
        files = []
        selection = []
        scannedCount = 0
        isScanning = true
        status = nil

        let root = self.root
        let minBytes = Int64(minSizeMB * 1_000_000)
        let cutoff: Date? = olderThanDays > 0
            ? Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date())
            : nil
        let options: FileManager.DirectoryEnumerationOptions = includeHidden
            ? [.skipsPackageDescendants]
            : [.skipsPackageDescendants, .skipsHiddenFiles]

        scanTask = Task {
            let stream = AsyncStream<(batch: [FoundFile], scanned: Int)> { continuation in
                let worker = Task.detached(priority: .userInitiated) {
                    Self.walk(root: root, options: options, minBytes: minBytes, cutoff: cutoff) { batch, scanned in
                        continuation.yield((batch, scanned))
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in worker.cancel() }
            }

            for await update in stream {
                files.append(contentsOf: update.batch)
                scannedCount = update.scanned
            }
            resort()
            isScanning = false
            hasScanned = true
            let total = files.reduce(0) { $0 + $1.size }
            status = "\(files.count) files, \(FS.format(total)) total."
        }
    }

    /// Synchronous directory walk; reports matches in batches. Stops when the surrounding task is cancelled.
    nonisolated static func walk(root: URL, options: FileManager.DirectoryEnumerationOptions, minBytes: Int64,
                                 cutoff: Date?, report: ([FoundFile], Int) -> Void) {
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
                                      .contentModificationDateKey, .contentAccessDateKey]
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
                                                     options: options, errorHandler: { _, _ in true }) else { return }
        var batch: [FoundFile] = []
        var scanned = 0
        while let url = e.nextObject() as? URL {
            if Task.isCancelled { break }
            scanned += 1
            guard let v = try? url.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { continue }
            let size = Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
            guard size >= minBytes else { continue }
            let modified = v.contentModificationDate ?? .distantPast
            // Spotlight's "last opened" date (what Finder shows). The access date is useless here:
            // backups and indexing touch files all the time.
            var opened = modified
            if let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL),
               let used = MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date {
                opened = max(used, modified)
            }
            if let cutoff, opened > cutoff { continue }
            batch.append(FoundFile(url: url, size: size, modified: modified, lastOpened: opened, kind: FileKind.of(url)))
            if batch.count >= 50 || scanned % 5000 == 0 { report(batch, scanned); batch = [] }
        }
        report(batch, scanned)
    }

    func cancel() {
        scanTask?.cancel()
        isScanning = false
    }

    func resort() {
        switch sortKey {
        case .size: files.sort { $0.size > $1.size }
        case .name: files.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .lastOpened: files.sort { $0.lastOpened < $1.lastOpened }
        }
    }

    func removeSelected() async {
        let targets = files.filter { selection.contains($0.url) }.map { (url: $0.url, size: $0.size) }
        let result = await Task.detached(priority: .userInitiated) { FS.remove(targets, permanently: false) }.value
        files.removeAll { !FS.exists($0.url) }
        selection = []
        status = result.summary + " Items went to the Trash."
    }
}
