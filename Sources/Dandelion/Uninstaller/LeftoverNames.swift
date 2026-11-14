import Foundation

/// Turns a bundle-ID folder name such as "com.topazlabs.TopazVideoEnhanceAI.savedState" into something a person
/// recognises: app "Topaz Video Enhance AI", maker "Topaz Labs". The app itself is gone, so macOS can't tell us its
/// name; this works from the ID alone, plus a short list of IDs whose names can't be guessed.
enum LeftoverNames {
    struct Name: Equatable, Sendable { let app: String; let vendor: String }

    /// IDs whose last part is a code rather than a name.
    static let known: [String: String] = [
        "com.dxo.cep4.app": "Color Efex Pro 4",
        "com.dxo.cep5.app": "Color Efex Pro 5",
        "com.dxo.aep2.app": "Analog Efex Pro 2",
        "com.dxo.hdr2.app": "HDR Efex Pro 2",
        "com.dxo.viveza3.app": "Viveza 3",
        "com.dxo.nik.installer": "Nik Collection Installer",
        "com.dxo.nik3installer": "Nik Collection 3 Installer",
        "org.python.idle": "IDLE",
        "net.java.openjdk.java": "Java (OpenJDK)",
        "com.bitrock.appinstaller": "BitRock Installer",
        "com.tinyspeck.slackmacgap": "Slack"
    ]

    /// Reverse-domain makers whose proper names aren't just the word capitalised.
    static let vendors: [String: String] = [
        "dxo": "DxO", "izotope": "iZotope", "topazlabs": "Topaz Labs", "wavesaudio": "Waves Audio",
        "encsecurity": "ENC Security", "bitrock": "BitRock", "openjdk": "OpenJDK", "java": "Java",
        "macpaw": "MacPaw", "jetbrains": "JetBrains", "github": "GitHub", "obsproject": "OBS Project",
        "videolan": "VideoLAN", "tinyspeck": "Slack", "native-instruments": "Native Instruments",
        "blackmagic-design": "Blackmagic Design", "uaudio": "Universal Audio", "fabfilter": "FabFilter",
        "valvesoftware": "Valve", "nektony": "Nektony", "plugin-alliance": "Plugin Alliance",
        "microsoft": "Microsoft", "google": "Google", "adobe": "Adobe", "apple": "Apple"
    ]

    private static let topLevel: Set<String> = ["com", "org", "net", "io", "de", "co", "uk", "fr", "jp", "app", "dev",
                                                "me", "us", "ca", "eu", "info", "biz", "ch", "nl", "se", "it", "cc"]
    private static let noise: Set<String> = ["app", "application", "mac", "macos", "osx", "savedstate", "plist"]
    private static let generic: Set<String> = ["installer", "uninstaller", "helper", "agent", "launcher", "updater",
                                               "daemon", "service", "extension", "plugin", "plugins"]

    static func name(forFolder folder: String) -> Name {
        var id = folder
        for suffix in [".savedState", ".plist"] where id.hasSuffix(suffix) { id = String(id.dropLast(suffix.count)) }
        var parts = id.split(separator: ".").map(String.init)
        // Team ID prefix ("ABCDE12345.")
        if let first = parts.first, first.count == 10, first.allSatisfy({ $0.isUppercase || $0.isNumber }) {
            parts.removeFirst()
        }
        let fullID = parts.joined(separator: ".").lowercased()
        if parts.first.map({ topLevel.contains($0.lowercased()) }) == true { parts.removeFirst() }
        guard let vendorKey = parts.first else { return Name(app: folder, vendor: "Unknown maker") }
        let vendor = vendors[vendorKey.lowercased()] ?? humanize(vendorKey)
        if let hit = known[fullID] { return Name(app: hit, vendor: vendor) }

        var rest = Array(parts.dropFirst()).filter { !noise.contains($0.lowercased()) && !$0.allSatisfy(\.isNumber) }
        if rest.isEmpty { rest = [vendorKey] }
        var app = humanize(rest.last!)
        if generic.contains(rest.last!.lowercased()) {
            app = rest.count >= 2 ? humanize(rest[rest.count - 2]) + " " + app : vendor + " " + app
        }
        return Name(app: app, vendor: vendor)
    }

    /// "TopazVideoEnhanceAI" -> "Topaz Video Enhance AI", "NEUTRON3" -> "Neutron 3", "Funter-SII" -> "Funter SII".
    static func humanize(_ raw: String) -> String {
        var words: [String] = []
        var current = ""
        let chars = Array(raw)
        for (i, c) in chars.enumerated() {
            if c == "-" || c == "_" || c == " " {
                if !current.isEmpty { words.append(current); current = "" }
                continue
            }
            if let prev = current.last {
                let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
                let startsWord = (prev.isLowercase && c.isUppercase)
                    || (prev.isLetter && c.isNumber) || (prev.isNumber && c.isLetter)
                    || (prev.isUppercase && c.isUppercase && (next?.isLowercase ?? false))
                if startsWord { words.append(current); current = "" }
            }
            current.append(c)
        }
        if !current.isEmpty { words.append(current) }
        return words.map { w in
            if w.allSatisfy({ $0.isUppercase || $0.isNumber }) && w.count > 3 { return w.prefix(1) + w.dropFirst().lowercased() }
            return w.prefix(1).uppercased() + w.dropFirst()
        }.joined(separator: " ")
    }
}
