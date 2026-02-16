// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftMod",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(name: "SwiftModCore", targets: ["SwiftModCore"]),
        .library(name: "SwiftModFormats", targets: ["SwiftModFormats"]),
        .library(name: "SwiftModEngine", targets: ["SwiftModEngine"]),
        .executable(name: "modinfo", targets: ["modinfo"]),
        .executable(name: "modsample", targets: ["modsample"]),
        .executable(name: "modplay", targets: ["modplay"]),
        .executable(name: "modlive", targets: ["modlive"]),
    ],
    targets: [
        .target(name: "SwiftModCore"),
        .target(name: "SwiftModFormats", dependencies: ["SwiftModCore"]),
        .target(name: "SwiftModEngine", dependencies: ["SwiftModCore"]),
        .executableTarget(name: "modinfo", dependencies: ["SwiftModCore", "SwiftModFormats"]),
        .executableTarget(name: "modsample", dependencies: ["SwiftModCore", "SwiftModFormats"]),
        .executableTarget(name: "modplay", dependencies: ["SwiftModCore", "SwiftModFormats", "SwiftModEngine"]),
        .executableTarget(name: "modlive", dependencies: ["SwiftModCore", "SwiftModFormats", "SwiftModEngine"]),
        .testTarget(name: "SwiftModCoreTests", dependencies: ["SwiftModCore"]),
        .testTarget(name: "SwiftModFormatsTests", dependencies: ["SwiftModFormats"]),
        .testTarget(name: "SwiftModEngineTests", dependencies: ["SwiftModEngine", "SwiftModCore"]),
    ]
)
