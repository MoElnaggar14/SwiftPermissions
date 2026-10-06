# Link only what you use: modular products and App Review

> "Your app's code references one or more APIs that access sensitive user data. The app's Info.plist file should contain a NSLocationWhenInUseUsageDescription key." My app had no location feature. My permissions library did.

Parts 1 and 2 were about types and concurrency. This part is about something architecture diagrams rarely show: what ends up in your binary, and who reads it.

## App Review reads your binary

When you upload a build, Apple's tooling scans it for code that can request a protected resource. If it finds `CLLocationManager.requestWhenInUseAuthorization` it expects `NSLocationWhenInUseUsageDescription`, whether or not your app ever calls it. A missing key means an automatic rejection email. A placeholder string ("We need location") invites a human reviewer to ask what for.

This is why "one library for every permission" designs keep backfiring. The convenient monolith links AVFoundation, Photos, Contacts, EventKit, Core Location, HealthKit and the rest into every app that uses it. A note-taking app that wants notifications ends up explaining to App Review why it might ask for HealthKit.

SwiftPermissions 2.x had exactly this problem. 3.0 fixed it with the package layout.

## One product per framework

```swift
let frameworks = [
    "Camera", "Photos", "Contacts", "Calendar", "Location", "Bluetooth", "Motion",
    "Speech", "MediaLibrary", "Siri", "Tracking", "Biometrics", "Health"
]

products: [
    .library(name: "SwiftPermissions", targets: ["SwiftPermissions"]),          // Core + SwiftUI
    .library(name: "SwiftPermissionsCore", targets: ["SwiftPermissionsCore"]),
    .library(name: "SwiftPermissionsUI", targets: ["SwiftPermissionsUI"]),
    .library(name: "SwiftPermissionsTesting", targets: ["SwiftPermissionsTesting"]),
] + frameworks.map { .library(name: "SwiftPermissions\($0)", targets: ["SwiftPermissions\($0)"]) }
```

Think of it as a power strip with switched sockets. The strip (Core) is always there; each socket (framework product) only draws current when something is plugged in. A camera app links two products:

```swift
.target(name: "App", dependencies: [
    .product(name: "SwiftPermissions", package: "SwiftPermissions"),
    .product(name: "SwiftPermissionsCamera", package: "SwiftPermissions"),
])
```

Its binary contains AVFoundation's request API and nothing else. Notifications live in Core because they need no usage description; every other framework is opt-in.

The rule that makes it work is enforced, not hoped for. CI greps Core, UI and the umbrella module for imports of any privacy framework and fails the build if it finds one:

```bash
FRAMEWORKS='AVFoundation|Photos|Contacts|EventKit|CoreLocation|CoreBluetooth|CoreMotion|Speech|MediaPlayer|Intents|AppTrackingTransparency|LocalAuthentication|HealthKit'
grep -rnE "^\s*(@preconcurrency\s+)?import\s+($FRAMEWORKS)\b" \
    Sources/SwiftPermissionsCore Sources/SwiftPermissionsUI Sources/SwiftPermissions && exit 1
```

A convenience helper sneaking `import CoreLocation` into Core would silently add a usage-description requirement to every app using the package. The grep makes that a red build instead.

## Registration: you register what you link

If Core can't import AVFoundation, how does `PermissionManager` know about the camera? It doesn't, until you tell it. Each framework product adds static members to `PermissionRegistration`:

```swift
// In SwiftPermissionsCamera
public extension PermissionRegistration {
    static var camera: PermissionRegistration { PermissionRegistration(CaptureDevicePermissionProvider.camera) }
    static var microphone: PermissionRegistration { PermissionRegistration(CaptureDevicePermissionProvider.microphone) }
}
```

So the composition root reads like a list of what the app does:

```swift
import SwiftPermissions
import SwiftPermissionsCamera
import SwiftPermissionsPhotos

let permissions = PermissionManager(permissions: [.camera, .photoLibrary, .notifications])
```

`.camera` only autocompletes once you import its product. The compiler has become your linker checklist: you can't register a permission you haven't linked, and you won't link one you don't register.

Forget a registration and the error tells you exactly what to do:

```
No provider registered for 'camera'. Link the SwiftPermissionsCamera product and pass
.camera to PermissionManager(permissions:). If you did, 'camera' isn't available on this platform.
```

