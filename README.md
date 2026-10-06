# SwiftPermissions

One async API for every Apple permission. Built for Swift 6 strict concurrency, it ships SwiftUI components and is testable without a device.

[![CI](https://github.com/MoElnaggar14/SwiftPermissions/actions/workflows/ci.yml/badge.svg)](https://github.com/MoElnaggar14/SwiftPermissions/actions/workflows/ci.yml)
![Swift 6.1 → 6.4 tested](https://img.shields.io/badge/Swift-6.1_→_6.4_tested-orange.svg)
![Platforms](https://img.shields.io/badge/platforms-iOS%2015%20%7C%20macOS%2012%20%7C%20tvOS%2015%20%7C%20watchOS%209%20%7C%20visionOS%201-blue.svg)
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

Try it: open [`Example/SwiftPermissionsExample.xcodeproj`](Example) and run it on a simulator or your iPhone. To learn how it's designed, read the [article series](Articles).

## Why

Every framework has its own authorization enum, its own request API (async, callback, delegate, or "just touch the data"), and its own Info.plist key. If a key is missing, the app crashes. SwiftPermissions handles all of that behind one model:

- **Link only what you use.** Each framework is its own product. App Store review scans your binary for code that can request a permission and asks for that permission's usage description, so a camera app shouldn't carry location, contacts or HealthKit code. Register what you link: `PermissionManager(permissions: [.camera, .photoLibrary])`.
- **One vocabulary.** `PermissionStatus` normalises 15+ framework enums. It keeps the distinctions UX depends on: `limited` photos, `provisional` notifications, parental `restricted`, and `unavailable` hardware.
- **No Info.plist crashes.** Before showing a prompt it checks the usage descriptions and throws `missingUsageDescription` instead. `missingUsageDescriptions(for:)` lets you assert this in a unit test.
- **No hangs.** A request made while the app is in the background waits until it's active (iOS ignores prompts until then). Location reports `.unavailable` when Location Services are off system-wide. Cancelling the calling task throws `.cancelled` without dismissing the prompt for other callers.
- **Concurrency-correct.** `PermissionManager` is an actor. It's checked under the Swift 6 language mode. Concurrent requests for the same permission share one prompt.
- **Live.** `updates(for:)` and `changes()` are `AsyncStream`s. `PermissionGate`, `PermissionPrompt` and `PermissionsList` refresh when the user returns from Settings; use `.refreshesPermissions(store)` on your own views.
- **Upgrades included.** `request(_:)` asks for when-in-use → Always location, write-only → full calendar and provisional → full notifications from the partial status. The location upgrade never hangs, even when iOS doesn't show the prompt. `PermissionRow` offers an **Allow More** button when an upgrade is possible, and `canRequest(_:)` (on the manager and the store) tells you whether a prompt can still appear, since the status alone can't: `.limited` location can be upgraded, `.limited` photos can't.
- **Open for extension.** Each permission is a small `PermissionProvider`. You can add your own permission, or replace how a built-in one is requested, without forking.
- **Testable.** `SwiftPermissionsTesting` provides scriptable stubs that run through the real manager logic, with no simulator prompts.

## Installation

```swift
.package(url: "https://github.com/MoElnaggar14/SwiftPermissions", from: "3.2.0")
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
| `.alarms` | `SwiftPermissionsAlarms` | ✓ (26+) | | | | `NSAlarmKitUsageDescription` |
| `.screenRecording` | `SwiftPermissionsScreenRecording` | | ✓ | | | none |
| `.accessibility` | `SwiftPermissionsAccessibility` | | ✓ | | | none |
| `.inputMonitoring` | `SwiftPermissionsInputMonitoring` | | ✓ | | | none |

`.bluetooth` in an AccessorySetupKit app: on iOS 18+, an app whose Info.plist lists `Bluetooth` under `NSAccessorySetupKitSupports` never sees the Bluetooth prompt. The user grants access to each accessory in the AccessorySetupKit picker, and `CBManager.authorization` stays `.notDetermined` before and after pairing. In such an app `.bluetooth` reports `.unavailable` instead of a `.notDetermined` that no prompt can resolve, and `request(.bluetooth)` shows nothing and returns at once. Use `ASAccessorySession.accessories` to see which accessories the app can reach. A real `.denied` or `.restricted` is still reported. Keep `NSBluetoothAlwaysUsageDescription` if you also support iOS 17, where the normal prompt still appears.

`.alarms` covers AlarmKit, whose alarms and timers sound through Silent mode and Focus. Before iOS 26 it reports `.unavailable`, so apps with an older deployment target can register it without availability checks.

`.screenRecording`, `.accessibility` and `.inputMonitoring` are macOS only (not Mac Catalyst); elsewhere their products are empty. They have no usage description: a request shows a system alert that sends the user to System Settings, and `AppSettings.open(for:)` opens the matching Privacy & Security pane. macOS only says whether Screen Recording and Accessibility are granted, so they read `.notDetermined` until the provider has asked in the current launch, and `.denied` after that. Input Monitoring reports all three states.

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

To let people decline without spending the one-time system prompt, pass `onDefer`. The prompt then shows **Not Now** while the permission can still be requested. The package stores nothing; your app decides when to ask again:

```swift
@AppStorage("scannerDeferredAt") private var deferredAt: Double = 0

PermissionGate(.camera, message: "Scan receipts with your camera.", store: permissions, onDefer: {
    deferredAt = Date().timeIntervalSince1970   // e.g. ask again after a week
}) {
    ScannerView()
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

### Limited photos and contacts

With limited access, people can share more photos (or, on iOS 18, contacts) without going to Settings. Pass `onSelectMore` to `PermissionRow` or `PermissionPrompt` and they show **Select More…** while the status is `.limited`. The pickers live in the framework products, so the UI module never links Photos or Contacts:

```swift
import SwiftPermissionsContacts
import SwiftPermissionsPhotos

// Photos (iOS and Mac Catalyst): a UIKit picker, so present it from a view controller.
PermissionRow(.photoLibrary, store: permissions) {
    Task { await PhotoLibraryPermissionProvider.readWrite.presentLimitedLibraryPicker(from: controller) }
}

// Contacts (iOS 18): a SwiftUI modifier.
@State private var pickingContacts = false

PermissionRow(.contacts, store: permissions) { pickingContacts = true }
    .limitedContactsPicker(isPresented: $pickingContacts) { identifiers in
        // newly shared contact identifiers
    }
```

Both return only the newly selected identifiers. The status stays `.limited`.

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

### Precise or approximate location

Users can allow location with **Precise** turned off. The status is still `.authorized`, but the coordinates are only accurate to an area several kilometres wide, so navigation, delivery and fitness apps need to know. `accuracy()` tells you, and `requestTemporaryFullAccuracy(purposeKey:)` asks for precise location for this session:

```swift
let location = LocationPermissionProvider.whenInUse

if await location.accuracy() == .reduced {   // nil until location is authorized
    let accuracy = try await location.requestTemporaryFullAccuracy(purposeKey: "Navigation")
}
```

The purpose key names an entry in the `NSLocationTemporaryUsageDescriptionDictionary` Info.plist dictionary, and the system shows that string as the reason. A missing entry throws `.missingUsageDescription` before anything is shown. Reduced accuracy is never reported as `.limited`, which for location means "when in use". tvOS has no temporary request.

### Notifications that are allowed but silent

A user can allow notifications and still never see them: alerts off, banners set to None, the lock screen and Notification Center hidden. `settings()` reads the details without prompting:

```swift
let settings = await NotificationsPermissionProvider().settings()

if settings.isEffectivelySilent {
    showTip("Turn on Banners for this app in Settings to see reminders.")
}
settings.timeSensitive      // .enabled / .disabled / .notSupported
settings.scheduledDelivery  // delivered in the Scheduled Summary?
settings.alertStyle         // .off / .banner / .alert
```

Fields a platform doesn't have read `.notSupported` (tvOS only has badges). Critical alerts need Apple's critical-alerts entitlement.

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

With Swift Testing, the same stubs work with `#expect`:

```swift
import Testing
import SwiftPermissionsTesting

@Test func scannerAsksOnce() async throws {
    let camera = StubPermissionProvider(.camera, onRequest: .deny)
    let permissions = PermissionManager.stubbed(camera)

    #expect(try await permissions.request(.camera) == .denied)
    #expect(await camera.requestCount == 1)
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

### Permission funnels in Amplitude, Google Analytics or Mixpanel

Product teams usually want two numbers per permission: how often the prompt is answered with Allow, and how often people change their mind in Settings. Neither needs a dependency here; give this type your SDK's track call:

```swift
/// Sends permission funnel events to any analytics SDK.
struct PermissionAnalytics: Sendable {
    let permissions: any PermissionManaging
    let track: @Sendable (_ event: String, _ properties: [String: String]) -> Void

    /// Requests `permission`, recording the answer when a system prompt was actually shown.
    func request(_ permission: Permission, from screen: String) async throws(PermissionError) -> PermissionStatus {
        let showsPrompt = await permissions.canRequest(permission)
        let status = try await permissions.request(permission)
        if showsPrompt {
            track("permission_prompt_answered", [
                "permission": permission.rawValue, "status": status.rawValue, "screen": screen
            ])
        }
        return status
    }

    /// Records changes made outside the app, e.g. in Settings. Run it for the app's lifetime.
    func trackSettingsChanges() async {
        var known: [Permission: PermissionStatus] = [:]
        for await change in permissions.changes() {
            // The first status seen is a baseline, and leaving .notDetermined is a prompt
            // answer that request(_:from:) already tracked.
            if let previous = known[change.permission], previous != change.status, previous != .notDetermined {
                track("permission_changed", [
                    "permission": change.permission.rawValue,
                    "from": previous.rawValue, "to": change.status.rawValue
                ])
            }
            known[change.permission] = change.status
        }
    }
}

let analytics = PermissionAnalytics(permissions: permissions) { event, properties in
    Amplitude.instance.track(eventType: event, eventProperties: properties)
}
```

Upgrade prompts (when-in-use → Always) show up as `permission_changed` too. Statuses aren't personal data, but analytics still needs whatever consent your privacy policy and App Store privacy details promise.

## Use with AI coding agents

The repository ships an [agent skill](plugin/skills/swiftpermissions/SKILL.md) that teaches AI coding agents to integrate SwiftPermissions correctly. It covers which product to add for each permission, registration, the Info.plist keys for each OS version, handling every status, upgrades and testing with stubs. It also includes a script that checks your registered permissions against your Info.plist and build settings:

```bash
python3 plugin/skills/swiftpermissions/scripts/check_usage_descriptions.py path/to/YourApp
```

**Claude Code**: install it as a plugin:

```
/plugin marketplace add MoElnaggar14/SwiftPermissions
/plugin install swiftpermissions@swiftpermissions
```

**Codex and other agents that read `SKILL.md`**: copy the skill into your app's repository:

```bash
git clone --depth 1 https://github.com/MoElnaggar14/SwiftPermissions /tmp/SwiftPermissions
mkdir -p .agents/skills && cp -R /tmp/SwiftPermissions/plugin/skills/swiftpermissions .agents/skills/
```

(Use `.claude/skills/` instead of `.agents/skills/` to give it to Claude Code without the plugin.) Agents working on this repository itself read [AGENTS.md](AGENTS.md).

## Requirements

Xcode 16+ (Swift 6.0+). iOS 15, macOS 12, tvOS 15, watchOS 9, visionOS 1. On visionOS, `.locationAlways`, `.motion`, `.siri` and `.mediaLibrary` aren't available.

CI builds and tests with Swift 6.4 (Xcode 27), 6.3 (Xcode 26.6) and 6.1 (Xcode 16.4), and runs the test suite on the newest iOS Simulator. It also builds for Mac Catalyst, tvOS, watchOS and visionOS, and builds the whole package as app-extension-safe.

- **App extensions.** Every product compiles into widgets and notification extensions. Requests skip the "wait until the app is active" step there. `AppSettings.open` and `PermissionStore.openSettings` are unavailable in extensions. The SwiftUI views open Settings through SwiftUI's `openURL` action, so they work everywhere.
- **Privacy manifest.** Core ships a `PrivacyInfo.xcprivacy` declaring no tracking, no collected data and no required-reason APIs. Your app still declares what it does with the data each permission unlocks.
- **Stable statuses.** `PermissionStatus` won't gain cases in 3.x, so exhaustive `switch`es stay valid. New permissions map onto the existing cases.

Upgrading from 2.x? See [MIGRATION.md](MIGRATION.md).

## License

MIT
