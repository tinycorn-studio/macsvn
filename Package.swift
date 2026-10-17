// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SVNDemo",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SVNCore", path: "Sources/SVNCore"),
        .executableTarget(name: "SVNDemo", dependencies: ["SVNCore"], path: "Sources/SVNDemo"),
        .executableTarget(name: "svncli", dependencies: ["SVNCore"], path: "Sources/svncli")
    ]
)
