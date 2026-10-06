# Preparing for 4.0

In 4.0, `PermissionStatus.limited` carries the reason access is limited: `case limited(Limitation)`. 3.6 adds the replacements first, so you can move before upgrading. Nothing breaks in 3.6; `rawValue` only gets a deprecation warning.

| Breaks in 4.0 | 3.6 replacement |
| --- | --- |
| `status == .limited` | `status.isLimited` |
| `.limited` built as a value, e.g. `StubPermissionProvider(.photoLibrary, status: .limited)` | `.limited(.selectedItems)` (in 3.x it builds `.limited`) |
| `status.rawValue`, `PermissionStatus(rawValue:)` | `status.description` for logging, `Codable` for storage |
| `PermissionStatus.allCases` | none; list the statuses you need |

`case .limited:` in a `switch` compiles unchanged in 4.0. A custom `PermissionProvider` that returns `.limited` should return `.limited(.partial)` (or a more specific reason), and compare with `status.isLimited` in `canRequest(from:)`.

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
