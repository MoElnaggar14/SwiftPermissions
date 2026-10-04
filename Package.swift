// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftPermissions",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v9)
    ],
    products: [
        // Everything: Core + SwiftUI components.
        .library(name: "SwiftPermissions", targets: ["SwiftPermissions"]),
        // Domain model, manager and system providers. No SwiftUI.
        .library(name: "SwiftPermissionsCore", targets: ["SwiftPermissionsCore"]),
        // SwiftUI store, gates, primers and rows.
        .library(name: "SwiftPermissionsUI", targets: ["SwiftPermissionsUI"]),
        // Stubs for unit tests and SwiftUI previews. Link from test targets only.
        .library(name: "SwiftPermissionsTesting", targets: ["SwiftPermissionsTesting"])
    ],
    targets: [
        .target(name: "SwiftPermissionsCore"),
        .target(name: "SwiftPermissionsUI", dependencies: ["SwiftPermissionsCore"]),
        .target(name: "SwiftPermissions", dependencies: ["SwiftPermissionsCore", "SwiftPermissionsUI"]),
        .target(name: "SwiftPermissionsTesting", dependencies: ["SwiftPermissionsCore"]),
        .testTarget(
            name: "SwiftPermissionsTests",
            dependencies: ["SwiftPermissionsCore", "SwiftPermissionsTesting"]
        ),
        .testTarget(
            name: "SwiftPermissionsUITests",
            dependencies: ["SwiftPermissionsUI", "SwiftPermissionsTesting"]
        )
    ],
    swiftLanguageModes: [.v6]
)