That last sentence matters. Some registrations don't exist on every platform: `.locationAlways` isn't available on tvOS or visionOS, so it isn't declared there. Requesting an unregistered permission throws; reading its status returns `.unavailable`, so a status-only screen degrades gracefully.

## Configured registrations

Some permissions need more than a name. HealthKit needs the types you'll read and write; notifications need the options you'll ask for. Those registrations are functions:

```swift
import SwiftPermissionsHealth

let permissions = PermissionManager(permissions: [
    .health(share: [HKQuantityType(.stepCount)], read: [HKQuantityType(.heartRate)]),
    .notifications(options: [.alert, .sound, .provisional]),
])
```

Asking with `.provisional` delivers notifications quietly without a prompt. Because the provider knows its own options, it also knows that a later request *without* `.provisional` can upgrade the user to full notifications, and says so through `canRequest(from:)`.

## Your own permissions, and replacing built-in ones

`PermissionProvider` is the extension point. Here's a provider wrapping a third-party SDK's consent flow:

```swift
extension Permission {
    static let analyticsConsent = Permission("analyticsConsent", displayName: "Analytics")
}

struct AnalyticsConsentProvider: PermissionProvider {
    let sdk: ConsentSDK
    var permission: Permission { .analyticsConsent }

    func status() async -> PermissionStatus {
        switch await sdk.currentConsent() {
        case .unknown: .notDetermined
        case .granted: .authorized
        case .refused: .denied
        }
    }

    func request() async throws -> PermissionStatus {
        try await sdk.presentConsentForm()
        return await status()
    }
}

let permissions = PermissionManager(permissions: [
    .camera,
    .provider(AnalyticsConsentProvider(sdk: consentSDK)),
])
```

You get coalescing, cancellation, streams and the SwiftUI views for free, because they live in the manager and the store, not in the providers.

Registration order resolves conflicts: a later registration for the same permission replaces an earlier one. That's how you change how a built-in permission is requested without forking. For example, you can wrap the camera provider to log every prompt:

```swift
struct LoggingProvider: PermissionProvider {
    let base: any PermissionProvider
    let log: @Sendable (String) -> Void

    var permission: Permission { base.permission }
    var requiredUsageDescriptionKeys: [String] { base.requiredUsageDescriptionKeys }
    func status() async -> PermissionStatus { await base.status() }
    func canRequest(from status: PermissionStatus) -> Bool { base.canRequest(from: status) }
    func request() async throws -> PermissionStatus {
        log("Prompting for \(permission)")
        return try await base.request()
    }
}

let permissions = PermissionManager(permissions: [
    .provider(LoggingProvider(base: CaptureDevicePermissionProvider.camera, log: { print($0) }))
])
```

This is the open/closed principle with a practical payoff: the package is closed for modification, and every behaviour you might want to change is a provider.

## Safe inside app extensions

Widgets, notification service extensions and share extensions compile packages with `APPLICATION_EXTENSION_API_ONLY`. Reference `UIApplication.shared` anywhere and the extension target won't build, even if that code never runs there.

Core needs the shared application for one thing: knowing whether the app is active before asking (Part 2). It looks it up at runtime instead of referencing it:

```swift
// `UIApplication.shared` is unavailable in app extensions, so referencing it would stop
// Core from compiling into a widget or notification extension. Looking it up at runtime
// keeps Core extension-safe; it's `nil` inside an extension.
package static var sharedApplication: UIApplication? {
    UIApplication.value(forKey: "sharedApplication") as? UIApplication
}
```

APIs that truly can't work in an extension say so in their availability, so you get a compile error rather than a runtime surprise:

```swift
@available(iOSApplicationExtension, unavailable)
public static func open(for permission: Permission? = nil) async -> Bool   // AppSettings
```

The built-in SwiftUI views open Settings through SwiftUI's `openURL` and `AppSettings.url(for:)`, which work everywhere. A dedicated CI job builds every target extension-safe, so a regression fails the pull request.

## Recap

- App Review scans the binary, so the package boundary *is* the privacy boundary.
- Core, UI and the umbrella module import no privacy framework, and CI enforces it.
- Registrations come from the products you link; the compiler stops you registering one you haven't linked.
- Custom and replacement providers plug into the same manager and get every guarantee.
- Core stays extension-safe; extension-unsafe APIs are marked unavailable.

Next: [SwiftUI and tests without a single system prompt](04-swiftui-and-testing.md).
