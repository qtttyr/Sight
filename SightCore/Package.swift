// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SightCore",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "SightCore", targets: ["SightCore"])
    ],
    targets: [
        .target(
            name: "SightCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SightCoreTests",
            dependencies: ["SightCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
