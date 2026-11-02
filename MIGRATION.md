# Migrating from 3.x to 4.0

4.0 has one breaking change: `PermissionStatus.limited` carries the reason access is limited, `case limited(Limitation)`. If you already moved to the 3.6 replacements, your code compiles unchanged.

```swift
switch try await permissions.request(.photoLibrary) {
case .authorized:              showLibrary()
case .limited(.selectedItems): showLibrary(banner: .selectMore)   // new: the reason
case .limited:                 showLibrary()                      // unchanged: any reason
case .provisional:             break
case .denied:                  await AppSettings.open(for: .photoLibrary)
case .notDetermined, .restricted, .unavailable: showUnavailableState()
}
```

| 3.x | 4.0 |
| --- | --- |
| `status == .limited` | `status.isLimited`, or `status == .limited(.selectedItems)` for one reason |
| `.limited` built as a value, e.g. `StubPermissionProvider(.photoLibrary, status: .limited)` | `.limited(.selectedItems)` (or `.whenInUse`, `.writeOnly`, `.partial`) |
| `upgradableFrom: [.limited]` | `upgradableFrom: [.limited(.whenInUse)]` |
| `status.rawValue` | `status.description` |
| `PermissionStatus(rawValue:)` | `Codable` (`JSONDecoder().decode(PermissionStatus.self, …)`) |
| `PermissionStatus.allCases` | list the statuses you need |
| — | `status.limitation` (`Limitation?`) reads the reason |

`case .limited:` in a `switch` compiles unchanged and matches every reason.

What each reason means:

| `Limitation` | Reported for |
| --- | --- |
| `.selectedItems` | Selected photos, selected contacts (iOS 18) |
| `.whenInUse` | `.locationAlways` granted only When In Use |
| `.writeOnly` | `.calendar` granted write-only |
| `.partial` | Some HealthKit share types; anything else |

## Logging and stored data

- `description` of a limited status is now `"limited.selectedItems"` (and so on); other statuses are unchanged. If your analytics group by `"limited"`, use `status.isLimited` or split by reason.
- The `Codable` form is the same string. `PermissionFlowProgress` and `UserDefaultsRequestHistory` store it.
- **Data saved by 3.x still reads.** A stored `"limited"` has no reason, so it reads as the reason the built-in provider meant for that permission: `.selectedItems` for photos and contacts, `.whenInUse` for Always location, `.writeOnly` for calendar, `.partial` otherwise. A bare `JSONDecoder` decode of `"limited"` reads `.limited(.partial)`.
- **Rolling back to 3.6 is safe.** 3.6 reads `"limited.selectedItems"` as `.limited`. Earlier 3.x releases don't; roll back to 3.6 or later.

## Custom providers

A `PermissionProvider` that returned `.limited` must pick a reason. `.partial` fits when nothing more specific does. In `canRequest(from:)`, compare with the reason you report, e.g. `status == .limited(.partial)`, or with `status.isLimited`.

## UI

`PermissionRow`, `PermissionPrompt` and `PermissionFlow` read the reason from the status instead of inferring it from the permission, so a custom provider's `.limited(.selectedItems)` gets **Select More…** too. `PermissionRow` shows the reason next to the status ("Limited · Selected Items"); `PermissionStatus.title` is still "Limited" and `Limitation.title` names the reason.

# Migrating from 2.x to 3.0

3.0 is a redesign around a domain model and per-permission providers. Most call sites change mechanically.

## Link only the permissions you use

Each system framework is now its own product. Add the ones you request and register them:

```swift
// Package.swift
.product(name: "SwiftPermissions", package: "SwiftPermissions"),
.product(name: "SwiftPermissionsCamera", package: "SwiftPermissions"),
.product(name: "SwiftPermissionsLocation", package: "SwiftPermissions"),

// App
let permissions = PermissionManager(permissions: [.camera, .locationWhenInUse, .notifications])
```

2.x linked every privacy framework into your app, so App Store review could ask for usage descriptions of permissions you never request. See the README for the product of each permission.

## API mapping

| 2.x | 3.0 |
| --- | --- |
| `PermissionType` (enum) | `Permission` (open struct; same static members) |
| `.notification` | `.notifications` |
| `.location` | `.locationWhenInUse` |
| `.faceID`, `.touchID` | `.biometrics` |
| `PermissionManagerProtocol` | `PermissionManaging` (= `PermissionStatusReading & PermissionRequesting & PermissionObserving`) |
| `PermissionManagerFactory.default()` | `PermissionManager(permissions: [...])` |
| `status(for:)` | `status(of:)` |
| `request(_:config:) -> PermissionResult` | `try request(_:) -> PermissionStatus` (throws `PermissionError`) |
| `requestMultiple(_:) -> [PermissionResult]` | `request(_:) -> PermissionBatchResult` |
| `canRequest(_:)` | `canRequest(_:)` (async; also true when an upgrade prompt can appear) |
| `PermissionStatus.isAuthorized` | `isGranted` |
| `PermissionStatus.canBeRequested` | `canRequest` |
| `permissionStatusChanged` (Combine) | `updates(for:)` / `changes()` (`AsyncStream`) |
| `openSettings()` | `await AppSettings.open(for:)` |
| `MockPermissionManager` | `PermissionManager.stubbed(...)` + `StubPermissionProvider` (in `SwiftPermissionsTesting`) |
| `ObservablePermissionManager` | `PermissionStore` |
| `PermissionStatusView` | `PermissionRow` |
| `PermissionsDashboardView` | `PermissionsList` (embed in your own `NavigationStack`) |
| `PermissionConfig` | removed (it was never used). Pass `message:` to `PermissionGate`/`PermissionPrompt`. |

## Behaviour changes

- **Statuses are no longer collapsed.** Limited photo access returns `.limited` (it used to return `.authorized`). Write-only calendar access returns `.limited` for `.calendar`. Parental controls return `.restricted` (they used to return `.denied`). `isGranted` treats `.limited` and `.provisional` as granted.
- **Missing usage descriptions throw** `PermissionError.missingUsageDescription` instead of letting the system terminate the app.
- **Unsupported permissions** report `.unavailable` from `status(of:)` and throw `.providerNotRegistered` from `request(_:)`.
- **Nothing is registered by default** except notifications. Requesting an unregistered permission throws `.providerNotRegistered`, naming the product to add.
- **Health** needs your data types: `.health(share:read:)` from `SwiftPermissionsHealth`. Without the HealthKit capability its status is `.unavailable`.
- **Biometrics** never prompts from `request(_:)`; use `BiometricsPermissionProvider().authenticate(reason:)`.
- **Requirements:** Swift 6 / Xcode 16. watchOS 9 minimum (was 8).

## Before / after

```swift
// 2.x
let manager = PermissionManagerFactory.default()
let result = await manager.request(.camera, config: nil)
if result.isSuccess { start() }

// 3.0
let manager = PermissionManager(permissions: [.camera])
if try await manager.request(.camera).isGranted { start() }
```
