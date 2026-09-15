// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WisentDesktopUpdate",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WisentDesktopUpdate", targets: ["WisentDesktopUpdate"]),
    ],
    targets: [
        .binaryTarget(
            name: "Sparkle",
            url: "https://github.com/sparkle-project/Sparkle/releases/download/2.9.5/Sparkle-for-Swift-Package-Manager.zip",
            checksum: "34b9b2071f3de0012eca3faa3a9290bb94e62131e9a74f6dc91514a000097a6c"
        ),
        .target(
            name: "WisentDesktopUpdate",
            dependencies: [
                .target(name: "Sparkle"),
            ]
        ),
        .testTarget(
            name: "WisentDesktopUpdateTests",
            dependencies: ["WisentDesktopUpdate"]
        ),
    ]
)
