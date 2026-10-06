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
.package(url: "https://github.com/MoElnaggar14/SwiftPermissions", from: "3.4.0")
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
| `.localNetwork` | `SwiftPermissionsLocalNetwork` | ✓ | ✓ (15+) | | | `NSLocalNetworkUsageDescription` + `_swiftperms._tcp` in `NSBonjourServices` |

`.bluetooth` in an AccessorySetupKit app: on iOS 18+, an app whose Info.plist lists `Bluetooth` under `NSAccessorySetupKitSupports` never sees the Bluetooth prompt. The user grants access to each accessory in the AccessorySetupKit picker, and `CBManager.authorization` stays `.notDetermined` before and after pairing. In such an app `.bluetooth` reports `.unavailable` instead of a `.notDetermined` that no prompt can resolve, and `request(.bluetooth)` shows nothing and returns at once. Use `ASAccessorySession.accessories` to see which accessories the app can reach. A real `.denied` or `.restricted` is still reported. Keep `NSBluetoothAlwaysUsageDescription` if you also support iOS 17, where the normal prompt still appears.

`.alarms` covers AlarmKit, whose alarms and timers sound through Silent mode and Focus. Before iOS 26 it reports `.unavailable`, so apps with an older deployment target can register it without availability checks.

`.screenRecording`, `.accessibility` and `.inputMonitoring` are macOS only (not Mac Catalyst); elsewhere their products are empty. They have no usage description: a request shows a system alert that sends the user to System Settings, and `AppSettings.open(for:)` opens the matching Privacy & Security pane. macOS only says whether Screen Recording and Accessibility are granted, so they read `.notDetermined` until the provider has asked, and `.denied` after that. By default that's remembered for the current launch only; see [Remembering requests across launches](#remembering-requests-across-launches). Input Monitoring reports all three states.

