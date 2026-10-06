// swift-tools-version: 6.0

import PackageDescription

/// One product per system framework. App Store review scans the binary for code that
/// can request a permission and asks for that permission's usage description, so an
/// app should link only the permissions it actually requests.
let frameworks = [
    "Camera", "Photos", "Contacts", "Calendar", "Location", "Bluetooth", "Motion",
    "Speech", "MediaLibrary", "Siri", "Tracking", "Biometrics", "Health", "Alarms",
    "ScreenRecording", "Accessibility", "InputMonitoring"
]

let package = Package(
    name: "SwiftPermissions",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        // Core + SwiftUI components. Add the framework products you need.
        .library(name: "SwiftPermissions", targets: ["SwiftPermissions"]),
        // Domain model, manager, registry and notifications. No SwiftUI, no privacy frameworks.
        .library(name: "SwiftPermissionsCore", targets: ["SwiftPermissionsCore"]),
        // SwiftUI store, gates, primers and rows.
        .library(name: "SwiftPermissionsUI", targets: ["SwiftPermissionsUI"]),
        // Stubs for unit tests and SwiftUI previews. Link from test targets only.
        .library(name: "SwiftPermissionsTesting", targets: ["SwiftPermissionsTesting"])
    ] + frameworks.map { Product.library(name: "SwiftPermissions\($0)", targets: ["SwiftPermissions\($0)"]) },
    targets: [
        .target(name: "SwiftPermissionsCore", resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "SwiftPermissionsUI", dependencies: ["SwiftPermissionsCore"]),
        .target(name: "SwiftPermissions", dependencies: ["SwiftPermissionsCore", "SwiftPermissionsUI"]),
        .target(name: "SwiftPermissionsTesting", dependencies: ["SwiftPermissionsCore"]),
        .testTarget(
            name: "SwiftPermissionsTests",
            dependencies: [
                "SwiftPermissionsCore", "SwiftPermissionsTesting",
                "SwiftPermissionsAlarms", "SwiftPermissionsBluetooth", "SwiftPermissionsCamera",
                "SwiftPermissionsLocation", "SwiftPermissionsAccessibility", "SwiftPermissionsInputMonitoring",
                "SwiftPermissionsScreenRecording"
            ]
        ),
        .testTarget(
            name: "SwiftPermissionsUITests",
            dependencies: ["SwiftPermissionsUI", "SwiftPermissionsTesting"]
        )
    ] + frameworks.map { Target.target(name: "SwiftPermissions\($0)", dependencies: ["SwiftPermissionsCore"]) },
    swiftLanguageModes: [.v6]
)
