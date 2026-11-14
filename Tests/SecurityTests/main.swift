// Security regression tests for ProtoArt Dandelion.
// Run with "Run Security Tests.command". Compiled together with the app's own source files,
// so they test the real code. Everything happens in a temporary folder; nothing of yours is touched.
import Foundation
import AppKit

var failures = 0
func check(_ ok: Bool, _ name: String) {
    print(ok ? "  PASS  \(name)" : "  FAIL  \(name)")
    if !ok { failures += 1 }
}

let fm = FileManager.default
// realpath, not resolvingSymlinksInPath: the latter turns /private/var into /var, which is itself a link.
let realTemp = String(cString: realpath(NSTemporaryDirectory(), nil))
let base = URL(fileURLWithPath: realTemp).appendingPathComponent("dandelion-security-tests-\(getpid())")
check(!FS.passesThroughSymlink(base.appendingPathComponent("x")), "a real folder under /private/var is not mistaken for a link")
check(FS.passesThroughSymlink(URL(fileURLWithPath: "/var/folders/x")), "/var (a link to /private/var) is recognised as a link")
try? fm.removeItem(at: base)
try! fm.createDirectory(at: base, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: base) }

func mkdir(_ path: String) -> URL {
    let u = base.appendingPathComponent(path); try! fm.createDirectory(at: u, withIntermediateDirectories: true); return u
}
func touch(_ path: String, bytes: Int = 4096) -> URL {
    let u = base.appendingPathComponent(path)
    try! fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! Data(repeating: 7, count: bytes).write(to: u); return u
}

print("Removal through symlinked folders")
do {
    _ = mkdir("documents")
    let precious = touch("documents/precious.txt")
    try! fm.createSymbolicLink(at: base.appendingPathComponent("cache-link"), withDestinationURL: base.appendingPathComponent("documents"))
    let r = FS.remove([(url: base.appendingPathComponent("cache-link/precious.txt"), size: 1)], permanently: true)
    check(fm.fileExists(atPath: precious.path), "a file reached through a symlinked folder is NOT deleted")
    check(r.removed == 0 && r.refused.count == 1, "it is reported as refused, not removed")
    let r2 = FS.remove([(url: base.appendingPathComponent("cache-link"), size: 0)], permanently: true)
    check(r2.removed == 1 && !FS.isSymlink(base.appendingPathComponent("cache-link")), "the link itself can still be removed")
    check(fm.fileExists(atPath: precious.path), "removing the link leaves its target alone")
}

print("Protected folders")
do {
    let home = mkdir("home/tester")
    for name in ["Documents", "Library", "Desktop", "Downloads"] { _ = mkdir("home/tester/\(name)") }
    _ = touch("home/tester/Documents/old.txt")
    for p in ["/", "/System", "/Library", "/Applications", "/Applications/Utilities", "/Users", "/usr", "/private",
              "/Users/Shared", "/Users/someone", "/Volumes/External", "/Applications/../Applications/",
              "/Users/someone/../../Applications", "/./Library/."] {
        check(FS.isProtected(URL(fileURLWithPath: p), home: home), "\(p) is protected")
    }
    for p in ["Documents", "Library", "Desktop", ""] {
        check(FS.isProtected(home.appendingPathComponent(p), home: home), "home/\(p.isEmpty ? "(itself)" : p) is protected")
    }
    for u in [home.appendingPathComponent("Documents/old.txt"), home.appendingPathComponent("Library/Caches"),
              URL(fileURLWithPath: "/Applications/Some App.app"), URL(fileURLWithPath: "/Library/Caches/x")] {
        check(!FS.isProtected(u, home: home), "\(u.path.replacingOccurrences(of: base.path, with: "…")) is NOT protected")
    }
    let r = FS.remove([(url: home.appendingPathComponent("Documents"), size: 1),
                       (url: home, size: 1)], permanently: true, home: home)
    check(fm.fileExists(atPath: home.appendingPathComponent("Documents/old.txt").path), "remove() refuses the Documents folder itself")
    check(r.refused.count == 2 && r.removed == 0, "both protected items reported as refused")
    let r2 = FS.remove([(url: home.appendingPathComponent("Documents/old.txt"), size: 1)], permanently: true, home: home)
    check(r2.removed == 1, "a file inside Documents can still be removed")
}

print("Junk scan does not follow a symlinked cache folder")
do {
    _ = touch("junk-target/big-document.pages", bytes: 64_000)
    try! fm.createSymbolicLink(at: base.appendingPathComponent("fake-cache"), withDestinationURL: base.appendingPathComponent("junk-target"))
    _ = touch("real-cache/com.example.cache", bytes: 64_000)
    let linked = JunkCategory(id: "caches", name: "t", detail: "", symbol: "", roots: [base.appendingPathComponent("fake-cache")])
    let real = JunkCategory(id: "caches", name: "t", detail: "", symbol: "", roots: [base.appendingPathComponent("real-cache")])
    check(JunkModel.scan(linked, fullDiskAccess: true, running: [], ownCache: nil).isEmpty, "symlinked root lists nothing")
    check(JunkModel.scan(real, fullDiskAccess: true, running: [], ownCache: nil).count == 1, "a normal cache folder still lists its items")
}

print("Uninstaller leftovers stay with their own app")
do {
    let lib = mkdir("Library")
    for p in ["Application Support/com.example.app", "Application Support/com.example.app.beta",
              "Preferences/com.example.app.plist", "Preferences/com.example.app.beta.plist",
              "Caches/com.example.app", "Caches/com.example.app.beta",
              "Group Containers/ABCDE12345.com.example.app.beta"] {
        _ = touch("Library/\(p)/x")
    }
    let app = AppInfo(url: URL(fileURLWithPath: "/Applications/Example.app"), name: "Example",
                      bundleID: "com.example.app", version: "1", size: 0)
    let found = Set(UninstallerModel.findLeftovers(for: app, otherBundleIDs: ["com.example.app.beta"], library: lib)
        .map { $0.url.lastPathComponent })
    check(found == ["com.example.app", "com.example.app.plist"], "only Example's own files are offered (got \(found.sorted()))")
    let none = Set(UninstallerModel.findLeftovers(for: app, otherBundleIDs: [], library: lib).map { $0.url.lastPathComponent })
    check(none.contains("com.example.app.beta"), "without a sibling app installed, matching still works as before")
}

print("Finder fallback quoting (AppleScript)")
do {
    let marker = "/tmp/dandelion-injection-\(getpid())"
    let names = ["quote\"here", "back\\slash", "x\" & (do shell script \"touch \(marker)\") & \"", "line\nbreak", "ünïcødé ✓"]
    for name in names {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", "return \(FS.appleScriptString(name))"]
        let out = Pipe(); p.standardOutput = out; p.standardError = out
        try! p.run(); p.waitUntilExit()
        var s = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        if s.hasSuffix("\n") { s.removeLast() }
        check(s == name, "file name \(name.debugDescription) stays plain text")
    }
    check(!fm.fileExists(atPath: marker), "the injected command never ran")
}

print(failures == 0 ? "\nAll security tests passed." : "\n\(failures) security test(s) FAILED.")
exit(failures == 0 ? 0 : 1)
