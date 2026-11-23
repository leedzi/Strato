// swift-tools-version:5.9
// This manifest exists so the platform-independent logic in Core/ can be unit-tested with a plain
// `swift test` on macOS. The app itself is built from project.yml (XcodeGen), which compiles the
// same Core/ sources directly into the app and widget targets.
import PackageDescription

let package = Package(
    name: "StratoCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "StratoCore", targets: ["StratoCore"])
    ],
    targets: [
        .target(name: "StratoCore", path: "Core"),
        .testTarget(name: "StratoCoreTests", dependencies: ["StratoCore"], path: "Tests/StratoCoreTests")
    ]
)
