import Foundation
import AppKit

/// File-system helpers shared by every feature.
enum FS {
    static var fm: FileManager { FileManager.default }
    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    static var library: URL { home.appendingPathComponent("Library", isDirectory: true) }

    private static let sizeKeys: Set<URLResourceKey> = [
        .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey
    ]

    /// Bytes on disk for a file or a whole directory tree (symlinks are not followed).
    static func allocatedSize(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: sizeKeys) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        if values.isDirectory != true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(sizeKeys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let file as URL in enumerator {
            if Task.isCancelled { break }
            guard let v = try? file.resourceValues(forKeys: sizeKeys), v.isRegularFile == true else { continue }
            total += Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
        }
        return total
    }

    /// Immediate children of a folder (including hidden ones). Empty if unreadable.
    static func children(of url: URL) -> [URL] {
        (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])) ?? []
    }

    static func exists(_ url: URL) -> Bool { fm.fileExists(atPath: url.path) }

    static func format(_ bytes: Int64) -> String {
        if bytes <= 0 { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Other apps' private data (sandbox containers). Reading inside these without Full Disk Access makes
    /// macOS show its "access data from other apps" prompt and stalls the scan until it is answered.
    static func isOtherAppData(_ url: URL) -> Bool {
        let p = url.path
        return p.contains("/Library/Containers/") || p.contains("/Library/Group Containers/")
    }

    /// Size, but only where we can look without triggering a privacy prompt; 0 = unknown.
    static func safeSize(of url: URL, fullDiskAccess: Bool) -> Int64 {
        if !fullDiskAccess && isOtherAppData(url) { return 0 }
        return allocatedSize(of: url)
    }

    /// Full Disk Access test: the Trash and Safari's folder can only be listed with it.
    static func hasFullDiskAccess() -> Bool {
        for path in [".Trash", "Library/Safari", "Library/Containers/com.apple.mail"] {
            let url = home.appendingPathComponent(path)
            guard fm.fileExists(atPath: url.path) else { continue }
            return (try? fm.contentsOfDirectory(atPath: url.path)) != nil
        }
        return true
    }

    /// macOS has no pop-up for Full Disk Access: it can only be switched on in System Settings.
    /// Open that page and show Dandelion in Finder so it can be dragged into the list.
    static func openFullDiskAccessSettings() {
        openPrivacyPane("Privacy_AllFiles")
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    /// "App Management" lets an app change or delete other apps (macOS 13+).
    static func openAppManagementSettings() {
        openPrivacyPane("Privacy_AppBundles")
    }

    private static func openPrivacyPane(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    static func reveal(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    static func icon(for url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    struct RemovalResult: Sendable {
        var removed = 0
        var bytes: Int64 = 0
        var failures: [String] = []
        /// Some items needed Finder (admin-owned apps, protected folders).
        var viaFinder = 0
        /// The user cancelled Finder's password prompt.
        var cancelled = false

        var summary: String {
            var s = removed == 0 && failures.isEmpty ? "Nothing to remove."
                : "Removed \(removed) item\(removed == 1 ? "" : "s")\(bytes > 0 ? " (\(FS.format(bytes)))" : "")."
            if !failures.isEmpty {
                s += cancelled
                    ? " \(failures.count) left in place: the password prompt was cancelled."
                    : " \(failures.count) could not be removed. Turn on Full Disk Access and App Management for Dandelion in System Settings, then try again."
            }
            return s
        }
    }

    /// Moves items to the Trash (default) or deletes them permanently.
    /// Anything Dandelion may not move itself (apps installed by an admin, apps protected by
    /// macOS "App Management") is handed to Finder, which asks for your password when needed.
    static func remove(_ items: [(url: URL, size: Int64)], permanently: Bool) -> RemovalResult {
        var result = RemovalResult()
        var blocked: [(url: URL, size: Int64)] = []
        for item in items {
            do {
                if permanently {
                    try fm.removeItem(at: item.url)
                } else {
                    try fm.trashItem(at: item.url, resultingItemURL: nil)
                }
                result.removed += 1
                result.bytes += item.size
            } catch {
                blocked.append(item)
            }
        }
        guard !blocked.isEmpty else { return result }

        // Second try through Finder (moves to the Trash; Finder asks for an admin password if needed).
        let cancelled = trashViaFinder(blocked.map(\.url))
        for item in blocked {
            if !fm.fileExists(atPath: item.url.path) {
                result.removed += 1
                result.bytes += item.size
                result.viaFinder += 1
            } else {
                result.failures.append(item.url.lastPathComponent)
            }
        }
        result.cancelled = cancelled
        return result
    }

    /// Asks Finder to move the items to the Trash. Returns true if the user cancelled.
    /// The first time, macOS asks once whether Dandelion may control Finder.
    @discardableResult
    static func trashViaFinder(_ urls: [URL]) -> Bool {
        let list = urls.map { url -> String in
            let path = url.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            return "(POSIX file \"\(path)\" as alias)"
        }.joined(separator: ", ")
        let script = "tell application \"Finder\" to delete {\(list)}"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        let err = Pipe()
        p.standardError = err
        p.standardOutput = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return false }
        p.waitUntilExit()
        let message = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return message.contains("-128")   // user cancelled
    }
}
