# Permissions, products and Info.plist keys

| Registration | Product (`import`) | iOS | macOS | tvOS | watchOS | Info.plist key(s) |
| --- | --- | :-: | :-: | :-: | :-: | --- |
| `.camera` | `SwiftPermissionsCamera` | ✓ | ✓ | | | `NSCameraUsageDescription` |
| `.microphone` | `SwiftPermissionsCamera` | ✓ | ✓ | | | `NSMicrophoneUsageDescription` |
| `.photoLibrary` | `SwiftPermissionsPhotos` | ✓ | ✓ | | | `NSPhotoLibraryUsageDescription` |
| `.photoLibraryAddOnly` | `SwiftPermissionsPhotos` | ✓ | ✓ | | | `NSPhotoLibraryAddUsageDescription` |
| `.contacts` | `SwiftPermissionsContacts` | ✓ | ✓ | | ✓ | `NSContactsUsageDescription` |
| `.calendar` | `SwiftPermissionsCalendar` | ✓ | ✓ | | ✓ | iOS 17+/macOS 14+: `NSCalendarsFullAccessUsageDescription`. Earlier: `NSCalendarsUsageDescription` |
| `.calendarWriteOnly` | `SwiftPermissionsCalendar` | ✓ | ✓ | | ✓ | iOS 17+/macOS 14+: `NSCalendarsWriteOnlyAccessUsageDescription`. Earlier: `NSCalendarsUsageDescription` |
| `.reminders` | `SwiftPermissionsCalendar` | ✓ | ✓ | | ✓ | iOS 17+/macOS 14+: `NSRemindersFullAccessUsageDescription`. Earlier: `NSRemindersUsageDescription` |
| `.locationWhenInUse` | `SwiftPermissionsLocation` | ✓ | ✓ | ✓ | ✓ | `NSLocationWhenInUseUsageDescription` |
| `.locationAlways` | `SwiftPermissionsLocation` | ✓ | ✓ | | ✓ | `NSLocationWhenInUseUsageDescription` + `NSLocationAlwaysAndWhenInUseUsageDescription` (macOS: when-in-use key only) |
| `.notifications` / `.notifications(options:)` | `SwiftPermissionsCore` (already in `SwiftPermissions`) | ✓ | ✓ | ✓ | ✓ | none |
| `.bluetooth` | `SwiftPermissionsBluetooth` | ✓ | ✓ | ✓ | ✓ | `NSBluetoothAlwaysUsageDescription` |
| `.tracking` | `SwiftPermissionsTracking` | ✓ | ✓ | ✓ | | `NSUserTrackingUsageDescription` |
| `.speechRecognition` | `SwiftPermissionsSpeech` | ✓ | ✓ | | | `NSSpeechRecognitionUsageDescription` (dictation usually also needs `.microphone`) |
| `.motion` | `SwiftPermissionsMotion` | ✓ | | | ✓ | `NSMotionUsageDescription` |
| `.siri` | `SwiftPermissionsSiri` | ✓ | | | ✓ | `NSSiriUsageDescription` + Siri capability |
| `.mediaLibrary` | `SwiftPermissionsMediaLibrary` | ✓ | | | | `NSAppleMusicUsageDescription` |
| `.biometrics` | `SwiftPermissionsBiometrics` | ✓ | ✓ | | | `NSFaceIDUsageDescription` (iOS, Face ID devices) |
| `.health(share:read:)` | `SwiftPermissionsHealth` | ✓ | | | ✓ | `NSHealthShareUsageDescription` (read) / `NSHealthUpdateUsageDescription` (share) + HealthKit capability |
| `.alarms` | `SwiftPermissionsAlarms` | ✓ (iOS 26+) | | | | `NSAlarmKitUsageDescription` |
| `.screenRecording` | `SwiftPermissionsScreenRecording` | | ✓ | | | none |
| `.accessibility` | `SwiftPermissionsAccessibility` | | ✓ | | | none |
| `.inputMonitoring` | `SwiftPermissionsInputMonitoring` | | ✓ | | | none |
| `.localNetwork` / `.localNetwork(serviceType:)` | `SwiftPermissionsLocalNetwork` | ✓ | ✓ (macOS 15+) | | | `NSLocalNetworkUsageDescription` + the probe's service type (`_swiftperms._tcp` by default) in the `NSBonjourServices` array |

