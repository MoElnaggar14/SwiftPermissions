# SwiftPermissions example

A SwiftUI app that tours SwiftPermissions 4.0 on a simulator or an iPhone or iPad:

| Section | What it shows |
| --- | --- |
| Gate a feature | `PermissionGate` around a camera screen: the pre-permission prompt, then the content once granted, or an Open Settings hint after a denial. |
| Limited access | Photos and contacts rows that read `.limited(.selectedItems)` and offer **Select More…**. The row title says why access is limited, e.g. "Limited · Selected Items". |
| Upgrades | `PermissionRow`s for location while in use → Always, and calendar. Allow More appears while an upgrade prompt can still be shown. |
| Custom flows | A camera + microphone batch request with `store.request([...])`, and Face ID / Touch ID with `BiometricsPermissionProvider().authenticate(reason:)`. |
| Onboarding flow | `PermissionFlow` with priming screens. It remembers where it stopped across launches. |
| All permissions | `PermissionsList` with every registered permission, including Local Network, whose last result is kept in a `UserDefaultsRequestHistory`. |
| Live changes | The manager's `changes()` stream. Change something in Settings, come back, and it's logged. |

The app composes one `PermissionManager` in `SwiftPermissionsExampleApp` and injects it, as the README recommends. It registers 16 permissions to show them all. A real app should link and register only what it requests.

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

## Mac checks

The iOS app can't request the macOS-only permissions, so `Example/MacChecks` is a small Mac app for Screen Recording, Accessibility, Input Monitoring and Local Network:

```bash
swift run --package-path Example/MacChecks
```

macOS gives the grant to the app that launched it (Terminal, or Xcode if you open `Example/MacChecks/Package.swift` and press ⌘R). Look for that app in System Settings → Privacy & Security, and remove it there afterwards. To forget the remembered requests, run `defaults delete MacChecks`, or delete the `MacChecks.` keys from that domain.

## Device checks

[#46](https://github.com/MoElnaggar14/SwiftPermissions/issues/46) lists what the stub-based tests can't check. Where to try each one:

| Check | Where |
|---|---|
| Limited photos and contacts | Limited access section: choose Limit Access, then **Select More…** |
| Location Always → While Using | Upgrades → Location (Always): allow While Using. The row reads "Limited · While Using" and offers no Select More…. |
| Calendar write-only | Upgrades → Calendar. Allow "Add Events Only" from Settings. The row reads "Limited · Write Only". |
| Local Network | All permissions → Local Network. Relaunch: the last result stays. |
| Location service session (iOS 18) | Custom flows → Location session → Start, then Stop. |
| Onboarding flow, and data saved by 3.x | Onboarding and diagnostics → Onboarding flow. See the issue for the upgrade check. |
| macOS permissions | `Example/MacChecks`, above. |