`.localNetwork` has no system API to read or request it. `request` runs a short Bonjour probe (advertise and browse `_swiftperms._tcp`), which shows the prompt the first time: finding itself means `.authorized`, a policy-denied error after the prompt closed means `.denied`, and no answer within the timeout leaves `.notDetermined`. `status` is `.notDetermined` until a request has run, then the last result; after a relaunch, request again (no prompt if the user already answered), or keep the result in a [persistent history](#remembering-requests-across-launches). To probe a service type your app already declares, register `.localNetwork(serviceType: "_myapp._tcp")`. On tvOS and macOS before 15 nothing gates the local network, so it reads `.authorized`.

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

### Onboarding flows

`PermissionFlow` asks for several permissions in turn, with a priming screen before each system prompt:

```swift
@AppStorage("onboardingPermissions") private var progress = PermissionFlowProgress()

PermissionFlow(store: permissions, steps: [
    .init(.notifications, title: "Stay in the loop", message: "Get a ping when your order ships."),
    .init(.locationWhenInUse, title: "Find stores near you", message: "See what's in stock nearby."),
    .init(.photoLibrary, title: "Share your receipts", message: "Attach photos of receipts.", optional: true),
], progress: $progress) { statuses in   // [Permission: PermissionStatus]
    showingOnboarding = false
}
```

- A step is skipped without a screen when its permission can't show a prompt: already decided, restricted or unavailable.
- Each screen offers the same actions as `PermissionPrompt`: **Continue**, **Not Now**, **Open Settings** and **Select More…** (pass `onSelectMore:`).
- **Not Now** on an optional step moves on. On a required step it pauses the flow, and the flow starts from that step next time.
- `PermissionFlowProgress` is a small `Codable` value (and a JSON `rawValue`, so `@AppStorage` takes it). Persist it and the flow continues where it stopped on the next launch. The package stores nothing. Call `progress.forget(.photoLibrary)` to ask for a deferred step again.
- Removing the view cancels a request in flight; that step is shown again next time.

The logic lives in `PermissionFlowState`, a plain value in Core with no UI. Drive it yourself for a UIKit or custom flow, or test it with stubs:

```swift
var flow = PermissionFlowState(steps: steps, progress: savedProgress)
while let step = await flow.advance(using: permissions) {   // skips decided steps
    // show your priming screen for step, then:
    await flow.requestCurrent(using: permissions)           // or flow.notNow(step.permission, status: .notDetermined)
}
savedProgress = flow.progress
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

### Precise or approximate location

Users can allow location with **Precise** turned off. The status is still `.authorized`, but the coordinates are only accurate to an area several kilometres wide, so navigation, delivery and fitness apps need to know. `accuracy()` tells you, and `requestTemporaryFullAccuracy(purposeKey:)` asks for precise location for this session:

```swift
let location = LocationPermissionProvider.whenInUse

if await location.accuracy() == .reduced {   // nil until location is authorized
    let accuracy = try await location.requestTemporaryFullAccuracy(purposeKey: "Navigation")
}
```

The purpose key names an entry in the `NSLocationTemporaryUsageDescriptionDictionary` Info.plist dictionary, and the system shows that string as the reason. A missing entry throws `.missingUsageDescription` before anything is shown. Reduced accuracy is never reported as `.limited`, which for location means "when in use". tvOS has no temporary request.

### Location service sessions (iOS 18)

iOS 18 added `CLServiceSession`, which tells Core Location that the app needs location at a given level. While a session is alive, Core Location shows the prompt when the app is in use and the user hasn't decided, and reports diagnostics that explain why location isn't arriving. Apps that set `NSLocationRequireExplicitServiceSession` in Info.plist get location updates only while they hold one. `startServiceSession(fullAccuracyPurposeKey:)` starts a session and hands it to you:

```swift
@available(iOS 18.0, *)
@MainActor final class MapModel {
    private var session: LocationServiceSession?

    func start() async throws {
        let session = try await LocationPermissionProvider.whenInUse.startServiceSession()
        self.session = session                       // keep it while the map needs location
        for await update in session.updates {
            show(update.status)                      // .denied, .restricted, .unavailable, ...
            if update.diagnostic.insufficientlyInUse { /* ask again once the app is in use */ }
        }
    }

    func stop() {
        session?.invalidate()                        // or let the model go
        session = nil
    }
}
```

`request(_:)` through `CLLocationManager` stays the default; the session is opt-in. Use `LocationPermissionProvider.always` for an Always session, and pass `fullAccuracyPurposeKey` to ask for precise location as well. Missing usage descriptions or purpose strings throw `.missingUsageDescription` before anything is shown.

**You own the session.** It lasts until you call `invalidate()` or release the `LocationServiceSession`, so keep it in the object whose lifetime matches the feature (a screen's model, a workout), not in a local that goes out of scope. The package never keeps one alive for you: a hidden session would tell Core Location that the app still needs location after the feature has gone. `updates` has one consumer and finishes when the session ends.

Each update carries the `PermissionStatus` and the raw `LocationSessionDiagnostic`. Restricted maps to `.restricted`, denied to `.denied`, and Location Services off to `.unavailable` (or `.denied` once the user has decided). Otherwise the status is the one `status()` reports, so a prompt in progress or an app that isn't in use enough reads `.notDetermined`. When an Always session gets When In Use, the status is `.limited`. Reduced accuracy is never a status; check `diagnostic.fullAccuracyDenied`. Sessions are available on iOS 18, Mac Catalyst 18, tvOS 18, watchOS 11 and visionOS 2, not on macOS.

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

### Remembering requests across launches

Screen Recording and Accessibility only say whether access is granted, and the local network has no status API at all. Their providers keep a `PermissionRequestHistory` to tell "never asked" from "declined". The default is in memory, so after a relaunch these permissions read `.notDetermined` again, and the UI offers **Allow** where it should offer **Open Settings**. Pass a `UserDefaultsRequestHistory` to remember across launches:

```swift
let history = UserDefaultsRequestHistory()   // UserDefaults.standard, keys prefixed "SwiftPermissions."

let permissions = PermissionManager(permissions: [
    .screenRecording(history: history),
    .accessibility(history: history),
    .localNetwork(serviceType: "_myapp._tcp", history: history)
])
```

A declined Screen Recording or Accessibility request then still reads `.denied` after a relaunch, and the local network reads its last result. The providers take a `history:` argument too, and you can write your own history (Keychain, iCloud) by conforming to the protocol.

- **A grant always wins.** If the system reports access, the status is `.authorized` whatever the history says.
- **`tccutil reset` isn't seen.** Resetting a permission with `tccutil` (or reinstalling a Mac app that keeps its defaults) clears the system's state but not the history, so the permission keeps reading `.denied`. Call `history.forget(.screenRecording)` to start over.
- **Settings changes to the local network aren't seen** until the next request. Calling `request()` on the provider directly shows no prompt once the user has answered and records the current answer.
- **Privacy manifest.** `UserDefaults` is a required-reason API, so Core's privacy manifest declares `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`. If you pass an app group's `UserDefaults(suiteName:)`, declare `1C8F.1` in your app's manifest.

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
- **Privacy manifest.** Core ships a `PrivacyInfo.xcprivacy` declaring no tracking and no collected data, and `UserDefaults` access with reason `CA92.1` for `UserDefaultsRequestHistory`. Your app still declares what it does with the data each permission unlocks.
- **Stable statuses.** `PermissionStatus` won't gain cases in 3.x, so exhaustive `switch`es stay valid. New permissions map onto the existing cases.

Upgrading from 2.x? See [MIGRATION.md](MIGRATION.md).

## License

MIT
