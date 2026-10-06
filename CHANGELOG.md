# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Remember requests across launches.** A `PermissionRequestHistory` port in Core, with `InMemoryRequestHistory` (the default, unchanged behaviour) and `UserDefaultsRequestHistory(defaults:keyPrefix:)`. The Screen Recording, Accessibility and Local Network providers take a `history:` argument, and register with `.screenRecording(history:)`, `.accessibility(history:)` and `.localNetwork(serviceType:history:)`. With a persistent history, a declined Screen Recording or Accessibility request still reads `.denied` after a relaunch, and the local network reads its last result. A grant reported by the system always wins. `tccutil reset` clears the system's state but not the history; call `forget(_:)` to start over. Core's privacy manifest now declares `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`. ([#36](https://github.com/MoElnaggar14/SwiftPermissions/issues/36))

## [3.3.0] — 2026-10-06

New permissions for the Mac and the local network, iOS 18 location service sessions, and Select More for limited Photos and Contacts access, plus a fix for Bluetooth in AccessorySetupKit apps. Additive; no API changes.

### Added
- **macOS permissions.** `SwiftPermissionsScreenRecording`, `SwiftPermissionsAccessibility` and `SwiftPermissionsInputMonitoring` products with `.screenRecording`, `.accessibility` and `.inputMonitoring` registrations, backed by `CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess`, `AXIsProcessTrustedWithOptions` and `IOHIDCheckAccess` / `IOHIDRequestAccess`. None needs a usage description. Screen Recording and Accessibility read `.notDetermined` until the provider has asked in the current launch, then `.denied`, because macOS doesn't say whether the user declined. `AppSettings` opens their Privacy & Security panes. The products are empty on other platforms, Mac Catalyst included. ([#11](https://github.com/MoElnaggar14/SwiftPermissions/issues/11))
- **Select more photos and contacts.** With limited access, `PermissionRow` and `PermissionPrompt` can offer **Select More…** through a new optional `onSelectMore` closure, instead of nothing (row) or **Open Settings** (prompt). The framework products supply the pickers: `PhotoLibraryPermissionProvider.presentLimitedLibraryPicker(from:)` (iOS and Mac Catalyst) returns the identifiers of newly selected assets, and the `limitedContactsPicker(isPresented:onSelection:)` view modifier in `SwiftPermissionsContacts` presents the iOS 18 contact access picker. Existing initialisers are unchanged, and the UI module still imports no privacy framework. ([#7](https://github.com/MoElnaggar14/SwiftPermissions/issues/7))
- **Local network.** A `SwiftPermissionsLocalNetwork` product with `.localNetwork` and `.localNetwork(serviceType:)` registrations. iOS has no API for this permission, so `request()` runs a short Bonjour probe (`NWListener` + `NWBrowser`) that shows the prompt and maps the outcome: finding its own service is `.authorized`, `PolicyDenied` after the prompt closed is `.denied`, and a timeout leaves `.notDetermined`. `status()` is `.notDetermined` until a request has run, then the last result. It needs `NSLocalNetworkUsageDescription` and the probe's service type (`_swiftperms._tcp` by default) in `NSBonjourServices`. On tvOS and macOS before 15 the status is `.authorized`; on watchOS `.unavailable`. ([#4](https://github.com/MoElnaggar14/SwiftPermissions/issues/4))
- **Location service sessions.** On iOS 18, watchOS 11, tvOS 18 and visionOS 2, `LocationPermissionProvider.startServiceSession(fullAccuracyPurposeKey:)` starts a `CLServiceSession` at the provider's level and returns a `LocationServiceSession` that the app owns: the session lasts until `invalidate()` or until the handle is released. Its `updates` stream maps each `CLServiceSession.Diagnostic` onto `PermissionStatus` and includes the diagnostic as a `LocationSessionDiagnostic`. `request(_:)` through `CLLocationManager` stays the default. The example app shows a session. ([#9](https://github.com/MoElnaggar14/SwiftPermissions/issues/9))

### Changed
- `InfoPlist(bundle:)` also reads arrays of strings, such as `NSBonjourServices`, as their entries joined by newlines, so `requiredUsageDescriptionKeys` can name them.

### Fixed
- **Bluetooth with AccessorySetupKit.** On iOS 18+, when Info.plist lists `Bluetooth` under `NSAccessorySetupKitSupports`, iOS never shows the Bluetooth prompt and `CBManager.authorization` stays `.notDetermined`, even after pairing. `.bluetooth` now reports `.unavailable` in such an app, and `request(.bluetooth)` returns at once instead of waiting for a prompt that never appears. A `.denied`, `.restricted` or `.allowedAlways` from Core Bluetooth is still reported as before. The README and the agent skill explain the behaviour. ([#10](https://github.com/MoElnaggar14/SwiftPermissions/issues/10))

## [3.2.0] — 2026-10-06

Precise vs approximate location and the iOS 26 AlarmKit permission. Additive; no API changes.

### Added
- **Location accuracy.** `LocationPermissionProvider.accuracy()` returns `.full` or `.reduced` once location is authorized, so apps can tell that the user turned off Precise; `PermissionStatus` is unchanged. `requestTemporaryFullAccuracy(purposeKey:)` asks for precise location for the session, after checking the purpose string in `NSLocationTemporaryUsageDescriptionDictionary`. The example app shows both. ([#6](https://github.com/MoElnaggar14/SwiftPermissions/issues/6))
- **AlarmKit.** A `SwiftPermissionsAlarms` product with an `.alarms` registration for iOS 26 alarms and timers, which sound through Silent mode and Focus. It needs `NSAlarmKitUsageDescription`. Before iOS 26, on Mac Catalyst, and with SDKs that have no AlarmKit (Xcode 16), the status is `.unavailable`, so apps with an older deployment target register it without availability checks. ([#5](https://github.com/MoElnaggar14/SwiftPermissions/issues/5))

## [3.1.0] — 2026-10-06

A Not Now option for pre-permission prompts, notification settings that explain "allowed but silent", and an article series on the design. Additive; no API changes.

### Added
- **Notification settings.** `NotificationsPermissionProvider().settings()` returns a `NotificationSettingsSnapshot` with alert, sound, badge, lock screen, Notification Center, critical alert, time-sensitive and scheduled-delivery settings, plus the alert style and previews. `isEffectivelySilent` answers "notifications are allowed, so why don't I see them?". Fields a platform lacks read `.notSupported`. ([#8](https://github.com/MoElnaggar14/SwiftPermissions/issues/8))
- **Not Now.** `PermissionPrompt` and `PermissionGate` take an optional `onDefer` closure. When it's set, the prompt also shows a **Not Now** button while the permission can still be requested (including upgrades), so users can decline without spending the one-time system prompt. The package stores nothing; the app decides when to ask again. ([#12](https://github.com/MoElnaggar14/SwiftPermissions/issues/12))

### Fixed
- Release notes on GitHub link to `MIGRATION.md` and other repository files at the released tag, instead of relative links that didn't resolve.

### Documentation

- A README recipe for tracking permission funnels (prompt answers and Settings changes) in Amplitude, Google Analytics or Mixpanel, with no new dependency.
- A four-part [article series](Articles) on the design: the domain model, the `PermissionManager` actor, modular products and App Review, and SwiftUI and testing.

## [3.0.0] — 2026-10-05

A redesign around a domain model and pluggable providers. See [MIGRATION.md](MIGRATION.md).

### Added
- **One product per framework** (`SwiftPermissionsCamera`, `…Photos`, `…Contacts`, `…Calendar`, `…Location`, `…Bluetooth`, `…Motion`, `…Speech`, `…MediaLibrary`, `…Siri`, `…Tracking`, `…Biometrics`, `…Health`). App Store review asks for the usage description of every permission whose request API is in the binary, so apps link only what they request. Register with `PermissionManager(permissions: [.camera, .photoLibrary])` / `PermissionStore(permissions:)`. CI fails if Core, UI or the umbrella imports a privacy framework.
- `PermissionError.providerNotRegistered` names the product and registration to add.
- `canRequest(_:)` on `PermissionRequesting` / `PermissionManager` and `PermissionStore` (plus `requestable`): whether a prompt can still appear, including upgrades. `PermissionRow` shows **Allow More** for an upgrade; "Allow All" still only asks for permissions not yet requested.
- `PermissionError.cancelled`: cancelling the calling task stops waiting without dismissing the prompt for other callers.
- `PermissionProvider` strategy protocol and `PermissionProviderRegistry`: add or replace permissions without touching the core.
- New permissions: `.photoLibraryAddOnly`, `.calendarWriteOnly`, `.bluetooth`, `.speechRecognition`, `.mediaLibrary`, `.siri`; `.health` via `HealthPermissionProvider(share:read:)`.
- `PermissionStatus.limited` and `.unavailable`.
- Info.plist usage-description validation before prompting, plus `missingUsageDescriptions(for:)` for tests.
- Request coalescing: concurrent requests for one permission show one prompt.
- `updates(for:)` / `changes()` async streams, and `refresh()` for changes made in Settings.
- **visionOS 1+** is a supported platform, and CI builds for it. On visionOS, `.locationAlways`, `.motion`, `.siri` and `.mediaLibrary` aren't available.
- **App-extension safe.** Core no longer references `UIApplication.shared`, so every product compiles into widgets and notification extensions. CI builds the package with `APPLICATION_EXTENSION_API_ONLY=YES`. `AppSettings.open` and `PermissionStore.openSettings` are unavailable in extensions. `PermissionPrompt` and `PermissionRow` open Settings with SwiftUI's `openURL`.
- **Privacy manifest** (`PrivacyInfo.xcprivacy`) in Core: no tracking, no collected data, no required-reason APIs.
- `PermissionStatus` documents its stability: no new cases in 3.x.
- `SwiftPermissionsTesting` re-exports `SwiftPermissionsCore`, so `import SwiftPermissionsTesting` is enough in a test file.
- **Agent skill** for Claude Code (installable as a plugin) and Codex: `plugin/skills/swiftpermissions`. It teaches AI coding agents the right product, registration, Info.plist keys and testing setup, and includes `check_usage_descriptions.py`, which checks the registered permissions against the app's Info.plist. `AGENTS.md` covers contributors.
- `AppSettings.open(for:)`, with per-permission Privacy panes on macOS and notification settings on iOS 16+.
- SwiftUI: `PermissionStore`, `PermissionGate`, `PermissionPrompt`, `PermissionRow`, `PermissionsList`, auto-refresh on foreground.
- `SwiftPermissionsTesting` product with `StubPermissionProvider` and `PermissionManager.stubbed(...)`.
- DocC catalog.

### Changed
- Swift 6 language mode; `PermissionManager` is an actor.
- Interface segregation: `PermissionStatusReading`, `PermissionRequesting`, `PermissionObserving`.
- `request(_:)` returns `PermissionStatus` and throws a typed `PermissionError`.
- CI builds iOS, Mac Catalyst, tvOS and watchOS with Xcode 27, runs tests on the iOS Simulator, and tests on macOS with Swift 6.4, 6.3 and 6.1.

### Fixed
- Location requests resolved immediately with `.notDetermined` (the delegate's initial callback) and leaked or overwrote continuations under concurrent requests.
- The package didn't compile for tvOS and watchOS.
- Data races in `PermissionManager` (`@unchecked Sendable` with lazy mutable state).
- `.limited`, `.restricted` and write-only statuses were reported as `.authorized` or `.denied`.
- `PermissionStatusView` created a new manager on every render.

### Fixed during 3.0 review
- Declining Contacts (and EventKit/notification requests that report errors) now yields `.denied` instead of `requestFailed`.
- Upgrade prompts: `PermissionProvider.canRequest(from:)` lets when-in-use → Always location (iOS), write-only → full calendar and provisional → full notifications be requested. The location upgrade resolves even when iOS shows no prompt.
- Bluetooth requires `NSBluetoothAlwaysUsageDescription` on macOS too (TCC terminates the app without it).
- `updates(for:)` delivers the initial value exactly once per subscriber, including for unavailable permissions.
- ATT waits for the app to be active, so it works in batches right after another alert.
- A late caller can no longer clear a newer in-flight request.
- Location no longer hangs when requested while the app is in the background (it waits until active) or with Location Services off system-wide (`.unavailable`).
- HealthKit without the entitlement (or with no data types) reports `.unavailable` instead of `.authorized`.
- `BiometricsPermissionProvider.authenticate(reason:)` checks `NSFaceIDUsageDescription` on Face ID devices instead of letting iOS terminate the app.
- Usage descriptions are only required when a prompt can actually appear, so `request(.biometrics)` on a Touch ID device no longer throws.
- README lists the pre-iOS 17 calendar and reminders keys.
- macOS opens the Notifications pane for `.notifications`; "Open Settings" is hidden where there's nothing to open (watchOS).

### Removed
- `PermissionConfig` (unused), `PermissionManagerFactory`, `MockPermissionManager` from the production module, the Combine publisher.
- `PermissionProviderRegistry.standard`: it linked every privacy framework into every app.
- Stale 1.x/2.x release notes and announcement drafts.

## [1.1.0] - 2024-08-11

### Added  
- Performance benchmarks for permission operations (4 new tests)
- Comprehensive Documentation.md with architecture guide
- Enhanced demo app with batch requests and visual feedback
- Thread-safe implementations throughout codebase
- Modular architecture: SwiftPermissionsCore + SwiftPermissionsUI + SwiftPermissions umbrella

### Changed
- **BREAKING CHANGE**: Restructured into modular components
- Enhanced test coverage (28 total tests, 100% passing)
- Optimized performance for high-frequency operations
- Improved CI/CD with macOS-compatible SwiftLint
- Updated platform requirements to iOS 15.0+, macOS 12.0+, tvOS 15.0+, watchOS 8.0+

### Fixed
- Thread safety issues in concurrent permission requests
- SwiftLint violations and code quality issues
- GitHub Actions compatibility with macOS runners
- Performance bottlenecks in batch operations

### Performance Metrics
- Status checks: ~0.3ms average
- Batch requests: ~31ms for 5 permissions  
- Permission groups: ~1ms for 1000 operations
- Factory methods: ~0.3ms

### Features
- Location services (when in use, always)
- Push notifications
- Camera and microphone access
- Photo library access
- Contacts and calendar access
- Health and motion data
- Biometric authentication (Face ID, Touch ID)
- App tracking transparency
- Custom permission configurations
- Permission grouping (media, location, social, fitness)

### SwiftUI Components
- `PermissionsDashboardView` - Complete permissions dashboard
- `PermissionStatusView` - Individual permission status display
- `ObservablePermissionManager` - Reactive permission management
- View modifiers for conditional content based on permissions
- Permission alert presentations
- Automatic permission requests on view appear

### Testing
- `MockPermissionManager` - Full mock implementation
- `PermissionManagerFactory` - Factory for production and test managers
- Comprehensive test suite covering all permission types
- Combine publisher testing

## [1.0.0] - 2024-12-10

### Added
- Initial public release
