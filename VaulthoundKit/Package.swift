// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VaulthoundKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VaulthoundModels", targets: ["VaulthoundModels"]),
        .library(name: "VaulthoundCore", targets: ["VaulthoundCore"]),
        .library(name: "VaulthoundSecurity", targets: ["VaulthoundSecurity"]),
    ],
    targets: [
        .target(name: "VaulthoundModels"),
        .target(name: "VaulthoundCore", dependencies: ["VaulthoundModels"]),
        .target(name: "VaulthoundSecurity", dependencies: ["VaulthoundModels"]),
        .testTarget(name: "VaulthoundCoreTests", dependencies: ["VaulthoundCore"]),
        .testTarget(name: "VaulthoundSecurityTests", dependencies: ["VaulthoundSecurity"]),
    ]
)
