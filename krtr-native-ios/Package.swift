// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KRTR",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "KRTR",
            targets: ["KRTR"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "KRTR",
            path: "KRTR"
        ),
    ]
)