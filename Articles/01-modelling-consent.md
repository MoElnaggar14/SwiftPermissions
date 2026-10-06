# Modelling consent: one vocabulary for every Apple permission

> I once shipped a camera feature that asked for photo access, location and notifications in the first ten seconds. The App Store rating told me what users thought of that before analytics did.

Every Apple framework that guards personal data asks for consent in its own dialect. `AVCaptureDevice` has `AVAuthorizationStatus`. Photos has `PHAuthorizationStatus` with a `.limited` case. Core Location has `CLAuthorizationStatus` with two "authorized" flavours. Notifications have `.provisional` and `.ephemeral`. HealthKit won't tell you whether the user allowed reading at all. Some APIs are async, some take callbacks, one needs a delegate, and Bluetooth asks the moment you create a manager.

Most apps end up with a `PermissionsHelper` that grows a `switch` per framework and a boolean per feature. SwiftPermissions starts from the other end: what does the *app* need to know, and what's the smallest model that answers it?

## Start from the screen, not the framework

Working backwards from the UI, a feature needs to answer four questions about a permission:

1. Can I use the feature now? Fully, or only partly?
2. If not, can I still ask, or is Settings the only way forward?
3. Is this something the user can't change (parental controls, MDM, missing hardware)?
4. Did something go wrong that I, the developer, need to fix?

Questions 1–3 are about the user's decision. Question 4 is about the app. They belong in different types.

## The domain: three small types

### `Permission`: an open set, not an enum

```swift
public struct Permission: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: String
    public let displayName: String
}

public extension Permission {
    static let camera = Permission("camera", displayName: "Camera")
    static let photoLibrary = Permission("photoLibrary", displayName: "Photos")
    // … every system permission
}
```

An enum would have been the obvious choice, and the wrong one. Your app might gate a feature on a third-party SDK's consent, on the local network, or on a permission Apple adds next year. A struct with static members reads exactly like an enum at the call site (`.camera`), but anyone can add a member:

```swift
extension Permission {
    static let localNetwork = Permission("localNetwork", displayName: "Local Network")
}
```

Identity is the raw value only. The display name is presentation, so two `Permission`s with the same raw value are equal even if one was decoded from disk without its display name.

### `PermissionStatus`: seven cases, nothing lost

```swift
public enum PermissionStatus: String, Sendable, Codable, CaseIterable {
    case notDetermined   // never asked: a request shows the prompt
    case denied          // the user said no: only Settings can change it
    case restricted      // a policy said no: the user can't change it
    case authorized      // full access
    case limited         // partial: selected photos, write-only calendar, when-in-use for Always
    case provisional     // quiet notifications, granted without asking
    case unavailable     // no such hardware or capability on this device
}
```

Think of it as a hotel key card. Every hotel's lock system is different, but the card at the front desk only needs to say: no card yet, refused, this floor is off limits, all access, some floors only, a trial card, or this hotel has no such floor. The front desk doesn't care whether the lock is magnetic or RFID; the providers translate.

The tempting simplification is a `Bool`. It throws away exactly the distinctions UX depends on:

- `.limited` photos means show the picker for *more* photos, not a "grant access" screen.
- `.provisional` notifications already arrive quietly; asking again upgrades them.
- `.restricted` means don't show an "Open Settings" button, because Settings won't help.
- `.unavailable` means hide the feature, not nag about it.

Three computed properties answer the common questions without a `switch`:

```swift
status.isGranted         // .authorized, .limited or .provisional
status.canRequest        // .notDetermined: a prompt will appear
status.requiresSettings  // .denied: send them to Settings
```

The case list is frozen for every 3.x release, so you can switch exhaustively without a `default`. A new permission maps onto these seven cases; a new case only arrives in a major version.

### `PermissionError`: the developer's problems, typed

```swift
public enum PermissionError: Error, Sendable, Equatable {
    case providerNotRegistered(Permission)
    case missingUsageDescription(Permission, keys: [String])
    case requestFailed(Permission, reason: String)
    case cancelled(Permission)
}
```

A user tapping "Don't Allow" is not an error. It's an answer, and it comes back as `.denied`. Errors are reserved for things the *app* got wrong or gave up on: the provider isn't linked, the Info.plist key is missing, the framework failed, or the calling task was cancelled.

`request(_:)` uses typed throws, so the compiler knows `catch` gives you a `PermissionError`, not `any Error`:

```swift
do {
    let status = try await permissions.request(.camera)
    render(status)
} catch {
    // `error` is a PermissionError here.
    print(error)   // e.g. "Add NSCameraUsageDescription to Info.plist before requesting 'camera'."
}
```

Every description says what to do, not just what went wrong. `providerNotRegistered` names the product to link.

## Ports: depend on the narrowest question

The manager's surface is split into three protocols, one per question a component might ask:

```swift
public protocol PermissionStatusReading: Sendable {
    func status(of permission: Permission) async -> PermissionStatus
}

public protocol PermissionRequesting: Sendable {
    func request(_ permission: Permission) async throws(PermissionError) -> PermissionStatus
    func canRequest(_ permission: Permission) async -> Bool
}

public protocol PermissionObserving: Sendable {
    func updates(for permission: Permission) -> AsyncStream<PermissionStatus>
    func changes() -> AsyncStream<PermissionChange>
}

public typealias PermissionManaging = PermissionStatusReading & PermissionRequesting & PermissionObserving
```

A settings screen that only shows status takes a `PermissionStatusReading`. It can't show a prompt by accident, and its test double is one method. This is interface segregation doing real work: the type signature documents that the screen is read-only.

## Providers: the adapters at the edge

The domain never mentions AVFoundation. Each framework hides behind a `PermissionProvider`:

```swift
public protocol PermissionProvider: Sendable {
    var permission: Permission { get }
    var requiredUsageDescriptionKeys: [String] { get }
    func status() async -> PermissionStatus           // must never show UI
    func canRequest(from status: PermissionStatus) -> Bool
    func request() async throws -> PermissionStatus   // a "no" is a status, not a throw
}
```

That's the whole contract. A provider translates one framework's dialect into the shared vocabulary, and declares which Info.plist keys its prompt needs. The manager looks providers up by `Permission` and never switches over permission kinds, so adding one never touches the core.

`canRequest(from:)` deserves a note. The status alone can't tell you whether a prompt can still appear. `.limited` location (when-in-use while you wanted Always) *can* be upgraded with another prompt. `.limited` photos can't. Only the provider knows, so the provider answers.

## The shape of it

```
              your features
                    │  depend on ports
┌───────────────────▼──────────────────────┐
│ Domain:  Permission · Status · Error     │
│ Ports:   Reading · Requesting · Observing│
│ PermissionManager (actor)                │
└───────────────────▲──────────────────────┘
                    │  implement PermissionProvider
    Camera · Photos · Location · Health · your own
```

Dependencies point inwards. Features depend on protocols, the manager depends on the provider protocol, and only the providers import privacy frameworks. Part 3 explains why that last rule matters to App Review, not just to architecture diagrams.

## What you get

```swift
import SwiftPermissions
import SwiftPermissionsCamera

let permissions = PermissionManager(permissions: [.camera])

switch try await permissions.request(.camera) {
case .authorized:                 startCapture()
case .limited:                    startCapture(limited: true)
case .denied:                     await AppSettings.open(for: .camera)
case .restricted, .unavailable:   hideCameraFeature()
case .notDetermined, .provisional: break
}
```

One vocabulary, one async call, and an exhaustive `switch` that the compiler keeps honest.

Next: [the control tower](02-the-control-tower.md), where the manager makes sure two screens asking at once see one prompt, and nothing ever hangs.
