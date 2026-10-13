// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EDScan",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Scanner core shared with OpenCoolscan. New scanner features go into CoolscanKit.
        .package(url: "https://github.com/EDalhus/CoolscanKit.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "EDScan",
            dependencies: ["CoolscanKit"],
            path: "Sources/EDScan"
        )
    ]
)
