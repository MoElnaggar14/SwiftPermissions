# SwiftPermissions example

A SwiftUI app that tours SwiftPermissions 3.0 on a simulator or an iPhone or iPad:

| Section | What it shows |
| --- | --- |
| Gate a feature | `PermissionGate` around a camera screen: the pre-permission prompt, then the content once granted, or an Open Settings hint after a denial. |
| Upgrades | `PermissionRow`s for location while in use → Always, and calendar. Allow More appears while an upgrade prompt can still be shown. |
| Custom flows | A camera + microphone batch request with `store.request([...])`, and Face ID / Touch ID with `BiometricsPermissionProvider().authenticate(reason:)`. |
| All permissions | `PermissionsList` with every registered permission, for onboarding or a privacy screen. |
| Live changes | The manager's `changes()` stream. Change something in Settings, come back, and it's logged. |

The app composes one `PermissionManager` in `SwiftPermissionsExampleApp` and injects it, as the README recommends. It registers 15 permissions to show them all. A real app should link and register only what it requests.

## Run on the simulator

```bash
open Example/SwiftPermissionsExample.xcodeproj
```

Pick an iPhone simulator and press ⌘R. Xcode resolves the package from this checkout (`..`), so your local edits to the library show up immediately.

Simulator limits:
- **Camera:** the simulator has no camera hardware, so the camera can be granted, but nothing is captured.
- **Bluetooth:** the simulator reports Bluetooth as unavailable.
- **Face ID:** turn it on with Features → Face ID → Enrolled, then use Matching Face / Non-matching Face.
- **Location:** set a location with Features → Location.
- **Reset:** to start over, run `xcrun simctl privacy booted reset all com.moelnaggar.SwiftPermissionsExample`, or delete the app.

## Run on an iPhone or iPad

1. Select the **SwiftPermissionsExample** target → Signing & Capabilities → choose your **Team**.
2. If Xcode says the bundle identifier is taken, change it, e.g. to `com.<you>.SwiftPermissionsExample`.
3. Connect the device, turn on Developer Mode (Settings → Privacy & Security → Developer Mode), pick the device and press ⌘R.

To see the prompts again: Settings → General → Transfer or Reset → Reset → Reset Location & Privacy, or delete the app.

## Things to try

- **Allow Once / When In Use first, then the Always row:** this walks through the location upgrade flow.
- **Remove a key from `Example/Info.plist`:** requesting that permission then shows a `missingUsageDescription` alert instead of crashing.
- **Check the keys from the repository root:**

  ```bash
  python3 plugin/skills/swiftpermissions/scripts/check_usage_descriptions.py Example
  ```

Requires Xcode 16 or later; the deployment target is iOS 17.
