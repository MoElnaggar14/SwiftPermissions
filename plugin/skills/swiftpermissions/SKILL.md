---
name: swiftpermissions
description: Integrate and use the SwiftPermissions 3.x Swift package to request Apple privacy permissions (camera, microphone, photos, contacts, calendar, reminders, location, notifications, Bluetooth, tracking/ATT, speech, motion, Siri, media library, Face ID/biometrics, HealthKit) in iOS, macOS, tvOS or watchOS apps. Use this skill whenever the user's project imports SwiftPermissions or depends on it in Package.swift, whenever they ask to add, request, check, test or show UI for an app permission in Swift/SwiftUI, hit a missing NS…UsageDescription crash or an App Store ITMS-90683 rejection, or are upgrading from SwiftPermissions 2.x — even if they don't name the package.
---

# SwiftPermissions 3.x

SwiftPermissions gives every Apple permission one async API: `PermissionManager` (an actor) asks a registered `PermissionProvider` per permission and returns a normalised `PermissionStatus`. Each framework lives in its own product, so the app links only the privacy frameworks it really uses. That matters because App Review scans the binary and asks for usage descriptions of any permission code it finds.

Think of the manager as an airport control tower and providers as airlines: the tower sequences prompts and announces status changes, but an airline only flies there if you link its product **and** register it.

## Workflow

Work through these steps in order. Most integration bugs come from skipping step 1 or step 4.

### 1. Decide which permissions are really needed

Before adding a permission, check whether a permission-free API does the job. Users never see a prompt for these, and the app needs no usage description:

| Need | Use instead | Product needed |
| --- | --- | --- |
| Let the user pick photos | `PhotosPicker` / `PHPickerViewController` | none |
| One-off current location | `LocationButton` / `CLLocationButton` | none |
| Pick a few contacts (iOS 18+) | `ContactAccessButton`, `CNContactPickerViewController` | none |
| Save to Photos only | `.photoLibraryAddOnly` (not `.photoLibrary`) | Photos |
| Add events only | `.calendarWriteOnly` (not `.calendar`) | Calendar |

Suggest the alternative when it fits; ask the user if unsure.

### 2. Add one product per framework

```swift
.package(url: "https://github.com/MoElnaggar14/SwiftPermissions", from: "3.0.0"),

.target(name: "App", dependencies: [
    .product(name: "SwiftPermissions", package: "SwiftPermissions"),        // Core + SwiftUI
    .product(name: "SwiftPermissionsCamera", package: "SwiftPermissions"),  // .camera / .microphone
])
```

In an Xcode project, add the same products under the target's "Frameworks, Libraries, and Embedded Content". Use `SwiftPermissionsCore` instead of `SwiftPermissions` when the target must not import SwiftUI. Add `SwiftPermissionsTesting` only to test targets and previews.

The table of permissions, products, platforms and Info.plist keys is in [references/permissions.md](references/permissions.md). Read it whenever you add or remove a permission.

### 3. Register in one place and inject it

Create one manager at the app's composition root and pass it down. Don't create a manager per screen, and don't make a singleton. A shared instance is what lets concurrent requests for the same permission share one prompt.

```swift
import SwiftPermissions
import SwiftPermissionsCamera
import SwiftPermissionsLocation

@main
struct MyApp: App {
    @StateObject private var permissions = PermissionStore(
        permissions: [.camera, .microphone, .locationWhenInUse, .notifications]
    )
    var body: some Scene {
        WindowGroup { RootView().environmentObject(permissions) }
    }
}
```

Outside SwiftUI, use `PermissionManager(permissions: [...])` and inject it as `any PermissionManaging`. A type that only needs to read status should depend on the narrower `PermissionStatusReading`.

`.notifications` comes from Core; every other registration needs its product's `import`. Requesting a permission that isn't registered throws `PermissionError.providerNotRegistered`, and its message names the product to add.

### 4. Add the Info.plist keys and verify them

Every registered permission except notifications needs a usage description. Without one, iOS terminates the app. SwiftPermissions throws `missingUsageDescription` instead, but the feature still won't work. Write descriptions that say what the user gets ("Scan receipts with your camera"), not "This app needs camera access."

Watch out for these keys:
- Calendar and reminders use different keys on iOS 17+ than earlier. Add both when the deployment target is below iOS 17.
- `.locationAlways` needs both the when-in-use key and `NSLocationAlwaysAndWhenInUseUsageDescription`.
- `.siri` and `.health(...)` also need a capability (entitlement) in Signing & Capabilities.

Then run the bundled checker from the app's repository root:

```bash
python3 <skill-dir>/scripts/check_usage_descriptions.py .
```

It finds the registrations in the Swift sources and the keys in Info.plist files, `INFOPLIST_KEY_*` build settings and `.xcconfig` files. It reports missing keys, products imported but never registered (dead weight that App Review still scans), and registrations whose product is never imported. It exits non-zero when something is missing, so it can also run in CI. Pass `--ios-deployment-target 16` when the target is below 17, so it requires the legacy calendar keys.

Also suggest a unit test that runs on every build. See "Testing" below.

### 5. Request at the moment of use and handle every status

Ask when the user taps the feature, not at launch. A prompt with context gets accepted far more often, and a denial can't be asked again.

With a `PermissionManager` (or `any PermissionManaging`), `request(_:)` throws:

