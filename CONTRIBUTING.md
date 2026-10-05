# Contributing to SwiftPermissions

Thanks for helping! Bug reports, docs fixes and pull requests are all welcome. By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Reporting bugs and requesting features

- Search [existing issues](https://github.com/MoElnaggar14/SwiftPermissions/issues) first.
- Open a [bug report](https://github.com/MoElnaggar14/SwiftPermissions/issues/new?template=bug_report.yml) or a [feature request](https://github.com/MoElnaggar14/SwiftPermissions/issues/new?template=feature_request.yml). The forms ask for the version, platform and a small reproduction.
- Security problems go through [private reporting](SECURITY.md), never a public issue.

## Development setup

You need Xcode 16.4 or later (Swift 6.1+). CI also tests Swift 6.3 (Xcode 26.6) and Swift 6.4 (Xcode 27).

```bash
git clone https://github.com/MoElnaggar14/SwiftPermissions.git
cd SwiftPermissions
swift build --build-tests
swift test
```

Open `Package.swift` in Xcode to work on the package, and lint before pushing:

```bash
brew install swiftlint
swiftlint lint
```

## How the code is organised

| Folder | Product |
| --- | --- |
| `Sources/SwiftPermissionsCore` | Domain, ports, `PermissionManager`, registry, notifications |
| `Sources/SwiftPermissionsUI` | `PermissionStore`, `PermissionGate`, `PermissionPrompt`, `PermissionRow`, `PermissionsList` |
| `Sources/SwiftPermissions<Framework>` | One provider product per system framework (Camera, Photos, Location, …) |
| `Sources/SwiftPermissionsTesting` | `StubPermissionProvider`, `PermissionManager.stubbed(...)` |

## Design rules

- **Core links no privacy frameworks.** A new permission gets its own `SwiftPermissions<Framework>` target and product, plus a `PermissionRegistration` static member. CI fails if Core, UI or the umbrella imports a privacy framework.
- **The manager never knows about frameworks.** Framework code lives in a `PermissionProvider`.
- **Report declines as a status, not an error.** A user saying no is `.denied`.
- **Never hang.** Every request must resume, including when the app is in the background or the system shows no prompt.
- **Never crash the host app.** List every Info.plist key a prompt needs in `requiredUsageDescriptionKeys`.

## Tests

Test manager behaviour with `StubPermissionProvider` and `PermissionManager.stubbed(...)`. Real system prompts can't run in CI, so describe any manual device testing in your pull request.

## Pull requests

1. Branch from `main`, keep the change focused, and explain *why* in the description (the pull request template will guide you).
2. Add or update tests, docs (README, DocC comments) and `CHANGELOG.md` under the next version.
3. Breaking changes need an entry in `MIGRATION.md`.
4. Make sure CI is green: tests on three Swift versions, builds for iOS, Mac Catalyst, tvOS and watchOS, and SwiftLint.

Commit messages and pull request titles follow [Conventional Commits](https://www.conventionalcommits.org): `fix: …`, `feat: …`, `docs: …`, `feat!: …` for breaking changes.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
