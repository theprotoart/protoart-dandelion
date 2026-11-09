// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Dandelion",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Dandelion",
            path: "Sources/Dandelion",
            swiftSettings: [.unsafeFlags(["-Osize"])]
        )
    ]
)