```swift
do {
    switch try await permissions.request(.camera) {
    case .authorized:          startCapture()
    case .limited:             startCapture(limited: true)
    case .denied:              showSettingsHint()      // await AppSettings.open(for: .camera)
    case .restricted:          showRestrictedState()   // parental controls / MDM; Settings can't fix it
    case .unavailable:         hideFeature()           // no hardware, service off, capability missing
    case .notDetermined, .provisional: break
    }
} catch let PermissionError.missingUsageDescription(_, keys) {
    assertionFailure("Add \(keys) to Info.plist")
} catch {
    // .providerNotRegistered, .requestFailed, .cancelled
}
```

Keep these behaviours in mind:
With a `PermissionStore`, `request(_:)` doesn't throw. It returns `PermissionStatus?` (nil on failure) and sets `store.lastError`:

```swift
guard let status = await store.request(.camera) else {
    if case .missingUsageDescription(_, let keys)? = store.lastError { assertionFailure("Add \(keys) to Info.plist") }
    return
}
if status.isGranted { startCapture() } else if status.requiresSettings { showSettingsHint() }
```

- The manager's `request(_:)` throws `PermissionError` (typed throws). `.cancelled` means the calling task was cancelled; the prompt stays up for other callers.
- `isGranted` is true for `.authorized`, `.limited` and `.provisional`.
- **Upgrades.** `request(_:)` also upgrades a partial grant: when-in-use → Always, write-only → full calendar, provisional → full notifications. A status alone can't tell you whether another prompt can appear (`.limited` location can be upgraded, `.limited` photos can't), so call `await permissions.canRequest(.x)` or `store.canRequest(.x)` before you show an "Allow" button.
- Requests made while the app is in the background wait until it is active. Location reports `.unavailable` when Location Services are off system-wide.
- Biometrics never prompts from `request(_:)`. Call `BiometricsPermissionProvider().authenticate(reason:)` when the user authenticates.
- Live status: `for await status in permissions.updates(for: .camera)`, or `changes()` for every permission.

### 6. SwiftUI components (optional)

- `PermissionGate(.camera, message: "…", store: store) { Content() }` shows the content once granted. Until then it shows a prompt with the right action (Continue, Open Settings, or nothing). A `fallback: { status in … }` closure replaces the built-in prompt.
- `PermissionPrompt(.x, message:store:)` is the prompt card on its own. `PermissionRow(.x, store:)` is one row, with an "Allow More" button when an upgrade is possible.
- `PermissionsList([...], footer:store:)` is a list for onboarding or a privacy settings screen. "Allow All" asks only for permissions that are still undetermined.
- `.refreshesPermissions(store)` makes your own view refresh when the user returns from Settings.

### 7. Testing

Use the real manager with stubs rather than mocking the protocol, so tests exercise the real coalescing and caching:

```swift
import Testing
import SwiftPermissionsTesting

@Test func deniedCameraShowsSettingsHint() async {
    let camera = StubPermissionProvider(.camera, status: .notDetermined, onRequest: .deny)
    let model = ScannerModel(permissions: PermissionManager.stubbed(camera))
    await model.start()
    #expect(model.showsSettingsHint)
    #expect(await camera.requestCount == 1)
}
```

- `onRequest:` takes `.grant`, `.deny`, `.status(...)` or `.fail(error)`.
- `upgradableFrom: [.limited]` simulates an upgrade prompt, and `requestDelay:` simulates a slow prompt for concurrency tests.
- For a SwiftUI app built around the store, inject a stubbed manager: `PermissionStore(manager: PermissionManager.stubbed(camera))`. For previews, use `PermissionStore(manager: PermissionManager.stubbed([.camera: .denied]))`.
- `import SwiftPermissionsTesting` also brings in `PermissionManager` and `Permission`.

Guard the Info.plist with a unit test. The test must be hosted by the app, so `Bundle.main` is the app's bundle, and the test target must link the framework products it registers, besides `SwiftPermissionsTesting`:

```swift
@Test func infoPlistDeclaresEveryPermission() {
    let used: [Permission] = [.camera, .microphone, .locationWhenInUse]
    let manager = PermissionManager(permissions: [.camera, .microphone, .locationWhenInUse],
                                    usageDescriptions: InfoPlist(bundle: .main))
    #expect(manager.missingUsageDescriptions(for: used).isEmpty)
}
```

## Custom permissions

Conform to `PermissionProvider` (`permission`, `requiredUsageDescriptionKeys`, `status()`, `request()`; optionally `canRequest(from:)` for upgrades), then register it with `.provider(MyProvider())`. Declare the permission with `Permission("localNetwork", displayName: "Local Network")`. Registering a provider for a built-in permission replaces how that permission is requested.

## Upgrading from 2.x

Read [references/migration-2x.md](references/migration-2x.md) when the code uses `PermissionType`, `PermissionManagerFactory`, `requestMultiple`, `MockPermissionManager`, `ObservablePermissionManager` or `PermissionResult`.

## Before you finish

- Every `.x` registration has its product added and imported.
- Every product added is registered. If one isn't, remove it.
- Every permission has its Info.plist key, and `check_usage_descriptions.py` passes.
- Every status is handled, including `.restricted` and `.unavailable`.
- There is one manager or store, injected rather than global.
