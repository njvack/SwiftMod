// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftMod",
    products: [
        .library(name: "SwiftModCore", targets: ["SwiftModCore"]),
        .library(name: "SwiftModFormats", targets: ["SwiftModFormats"]),
        .executable(name: "modinfo", targets: ["modinfo"]),
        .executable(name: "modsample", targets: ["modsample"]),
    ],
    targets: [
        .target(name: "SwiftModCore"),
        .target(name: "SwiftModFormats", dependencies: ["SwiftModCore"]),
        .executableTarget(name: "modinfo", dependencies: ["SwiftModCore", "SwiftModFormats"]),
        .executableTarget(name: "modsample", dependencies: ["SwiftModCore", "SwiftModFormats"]),
        .testTarget(name: "SwiftModCoreTests", dependencies: ["SwiftModCore"]),
        .testTarget(name: "SwiftModFormatsTests", dependencies: ["SwiftModFormats"]),
    ]
)
