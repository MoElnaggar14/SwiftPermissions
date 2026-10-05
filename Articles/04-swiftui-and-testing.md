# SwiftUI and tests without a single system prompt

> The simulator remembers your answer to every permission prompt. My UI tests passed on my machine and failed on CI, because CI's simulator had never been asked.

The first three parts built a manager you can trust. This part is about the two places you'll touch it most: views and tests. Both rest on the same idea from Part 1: depend on a protocol, and inject the concrete thing at the edge.

## `PermissionStore`: main-actor state for views

`PermissionManager` is an actor, and SwiftUI wants synchronous, main-actor state it can read in `body`. `PermissionStore` bridges the two:

```swift
@MainActor
public final class PermissionStore: ObservableObject {
    @Published public private(set) var statuses: [Permission: PermissionStatus]
    @Published public private(set) var pending: Set<Permission>      // prompts on screen
    @Published public private(set) var requestable: Set<Permission>  // a prompt can still appear
    @Published public var lastError: PermissionError?

    public convenience init(permissions: [PermissionRegistration])
    public init(manager: any PermissionManaging = PermissionManager())
}
```

Think of the manager as the kitchen and the store as the waiter. The kitchen does the real work at its own pace; the waiter keeps the table's view of the order current and never makes the diners walk into the kitchen.

The store subscribes to the manager's `changes()` stream when it's created. A request made anywhere (another screen, a background task, a raw manager call) shows up in every view bound to the store. Create **one** per app and pass it down, so every screen shares one manager and concurrent requests show one prompt:

```swift
@main
struct ScannerApp: App {
    @StateObject private var permissions = PermissionStore(permissions: [.camera, .photoLibrary, .notifications])

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(permissions)
        }
    }
}
```

Requests from the store don't throw. They return the status, or `nil` and set `lastError`, which suits views that show an alert rather than a `do`/`catch`:

```swift
VStack {
    Button("Enable Notifications") {
        Task { await permissions.request(.notifications) }
    }
    if let error = permissions.lastError {
        Text(error.description).font(.footnote)   // e.g. a missing usage description in a debug build
    }
}
```

## Views that do the right thing for every status

Part 1 argued that seven statuses each need different UI. The built-in views encode that once.

**`PermissionGate`** shows your content when access is granted, and a pre-permission prompt until then:

```swift
struct ScannerScreen: View {
    @EnvironmentObject private var permissions: PermissionStore

    var body: some View {
        PermissionGate(.camera, message: "Scan receipts with your camera.", store: permissions) {
            ScannerView()
        }
    }
}
```

The prompt picks its action from the status: **Continue** when a prompt can appear, **Open Settings** when `.denied` (or `.limited` with no upgrade left), and no button when `.restricted` or `.unavailable`, because neither the user nor Settings can help. Asking with a pre-permission screen first is what Apple's Human Interface Guidelines recommend: the user learns *why* before iOS asks *whether*.

Bring your own fallback when the design calls for it:

```swift
PermissionGate(.microphone, store: permissions) {
    Recorder()
} fallback: { status in
    MicrophoneOnboarding(status: status) {
        Task { await permissions.request(.microphone) }
    }
}
```

**`PermissionRow`** and **`PermissionsList`** build a privacy screen. A row shows the icon, name and status, plus the next action. Its button says **Allow** for `.notDetermined` and **Allow More** when an upgrade is possible, using `store.canRequest(_:)` rather than the status. That's Part 2's `canRequest(from:)` reaching the UI: `.limited` location gets an Allow More button, `.limited` photos doesn't.

```swift
PermissionsList([.camera, .locationWhenInUse, .notifications],
                footer: "You can change these at any time in Settings.",
                store: permissions)
```

The built-in views open Settings with SwiftUI's `openURL(AppSettings.url(for:))`, so they compile inside app extensions too (Part 3).

## Coming back from Settings

The user taps Open Settings, flips the switch, and returns. The app has to notice. The built-in views re-read statuses when the scene becomes active. For your own views, one modifier does the same:

```swift
MyCustomPrivacyScreen()
    .refreshesPermissions(permissions)
```

It watches `scenePhase` and calls `store.refresh()`, which asks the manager to re-read every permission it has seen and publishes only the ones that changed.

