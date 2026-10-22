// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Pawprints",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "MysteryKit", targets: ["MysteryKit"]),
        .executable(name: "Pawprints", targets: ["MysteryApp"]),
        .executable(name: "pawprints-cli", targets: ["mystery-cli"]),
        .executable(name: "PawprintsPainter", targets: ["PawprintsPainter"]),
    ],
    targets: [
        .target(name: "MysteryKit"),
        .executableTarget(name: "MysteryApp", dependencies: ["MysteryKit"]),
        .executableTarget(name: "mystery-cli", dependencies: ["MysteryKit"]),
        .executableTarget(name: "PawprintsPainter", dependencies: ["MysteryKit"]),
        .testTarget(name: "MysteryKitTests", dependencies: ["MysteryKit"]),
    ]
)
