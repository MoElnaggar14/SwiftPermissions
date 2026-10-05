# SwiftPermissions

One async API for every Apple permission. Built for Swift 6 strict concurrency, it ships SwiftUI components and is testable without a device.

[![CI](https://github.com/MoElnaggar14/SwiftPermissions/actions/workflows/ci.yml/badge.svg)](https://github.com/MoElnaggar14/SwiftPermissions/actions/workflows/ci.yml)
![Swift 6.0 → 6.4](https://img.shields.io/badge/Swift-6.0_→_6.4-orange.svg)
![Platforms](https://img.shields.io/badge/platforms-iOS%2015%20%7C%20macOS%2012%20%7C%20tvOS%2015%20%7C%20watchOS%209-blue.svg)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)

```swift
import SwiftPermissions          // manager + SwiftUI
import SwiftPermissionsCamera    // adds .camera / .microphone

let permissions = PermissionManager(permissions: [.camera, .notifications])

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

- **Link only what you use.** Each framework is its own product. App Store review scans your binary for code that can request a permission and asks for that permission's usage description, so a camera app shouldn't carry location, contacts or HealthKit code. Register what you link: `PermissionManager(permissions: [.camera, .photoLibrary])`.
- **One vocabulary.** `PermissionStatus` normalises 15+ framework enums. It keeps the distinctions UX depends on: `limited` photos, `provisional` notifications, parental `restricted`, and `unavailable` hardware.
- **No Info.plist crashes.** Before showing a prompt it checks the usage descriptions and throws `missingUsageDescription` instead. `missingUsageDescriptions(for:)` lets you assert this in a unit test.
- **No hangs.** A request made while the app is in the background waits until it's active (iOS ignores prompts until then). Location reports `.unavailable` when Location Services are off system-wide. Cancelling the calling task throws `.cancelled` without dismissing the prompt for other callers.
- **Concurrency-correct.** `PermissionManager` is an actor. It's checked under the Swift 6 language mode. Concurrent requests for the same permission share one prompt.
- **Live.** `updates(for:)` and `changes()` are `AsyncStream`s. `PermissionGate`, `PermissionPrompt` and `PermissionsList` refresh when the user returns from Settings; use `.refreshesPermissions(store)` on your own views.
- **Upgrades included.** `request(_:)` asks for when-in-use → Always location, write-only → full calendar and provisional → full notifications from the partial status. The location upgrade never hangs, even when iOS doesn't show the prompt. (The stock SwiftUI views treat a partial status as granted and don't offer the upgrade; call `request(_:)` where your feature needs it.)
- **Open for extension.** Each permission is a small `PermissionProvider`. You can add your own permission, or replace how a built-in one is requested, without forking.
- **Testable.** `SwiftPermissionsTesting` provides scriptable stubs that run through the real manager logic, with no simulator prompts.

## Installation

```swift
.package(url: "https://github.com/MoElnaggar14/SwiftPermissions", from: "3.0.0")
```

Add `SwiftPermissions` (or just `SwiftPermissionsCore` without SwiftUI), plus one product per framework you request:

```swift
.target(name: "App", dependencies: [
    .product(name: "SwiftPermissions", package: "SwiftPermissions"),
    .product(name: "SwiftPermissionsCamera", package: "SwiftPermissions"),
    .product(name: "SwiftPermissionsPhotos", package: "SwiftPermissions"),
])
```

| Product | Use it for |
| --- | --- |
| `SwiftPermissions` | Core + SwiftUI. No privacy frameworks. |
| `SwiftPermissionsCore` | Domain, manager, registry, notifications. No SwiftUI. |
| `SwiftPermissionsUI` | `PermissionStore`, `PermissionGate`, `PermissionPrompt`, `PermissionRow`, `PermissionsList` |
| `SwiftPermissions<Framework>` | One per framework; see the table below |
| `SwiftPermissionsTesting` | `StubPermissionProvider`, `PermissionManager.stubbed(...)`, for test targets and previews |

Requesting a permission you didn't register throws `providerNotRegistered`, and its message names the product to add.

## Supported permissions

| Registration | Product | iOS | macOS | tvOS | watchOS | Info.plist key(s) |
| --- | --- | :-: | :-: | :-: | :-: | --- |
| `.camera` / `.microphone` | `SwiftPermissionsCamera` | ✓ | ✓ | | | `NSCameraUsageDescription` / `NSMicrophoneUsageDescription` |
| `.photoLibrary` / `.photoLibraryAddOnly` | `SwiftPermissionsPhotos` | ✓ | ✓ | | | `NSPhotoLibraryUsageDescription` / `NSPhotoLibraryAddUsageDescription` |
| `.contacts` | `SwiftPermissionsContacts` | ✓ | ✓ | | ✓ | `NSContactsUsageDescription` |
| `.calendar` / `.calendarWriteOnly` | `SwiftPermissionsCalendar` | ✓ | ✓ | | ✓ | iOS 17+: `NSCalendarsFullAccessUsageDescription` / `NSCalendarsWriteOnlyAccessUsageDescription`. Earlier: `NSCalendarsUsageDescription` |
| `.reminders` | `SwiftPermissionsCalendar` | ✓ | ✓ | | ✓ | iOS 17+: `NSRemindersFullAccessUsageDescription`. Earlier: `NSRemindersUsageDescription` |
| `.locationWhenInUse` | `SwiftPermissionsLocation` | ✓ | ✓ | ✓ | ✓ | `NSLocationWhenInUseUsageDescription` |
| `.locationAlways` | `SwiftPermissionsLocation` | ✓ | ✓ | | ✓ | + `NSLocationAlwaysAndWhenInUseUsageDescription` (not on macOS) |
| `.notifications` | `SwiftPermissionsCore` | ✓ | ✓ | ✓ | ✓ | none |
| `.bluetooth` | `SwiftPermissionsBluetooth` | ✓ | ✓ | ✓ | ✓ | `NSBluetoothAlwaysUsageDescription` |
| `.tracking` | `SwiftPermissionsTracking` | ✓ | ✓ | ✓ | | `NSUserTrackingUsageDescription` |
| `.speechRecognition` | `SwiftPermissionsSpeech` | ✓ | ✓ | | | `NSSpeechRecognitionUsageDescription` |
| `.motion` | `SwiftPermissionsMotion` | ✓ | | | ✓ | `NSMotionUsageDescription` |
| `.siri` | `SwiftPermissionsSiri` | ✓ | | | ✓ | `NSSiriUsageDescription` + Siri capability |
| `.mediaLibrary` | `SwiftPermissionsMediaLibrary` | ✓ | | | | `NSAppleMusicUsageDescription` |
| `.biometrics` | `SwiftPermissionsBiometrics` | ✓ | ✓ | | | `NSFaceIDUsageDescription` (iOS) |
| `.health(share:read:)` | `SwiftPermissionsHealth` | ✓ | | | ✓ | `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` + HealthKit capability |

Some features need no permission at all, so don't add a product for them: `PhotosPicker` / `PHPickerViewController` (picking photos), `LocationButton` / `CLLocationButton` (one-time location), and `ContactAccessButton` on iOS 18.

## SwiftUI

```swift
struct ScannerScreen: View {
    @StateObject private var permissions = PermissionStore(permissions: [.camera])

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

Create one store per app and pass it down (or inject it with `.environmentObject`), so every screen shares one manager and concurrent requests show one prompt.

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
│ Notifications provider                             │
└───────────────────────▲────────────────────────────┘
                        │ one product per framework
  SwiftPermissionsCamera · …Photos · …Location · …Health
```

Think of `PermissionManager` as an airport control tower and providers as the airlines. The tower doesn't care how each airline boards its passengers. It sequences take-offs (prompts), prevents two planes from taking the same runway at once (coalescing), and announces every status change on the radio (streams). Airlines only fly into airports that sign them up: a provider exists in your app only if you link its product and register it.

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

let permissions = PermissionManager(permissions: [.camera, .provider(LocalNetworkProvider())])
```

### HealthKit

```swift
import SwiftPermissionsHealth

let permissions = PermissionManager(permissions: [
    .health(share: [HKQuantityType(.stepCount)], read: [HKQuantityType(.heartRate)])
])
```

Without the HealthKit capability the status is `.unavailable`. Only request share access for types your app can write: HealthKit raises an exception that Swift can't catch for read-only types such as characteristics.

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
    let manager = PermissionManager(
        permissions: [.camera, .photoLibrary, .locationWhenInUse],
        usageDescriptions: InfoPlist(bundle: appBundle)
    )
    let missing = manager.missingUsageDescriptions(for: [.camera, .photoLibrary, .locationWhenInUse])
    XCTAssertEqual(missing, [:])
}
```

## Observability

`changes()` streams every status change, so piping them into your logger or analytics takes a few lines. With [SwiftMoLogger](https://github.com/MoElnaggar14/SwiftMoLogger):

```swift
Task {
    for await change in permissions.changes() {
        log.info("Permission changed", tag: .security, metadata: [
            "permission": .string(change.permission.rawValue),
            "status": .string(change.status.rawValue)
        ])
    }
}
```

## Requirements

Xcode 16+ (Swift 6.0+). iOS 15, macOS 12, tvOS 15, watchOS 9.

CI builds and tests with Swift 6.4 (Xcode 27), 6.3 (Xcode 26.6) and 6.1 (Xcode 16.4), and runs the test suite on the newest iOS Simulator.

Upgrading from 2.x? See [MIGRATION.md](MIGRATION.md).

## License

MIT
