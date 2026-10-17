// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SVNDemo",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "SVNDemo", path: "Sources/SVNDemo")
    ]
)
