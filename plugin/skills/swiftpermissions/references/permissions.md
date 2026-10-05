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

On **visionOS 1+**, every permission above that isn't iOS-only is available, except `.locationAlways`, `.motion`, `.siri` and `.mediaLibrary`.

## Notes per permission

- **Tracking (ATT):** request it only after the app is active and only when you really track across apps. The prompt is shown at most once per install.
- **Location Always:** iOS first grants "provisional Always", which shows as when-in-use. Request `.locationWhenInUse` first, then `.locationAlways` later when there's a clear reason. The upgrade never hangs, even when iOS shows no prompt.
- **HealthKit:** list only the types the app needs. Put only writable sample types in `share:`. Characteristic types (such as date of birth) are read-only, and HealthKit raises an Objective-C exception, which Swift can't catch, if one is asked for writing. For privacy, HealthKit doesn't reveal whether read access was granted: once the user has answered, the status reads `.authorized`.
- **Calendar write-only:** before iOS 17 it falls back to full access, which needs `NSCalendarsUsageDescription`.
- **Notifications:** `.notifications(options: [.alert, .sound, .badge, .provisional])` asks for provisional delivery without a prompt. The status is then `.provisional`, and a later `request` upgrades it.
