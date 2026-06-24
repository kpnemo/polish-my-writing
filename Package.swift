// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PolishCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PolishCore", targets: ["PolishCore"]),
    ],
    targets: [
        .target(name: "PolishCore"),
        .testTarget(name: "PolishCoreTests", dependencies: ["PolishCore"]),
    ]
)
