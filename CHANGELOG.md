# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.0.0] — Unreleased

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
