# AGENTS.md

Guidance for AI coding agents (Codex, Claude Code, Cursor, …) working **on this repository**.

> Integrating SwiftPermissions into an app? Use the agent skill instead:
> [`plugin/skills/swiftpermissions/SKILL.md`](plugin/skills/swiftpermissions/SKILL.md). The README explains how to install it.

## Build and test

```bash
swift build --build-tests
swift test
# Full suite on a simulator, as CI runs it:
xcodebuild test -scheme SwiftPermissions-Package -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
swiftlint lint
```

CI builds with Swift 6.4, 6.3 and 6.1, and builds for iOS, Mac Catalyst, tvOS and watchOS. Code must compile on all of them. Guard newer APIs with `#available` and platform-specific code with `#if os(...)`.

## Layout

- `Sources/SwiftPermissionsCore`: the domain (`Permission`, `PermissionStatus`, `PermissionError`), ports (protocols), `PermissionManager` (an actor), the registry, and notifications.
- `Sources/SwiftPermissionsUI`: `PermissionStore` (MainActor) and the SwiftUI views.
- `Sources/SwiftPermissions`: the umbrella module, which re-exports Core and UI.
- `Sources/SwiftPermissions<Framework>`: one provider per privacy framework, plus its `PermissionRegistration` static members.
- `Sources/SwiftPermissionsTesting`: `StubPermissionProvider` and `PermissionManager.stubbed`.
- `plugin/`: the Claude Code plugin and agent skill for app developers.

## Rules

- Core, UI and the umbrella module must never import a privacy framework such as AVFoundation, Photos, CoreLocation or HealthKit. CI enforces this, because App Review asks for usage descriptions of every permission API it finds in the binary.
- Keep Swift 6 strict concurrency clean. Don't use `@unchecked Sendable` without a comment explaining why it's safe.
- Use no singletons. Dependencies are passed in through initialisers.
- Tests use Swift Testing or XCTest with stubs. They never show a real system prompt.

## Adding a permission

1. Add the framework name to `frameworks` in `Package.swift` and create `Sources/SwiftPermissions<Framework>/`.
2. Implement a `PermissionProvider`, and add `public extension PermissionRegistration { static var x }`.
3. Add the permission to `Permission.registrationHint` in `Core/Manager/PermissionRegistration.swift`, so `providerNotRegistered` names the product.
4. Update the README's permissions table and the CHANGELOG.
5. Update the agent skill: `plugin/skills/swiftpermissions/references/permissions.md` and the `PERMISSIONS` map in `scripts/check_usage_descriptions.py`. CI fails if a product is missing from either.
