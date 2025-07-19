// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KRTRMesh",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "KRTRMesh",
            targets: ["KRTRMesh"]
        ),
    ],
    dependencies: [
        // Swift Crypto for cryptographic operations
        .package(url: "https://github.com/apple/swift-crypto", from: "3.0.0"),
        // CryptoSwift for additional crypto utilities
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift", from: "1.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "KRTRMesh",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                "CryptoSwift"
            ],
            path: "KRTRMesh"
        ),
    ]
)
