// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftPermissions",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        // Main umbrella framework
        .library(
            name: "SwiftPermissions",
            targets: ["SwiftPermissions"]
        ),
        // Individual modules for specific use cases
        .library(
            name: "SwiftPermissionsCore",
            targets: ["SwiftPermissionsCore"]
        ),
        .library(
            name: "SwiftPermissionsUI",
            targets: ["SwiftPermissionsUI"]
        )
    ],
    dependencies: [],
    targets: [
        // Core permissions logic (no UI dependencies)
        .target(
            name: "SwiftPermissionsCore",
            dependencies: [],
            path: "Sources/SwiftPermissionsCore"
        ),
        // SwiftUI and UI components
        .target(
            name: "SwiftPermissionsUI",
            dependencies: ["SwiftPermissionsCore"],
            path: "Sources/SwiftPermissionsUI"
        ),
        // Main umbrella target that re-exports everything
        .target(
            name: "SwiftPermissions",
            dependencies: ["SwiftPermissionsCore", "SwiftPermissionsUI"],
            path: "Sources/SwiftPermissions"
        ),
        .testTarget(
            name: "SwiftPermissionsTests",
            dependencies: ["SwiftPermissions"],
            path: "Tests/SwiftPermissionsTests"
        )
    ]
)
