# SwiftPermissions — Article Series

A four-part series on how SwiftPermissions 3.0 is designed, and why each piece exists. Every code sample uses the 3.0 API: one `PermissionManager` (or `PermissionStore`) created at your composition root and injected, with one product per privacy framework.

| # | Title | What you'll learn |
|---|---|---|
| 1 | [Modelling consent: one vocabulary for every Apple permission](01-modelling-consent.md) | Why 15+ framework enums collapse into seven statuses without losing a UX distinction, and how the domain, ports and providers fit together |
| 2 | [The control tower: an actor that never hangs](02-the-control-tower.md) | Coalescing concurrent prompts, cancellation that doesn't dismiss anyone else's prompt, the Info.plist crash guard, and the location upgrade that iOS may silently skip |
| 3 | [Link only what you use: modular products and App Review](03-link-only-what-you-use.md) | Why each framework is its own product, how registration works, staying app-extension safe, and adding your own permission |
| 4 | [SwiftUI and tests without a single system prompt](04-swiftui-and-testing.md) | `PermissionStore`, `PermissionGate`, refreshing after Settings, scriptable stubs, and catching a missing usage description in CI |

Read in order, or jump to whichever is on fire for you today.

New to the package? Start with the [README](../README.md). Upgrading from 2.x? See [MIGRATION.md](../MIGRATION.md).
