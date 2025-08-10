// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftPermissions",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7)
    ],
    products: [
        .library(
            name: "SwiftPermissions",
            targets: ["SwiftPermissions"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftPermissions",
            dependencies: [],
            path: "Sources/SwiftPermissions"
        ),
        .testTarget(
            name: "SwiftPermissionsTests",
            dependencies: ["SwiftPermissions"],
            path: "Tests/SwiftPermissionsTests"
        )
    ]
)
