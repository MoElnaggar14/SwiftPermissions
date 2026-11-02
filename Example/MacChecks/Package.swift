// swift-tools-version: 6.0
import PackageDescription

/// A small macOS app for the Mac device checks (#46): Screen Recording, Accessibility,
/// Input Monitoring and Local Network, with requests remembered across launches.
let package = Package(
    name: "MacChecks",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../..")],
    targets: [
        .executableTarget(
            name: "MacChecks",
            dependencies: [
                .product(name: "SwiftPermissions", package: "SwiftPermissions"),
                .product(name: "SwiftPermissionsScreenRecording", package: "SwiftPermissions"),
                .product(name: "SwiftPermissionsAccessibility", package: "SwiftPermissions"),
                .product(name: "SwiftPermissionsInputMonitoring", package: "SwiftPermissions"),
                .product(name: "SwiftPermissionsLocalNetwork", package: "SwiftPermissions")
            ]
        )
    ]
)
