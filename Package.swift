// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Dots", platforms: [.macOS(.v13)], targets: [
    .executableTarget(name: "Dots", path: "Sources")
])
