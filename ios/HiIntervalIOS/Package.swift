// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HiIntervalIOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "HiIntervalCore", targets: ["HiIntervalCore"]),
    ],
    targets: [
        .target(name: "HiIntervalCore"),
        .testTarget(
            name: "HiIntervalCoreTests",
            dependencies: ["HiIntervalCore"]
        ),
    ]
)

