// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WisentDesktopUpdate",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WisentDesktopUpdate", targets: ["WisentDesktopUpdate"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.5"),
    ],
    targets: [
        .target(
            name: "WisentDesktopUpdate",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .testTarget(
            name: "WisentDesktopUpdateTests",
            dependencies: ["WisentDesktopUpdate"]
        ),
    ]
)
