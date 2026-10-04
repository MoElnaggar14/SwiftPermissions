# SwiftPermissions

One async API for every Apple permission. Built for Swift 6 strict concurrency, it ships SwiftUI components and is testable without a device.

[![CI](https://github.com/MoElnaggar14/SwiftPermissions/actions/workflows/ci.yml/badge.svg)](https://github.com/MoElnaggar14/SwiftPermissions/actions/workflows/ci.yml)
![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)
![Platforms](https://img.shields.io/badge/platforms-iOS%2015%20%7C%20macOS%2012%20%7C%20tvOS%2015%20%7C%20watchOS%209-blue.svg)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)

```swift
let permissions = PermissionManager()

switch try await permissions.request(.camera) {
case .authorized:          startCapture()
case .limited:             startCapture(limited: true)
case .denied:              await AppSettings.open(for: .camera)
case .restricted, .unavailable, .notDetermined, .provisional:
    showUnavailableState()
}
```

## Why

Every framework has its own authorization enum, its own request API (async, callback, delegate, or "just touch the data"), and its own Info.plist key. If a key is missing, the app crashes. SwiftPermissions handles all of that behind one model:

- **One vocabulary.** `PermissionStatus` normalises 15+ framework enums. It keeps the distinctions UX depends on: `limited` photos, `provisional` notifications, parental `restricted`, and `unavailable` hardware.
- **No Info.plist crashes.** Before showing a prompt it checks the usage descriptions and throws `missingUsageDescription` instead. `missingUsageDescriptions(for:)` lets you assert this in a unit test.
- **Concurrency-correct.** `PermissionManager` is an actor. It's checked under the Swift 6 language mode. Concurrent requests for the same permission share one prompt.
- **Live.** `updates(for:)` and `changes()` are `AsyncStream`s, and the SwiftUI store refreshes when the user returns from Settings.
- **Open for extension.** Each permission is a small `PermissionProvider`. You can add your own permission, or replace how a built-in one is requested, without forking.
- **Testable.** `SwiftPermissionsTesting` provides scriptable stubs that run through the real manager logic, with no simulator prompts.

## Installation

```swift
.package(url: "https://github.com/MoElnaggar14/SwiftPermissions", from: "3.0.0")
```

| Product | Use it for |
| --- | --- |
| `SwiftPermissions` | Everything (Core + SwiftUI) |
| `SwiftPermissionsCore` | Domain, manager, providers. No SwiftUI. |
| `SwiftPermissionsUI` | `PermissionStore`, `PermissionGate`, `PermissionPrompt`, `PermissionRow`, `PermissionsList` |
| `SwiftPermissionsTesting` | `StubPermissionProvider`, `PermissionManager.stubbed(...)`, for test targets and previews |

## Supported permissions

| Permission | iOS | macOS | tvOS | watchOS | Info.plist key(s) |
| --- | :-: | :-: | :-: | :-: | --- |
| `.camera` | ✓ | ✓ | | | `NSCameraUsageDescription` |
| `.microphone` | ✓ | ✓ | | | `NSMicrophoneUsageDescription` |
| `.photoLibrary` / `.photoLibraryAddOnly` | ✓ | ✓ | | | `NSPhotoLibraryUsageDescription` / `NSPhotoLibraryAddUsageDescription` |
| `.contacts` | ✓ | ✓ | | ✓ | `NSContactsUsageDescription` |
| `.calendar` / `.calendarWriteOnly` | ✓ | ✓ | | ✓ | `NSCalendarsFullAccessUsageDescription` / `NSCalendarsWriteOnlyAccessUsageDescription` (iOS 17+) |
| `.reminders` | ✓ | ✓ | | ✓ | `NSRemindersFullAccessUsageDescription` (iOS 17+) |
| `.locationWhenInUse` | ✓ | ✓ | ✓ | ✓ | `NSLocationWhenInUseUsageDescription` |
| `.locationAlways` | ✓ | ✓ | | ✓ | + `NSLocationAlwaysAndWhenInUseUsageDescription` |
| `.notifications` | ✓ | ✓ | ✓ | ✓ | none |
| `.bluetooth` | ✓ | ✓ | ✓ | ✓ | `NSBluetoothAlwaysUsageDescription` |
| `.tracking` | ✓ | ✓ | ✓ | | `NSUserTrackingUsageDescription` |
| `.speechRecognition` | ✓ | ✓ | | | `NSSpeechRecognitionUsageDescription` |
| `.motion` | ✓ | | | ✓ | `NSMotionUsageDescription` |
| `.siri` | ✓ | | | ✓ | `NSSiriUsageDescription` |
| `.mediaLibrary` | ✓ | | | | `NSAppleMusicUsageDescription` |
| `.biometrics` | ✓ | ✓ | | | `NSFaceIDUsageDescription` |
| `.health` (opt-in) | ✓ | | | ✓ | `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` |

## SwiftUI

```swift
struct ScannerScreen: View {
    @StateObject private var permissions = PermissionStore()

    var body: some View {
        // Shows the scanner once granted. Until then it shows a pre-permission prompt
        // with the right action for the status: Continue, Open Settings, or nothing.
        PermissionGate(.camera, message: "Scan receipts with your camera.", store: permissions) {
            ScannerView()
        }
    }
}
```

You can provide your own fallback UI:

```swift
PermissionGate(.microphone, store: permissions) {
    Recorder()
} fallback: { status in
    MicrophoneOnboarding(status: status) { Task { await permissions.request(.microphone) } }
}
```

For an onboarding or privacy screen: `PermissionsList([.camera, .microphone, .notifications], store: permissions)`.

## Architecture

```
┌──────────────── SwiftPermissionsUI ────────────────┐
│ PermissionStore (MainActor) → Gate / Prompt / Row  │
└───────────────────────┬────────────────────────────┘
                        │ depends on protocols
┌──────────────── SwiftPermissionsCore ──────────────┐
│ Domain:  Permission · PermissionStatus · Error     │
│ Ports:   PermissionStatusReading / Requesting /    │
│          Observing · PermissionProvider            │
│ Manager: PermissionManager (actor) + Registry      │
│ Providers: Camera · Photos · Location · …          │
└────────────────────────────────────────────────────┘
```

Think of `PermissionManager` as an airport control tower and providers as the airlines. The tower doesn't care how each airline boards its passengers. It sequences take-offs (prompts), prevents two planes from taking the same runway at once (coalescing), and announces every status change on the radio (streams).

Depend on the narrowest protocol: a screen that only shows status takes a `PermissionStatusReading`, not the whole manager.

### Custom permissions

```swift
extension Permission {
    static let localNetwork = Permission("localNetwork", displayName: "Local Network")
}

struct LocalNetworkProvider: PermissionProvider {
    let permission = Permission.localNetwork
    let requiredUsageDescriptionKeys = ["NSLocalNetworkUsageDescription"]
    func status() async -> PermissionStatus { /* … */ }
    func request() async throws -> PermissionStatus { /* … */ }
}

let permissions = PermissionManager(registry: .standard.registering(LocalNetworkProvider()))
```

### HealthKit

```swift
let permissions = PermissionManager(
    registry: .standard.registering(
        HealthPermissionProvider(share: [HKQuantityType(.stepCount)], read: [HKQuantityType(.heartRate)])
    )
)
```

## Testing

```swift
import SwiftPermissionsTesting

func testScannerShowsSettingsHintWhenDenied() async {
    let camera = StubPermissionProvider(.camera, status: .notDetermined, onRequest: .deny)
    let model = ScannerModel(permissions: PermissionManager.stubbed(camera))

    await model.start()

    XCTAssertTrue(model.showsSettingsHint)
    let prompts = await camera.requestCount
    XCTAssertEqual(prompts, 1)
}
```

Catch a missing Info.plist key in CI rather than in App Review:

```swift
func testInfoPlistDeclaresEveryPermissionWeUse() {
    let missing = PermissionManager(usageDescriptions: InfoPlist(bundle: appBundle))
        .missingUsageDescriptions(for: [.camera, .photoLibrary, .locationWhenInUse])
    XCTAssertEqual(missing, [:])
}
```

## Requirements

Xcode 16+ (Swift 6). iOS 15, macOS 12, tvOS 15, watchOS 9.

Upgrading from 2.x? See [MIGRATION.md](MIGRATION.md).

## License

MIT