On **visionOS 1+**, every permission above that isn't iOS-only is available, except `.locationAlways`, `.motion`, `.siri` and `.mediaLibrary`.

## Notes per permission

- **Tracking (ATT):** request it only after the app is active and only when you really track across apps. The prompt is shown at most once per install.
- **Location Always:** iOS first grants "provisional Always", which shows as when-in-use. Request `.locationWhenInUse` first, then `.locationAlways` later when there's a clear reason. The upgrade never hangs, even when iOS shows no prompt.
- **Location accuracy:** `.authorized` can still mean approximate location, when the user turned off Precise. If the feature needs exact coordinates, check `await LocationPermissionProvider.whenInUse.accuracy() == .reduced` (it's `nil` until authorized) and call `requestTemporaryFullAccuracy(purposeKey:)`. Add the purpose key to the `NSLocationTemporaryUsageDescriptionDictionary` dictionary in Info.plist; a missing key throws `.missingUsageDescription`. Don't treat reduced accuracy as `.limited`.
- **HealthKit:** list only the types the app needs. Put only writable sample types in `share:`. Characteristic types (such as date of birth) are read-only, and HealthKit raises an Objective-C exception, which Swift can't catch, if one is asked for writing. For privacy, HealthKit doesn't reveal whether read access was granted: once the user has answered, the status reads `.authorized`.
- **Bluetooth with AccessorySetupKit:** on iOS 18+, if Info.plist lists `Bluetooth` under `NSAccessorySetupKitSupports`, iOS never shows the Bluetooth prompt; the user approves each accessory in the AccessorySetupKit picker, and `CBManager.authorization` stays `.notDetermined` even after pairing. `.bluetooth` then reports `.unavailable` and `request(.bluetooth)` returns at once without a prompt. Don't gate the feature on `.bluetooth` in such an app (and don't put it in a `PermissionGate`); check `ASAccessorySession.accessories` instead. A `.denied` or `.restricted` from Core Bluetooth is still reported. Keep `NSBluetoothAlwaysUsageDescription` when the deployment target is below iOS 18. Declaring AccessorySetupKit also blocks `CBPeripheralManager`.
- **Alarms (AlarmKit):** for alarms and countdown timers that must sound through Silent mode and Focus. Before iOS 26, and on Mac Catalyst, the status is `.unavailable`, so no `#available` check is needed around the registration; hide the feature when the status is `.unavailable`. Ordinary reminders should use notifications instead.
- **Screen Recording, Accessibility, Input Monitoring (macOS):** for screen capture, controlling other apps, and global keyboard events (`CGEventTap`, `IOHIDManager`). macOS only, not Mac Catalyst; the products compile empty elsewhere, so guard their imports and registrations with `#if os(macOS)` in multiplatform code. No Info.plist key is needed. A request shows a system alert pointing to System Settings and returns before the user decides, so show `AppSettings.open(for:)` (it opens `Privacy_ScreenCapture`, `Privacy_Accessibility` or `Privacy_ListenEvent`) and rely on the store refreshing when the app becomes active. Screen Recording and Accessibility can't tell "never asked" from "declined": they read `.notDetermined` until the provider has asked in this launch, then `.denied`. A new Screen Recording grant may need an app relaunch. Input Monitoring reports `.notDetermined`, `.denied` and `.authorized` directly.
- **Local network:** there's no API to read or request it, so `request` runs a short Bonjour probe that shows the prompt. `status` is `.notDetermined` until a request has run in this launch, then the last result; don't treat `.notDetermined` as "never asked". Request it right before the feature that browses the network, not at launch. `NSBonjourServices` must list the probe's service type: add `_swiftperms._tcp`, or register `.localNetwork(serviceType:)` with a type the app already declares. A timeout (the user left the prompt up) returns `.notDetermined`. On tvOS and macOS before 15 it reads `.authorized`, on watchOS `.unavailable`.
- **Calendar write-only:** before iOS 17 it falls back to full access, which needs `NSCalendarsUsageDescription`.
- **Notifications:** `.notifications(options: [.alert, .sound, .badge, .provisional])` asks for provisional delivery without a prompt. The status is then `.provisional`, and a later `request` upgrades it. `.authorized` doesn't mean the user sees anything: `await NotificationsPermissionProvider().settings()` returns the alert, sound, lock-screen, time-sensitive and other settings, and `isEffectivelySilent` is `true` when nothing visible or audible is on. Use it to show a "turn on banners" tip.