## Testing: real logic, fake system

The usual way to test permission code is to mock a `PermissionsHelper` protocol. That tests your view model against your own assumptions about how permissions behave. You never exercise coalescing, the missing-key guard or the streams, which is where the bugs are.

SwiftPermissions inverts it: keep the real `PermissionManager`, and stub at the provider, the only layer that talks to the system. Back to the kitchen analogy: keep the real kitchen, swap in a fake supplier.

```swift
import Testing
import SwiftPermissionsTesting

@Test func scannerShowsSettingsHintWhenDenied() async {
    let camera = StubPermissionProvider(.camera, status: .notDetermined, onRequest: .deny)
    let model = ScannerModel(permissions: PermissionManager.stubbed(camera))

    await model.start()

    #expect(model.showsSettingsHint)
    #expect(await camera.requestCount == 1)
}
```

`StubPermissionProvider` is an actor you script:

| Want to test | Stub it like this |
| --- | --- |
| The user allows / declines | `onRequest: .grant` / `.deny` |
| Partial access | `onRequest: .status(.limited)` |
| Framework failure | `onRequest: .fail(MyError())` |
| An upgrade prompt | `status: .limited, upgradableFrom: [.limited]` |
| Concurrent callers | `requestDelay: 0.2` |
| User changes it in Settings | `await stub.setStatus(.denied)`, then `refresh()` |
| Prompt count, status reads | `requestCount`, `statusReadCount` |

`PermissionManager.stubbed(_:)` builds a real manager with only your stubs registered and usage-description checks turned off, so tests behave the same on your Mac and on a CI simulator that has never seen a prompt. Nothing in the test suite ever shows a real system dialog.

The store is just as testable, because it takes `any PermissionManaging`:

```swift
@MainActor
@Test func rowOffersUpgradeFromWhenInUse() async {
    let location = StubPermissionProvider(.locationAlways, status: .limited, upgradableFrom: [.limited])
    let store = PermissionStore(manager: PermissionManager.stubbed(location))

    await store.load([.locationAlways])

    #expect(store.canRequest(.locationAlways))
}
```

### Previews

The same stubs make previews show every state without a device:

```swift
#Preview("Denied") {
    ScannerScreen()
        .environmentObject(PermissionStore(manager: PermissionManager.stubbed([.camera: .denied])))
}
```

## Catch the missing key before App Review does

Part 2's guard stops a missing usage description from killing the app. Better still is never shipping one. `missingUsageDescriptions(for:)` reads the keys every registered provider needs and checks them against an Info.plist you choose:

```swift
@Test func infoPlistDeclaresEveryPermissionWeUse() {
    let used: [Permission] = [.camera, .photoLibrary, .locationWhenInUse]
    let manager = PermissionManager(
        permissions: [.camera, .photoLibrary, .locationWhenInUse],
        usageDescriptions: InfoPlist(bundle: appBundle)
    )
    #expect(manager.missingUsageDescriptions(for: used).isEmpty)
}
```

It knows the version-specific rules so you don't have to: iOS 17's separate full and write-only calendar keys, the Always location key that macOS doesn't use, the HealthKit share and update keys.

The repository's [agent skill](../plugin/skills/swiftpermissions/SKILL.md) ships the same check as a script that reads your source and project files without building:

```bash
python3 plugin/skills/swiftpermissions/scripts/check_usage_descriptions.py path/to/YourApp
```

It finds your registrations in `PermissionManager(permissions:)` and `PermissionStore(permissions:)` literals, then looks for each key in Info.plist files, `INFOPLIST_KEY_*` build settings and xcconfigs. Run it in CI, or let your coding agent run it after adding a permission.

## Recap

- One `PermissionStore` per app, injected; it mirrors the manager on the main actor.
- `PermissionGate`, `PermissionRow` and `PermissionsList` encode the right action for each of the seven statuses, including upgrades.
- `.refreshesPermissions(_:)` picks up changes made in Settings.
- Test the real manager with stubbed providers: coalescing, guards and streams included, no prompts.
- Assert usage descriptions in a unit test or with the checker script, not in App Review.

That's the series. The [README](../README.md) has the full permission table, and the [Example app](../Example) runs every permission on a simulator or device.
