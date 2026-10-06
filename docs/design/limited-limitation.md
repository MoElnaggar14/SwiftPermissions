# `PermissionStatus.limited(Limitation)`

Status: proposal for 4.0 · Issue: [#35](https://github.com/MoElnaggar14/SwiftPermissions/issues/35) · Tracker: [#34](https://github.com/MoElnaggar14/SwiftPermissions/issues/34)

Today `.limited` means five different things, and the UI works out which one from the permission. This doc starts from what app code looks like in 4.0 and works backwards to what 3.x ships first, so that moving to 4.0 is mostly mechanical.

## 1. The end state in 4.0

App code switches on the status and, when it needs to, on the reason:

```swift
switch try await permissions.request(.photoLibrary) {
case .authorized:
    showLibrary()
case .limited(.selectedItems):
    showLibrary(banner: .selectMore)          // the user picked some photos
case .limited:
    showLibrary()                             // any other limitation
case .provisional:
    break                                     // notifications only
case .denied:
    await AppSettings.open(for: .photoLibrary)
case .notDetermined, .restricted, .unavailable:
    showUnavailableState()
}
```

Code that doesn't care about the reason still compiles as it does today, because `case .limited:` without a binding matches every limitation.

What each limitation means:

| `Limitation` | Meaning | Reported by | What the user can do |
| --- | --- | --- | --- |
| `.selectedItems` | Access to items the user picked, not the whole library | Photos (`PHAuthorizationStatus.limited`), Contacts (iOS 18 `CNAuthorizationStatus.limited`) | Pick more in the system picker, or allow full access in Settings |
| `.whenInUse` | When-in-use location when Always was asked for | `LocationPermissionProvider.always`, `LocationServiceSession` (`alwaysAuthorizationDenied`) | Upgrade prompt (iOS shows it once), then Settings |
| `.writeOnly` | Can add events but not read them, when full access was asked for | `EventKitPermissionProvider.calendar` (iOS 17+) | Upgrade prompt, then Settings |
| `.partial` | Some of the requested items were allowed | `HealthPermissionProvider` (some share types allowed) | Health app. A new request only covers types not yet asked |

`.provisional` stays its own case (see section 3).

## 2. The domain model

In `SwiftPermissionsCore/Domain/Limitation.swift`. It imports nothing, so Core and UI still import no privacy framework.

```swift
/// Why access is ``PermissionStatus/limited(_:)`` rather than ``PermissionStatus/authorized``.
///
/// The set of cases is fixed for the 4.x releases, like ``PermissionStatus``.
public enum Limitation: String, Sendable, Hashable, Codable, CaseIterable {
    /// Only items the user picked: selected photos, or selected contacts (iOS 18).
    case selectedItems
    /// When-in-use location, when Always was asked for.
    case whenInUse
    /// Write-only calendar access, when full access was asked for.
    case writeOnly
    /// Some of the requested items, e.g. some HealthKit share types.
    case partial
}

public enum PermissionStatus: Sendable, Hashable, CustomStringConvertible {
    case notDetermined
    case denied
    case restricted
    case authorized
    case limited(Limitation)
    case provisional
    case unavailable
}
```

`PermissionStatus` loses `String` raw values and `CaseIterable`, because a case with a payload can't have either. `Codable` is written by hand (section 6).

Conveniences on the status:

```swift
public extension PermissionStatus {
    /// The reason access is limited, or `nil` for any other status.
    var limitation: Limitation? {
        if case let .limited(limitation) = self { limitation } else { nil }
    }

    /// Whether the status is `.limited`, whatever the reason.
    var isLimited: Bool { limitation != nil }
}
```

Provider mapping changes are one line each:

```swift
// Photos
case .limited: .limited(.selectedItems)
// Contacts
return status.rawValue == 4 ? .limited(.selectedItems) : .denied
// Location (and LocationServiceSession.map)
case .authorizedWhenInUse: wantsAlways ? .limited(.whenInUse) : .authorized
// Calendar
case 4: return wantsFullAccess ? .limited(.writeOnly) : .authorized
// Health
default: return .limited(.partial)
```

And their upgrade checks compare the reason, not just the case:

```swift
// LocationPermissionProvider
status == .notDetermined || (level == .always && status == .limited(.whenInUse))
// EventKitPermissionProvider
status == .notDetermined || (access == .fullEvents && status == .limited(.writeOnly))
```

### Why these four, and not more

- **Reduced accuracy is not a limitation.** Precise location off is a property of a grant, not a kind of grant: a user can allow When In Use *and* turn Precise off. One `Limitation` value can't say both, and the README already promises that reduced accuracy is never `.limited`. It stays on `accuracy()` and `LocationSessionDiagnostic.fullAccuracyDenied`.
- **`whenInUse`, not `whileInUse`.** The issue sketches `whileInUse`. This doc proposes `whenInUse` to match `Permission.locationWhenInUse`, `LocationPermissionProvider.whenInUse`, `CLAuthorizationStatus.authorizedWhenInUse` and the Info.plist key. (Open question 1.)
- **`partial` is the general case.** It means "some of what was asked for". It is also what legacy data and third-party providers map to when nothing more specific fits (section 6).
- **Closed enum.** Exhaustive switches are the point of the change. `Permission` is an open struct, but limitations come from Apple's frameworks and change rarely. New ones arrive in a major release, as with `PermissionStatus` cases.

## 3. Does `.provisional` fold in?

Recommendation: **no, keep `.provisional` as a case.**

- It means something different. Provisional notifications are granted *without asking*, and are delivered quietly. The other limitations are an answer the user gave to a prompt.
- Folding it in breaks every `case .provisional:` in app code. Keeping it means the only source break is `.limited` used as a value, which section 5 makes easy to fix in 3.x.
- The UI already treats it like a limited grant (yellow, `checkmark.circle`), and `canRequest(from:)` already handles its upgrade. Nothing gets simpler by folding it.

The alternative, `.limited(.quietDelivery)`, is listed in section 8.

## 4. How each case maps

`isGranted`, `canRequest` and `requiresSettings` keep their meaning:

| Status | `isGranted` | `canRequest` (status) | `requiresSettings` |
| --- | --- | --- | --- |
| `.limited(_)`, any reason | `true` | `false` | `false` |
| `.provisional` | `true` | `false` | `false` |

As today, whether an upgrade prompt can still appear is the provider's answer (`canRequest(from:)` / `PermissionRequesting.canRequest(_:)`), not the status's. iOS offers the Always upgrade once, so `.limited(.whenInUse)` is upgradable on the first try and not after. The status can't know that.

### UI decisions

The UI stops guessing from the permission. A single internal helper in `SwiftPermissionsUI` replaces the three copies in `RowAction`, `PromptActions` and `Permission+UI`:

```swift
/// What a limited grant offers once no prompt can appear.
enum LimitedAction: Equatable {
    case selectMore      // system picker
    case openSettings
    case nothing

    init(_ limitation: Limitation, canSelectMore: Bool, hasSettingsURL: Bool) {
        switch limitation {
        case .selectedItems where canSelectMore: self = .selectMore
        case .selectedItems, .whenInUse, .writeOnly: self = hasSettingsURL ? .openSettings : .nothing
        case .partial: self = .nothing   // Health has no Settings pane for the app
        }
    }
}
```

| Limitation | `canRequest(_:)` true | `canRequest(_:)` false, `PermissionPrompt` | `canRequest(_:)` false, `PermissionRow` |
| --- | --- | --- | --- |
| `.selectedItems` | n/a (never upgradable) | Select More… if `onSelectMore`, else Open Settings | Select More… if `onSelectMore`, else nothing (today) or Settings (open question 3) |
| `.whenInUse` | Continue / Allow More | Open Settings | nothing (today) or Settings |
| `.writeOnly` | Continue / Allow More | Open Settings | nothing (today) or Settings |
| `.partial` | n/a (Health can't upgrade) | nothing | nothing |

Two fixes fall out of this:

- **Select More… only for `.selectedItems`.** Today a row with `onSelectMore` shows Select More… for any `.limited`, including when-in-use location after the upgrade prompt was spent.
- **Labels can name the reason.** `PermissionStatus.title` can read "Selected Photos", "While Using", "Write Only" or "Partial" instead of "Limited". The permission still decides the noun (photos or contacts) for `.selectedItems`, but that's copy, not a decision. Proposed: `title` stays "Limited" and a new `limitation.title` gives the reason, so VoiceOver can read both. (Open question 4.)

`PermissionGate` uses `isGranted` only, and `PermissionFlowState` uses `canRequest` and `== .unavailable` only, so neither changes.

## 5. Migration, working backwards

The 4.0 change breaks app code in four ways. For each, 3.x ships the replacement first, so apps can fix the break before upgrading:

| Breaks in 4.0 | Example | 3.x replacement | Ships in |
| --- | --- | --- | --- |
| `.limited` compared as a value | `status == .limited` | `status.isLimited` | 3.6 |
| `.limited` built as a value | `StubPermissionProvider(.photoLibrary, status: .limited)`, `upgradableFrom: [.limited]` | `.limited(.selectedItems)` (a 3.x static func that returns `.limited`) | 3.6, if it compiles (open question 5) |
| `rawValue` / `init(rawValue:)` | `change.status.rawValue` in analytics | `description` (and the `Codable` form for storage) | 3.6 docs; 3.6 deprecation if feasible |
| `CaseIterable` | `PermissionStatus.allCases` | none; list the cases you need | 4.0 |

`case .limited:` in a `switch` needs nothing: it compiles in 3.x and 4.0.

### What 3.6 ships

All additive:

```swift
// Core, 3.6
public enum Limitation: String, Sendable, Hashable, Codable, CaseIterable { … }   // as in 4.0

public extension PermissionStatus {
    /// `true` for `.limited`. Use it instead of `== .limited`, which won't compile in 4.0.
    var isLimited: Bool { self == .limited }

    /// Builds `.limited`. In 3.x the reason is dropped; in 4.0 this is the case itself.
    static func limited(_ limitation: Limitation) -> PermissionStatus { .limited }
}
```

- The package's own code, tests, README, Articles and skill switch to `isLimited` and `.limited(.reason)` in 3.6, so 4.0's diff in them is the case change only.
- The providers compute their `Limitation` internally in 3.6 (an internal `mapLimitation` next to each `map`) and unit-test it. 4.0 only wires it into the status.
- The 3.6 decoders for `PermissionStatus`, `PermissionFlowProgress` and `UserDefaultsRequestHistory` accept the 4.0 form (`"limited.selectedItems"`) and read it as `.limited`. An app that is rolled back from 4.0 to 3.6 then keeps its saved flow progress instead of starting over.
- No public `limitation` property in 3.x. Without a payload it would have to be `nil` or a guess, and the point of the change is to stop guessing.

Deprecating `rawValue` in 3.6 means dropping the `String` raw type and writing `RawRepresentable` by hand, with `@available(*, deprecated)` on `rawValue`. That's possible but touches `Codable`. Proposed: do it only if it stays a small diff; otherwise document `description` and let 4.0 break.

### What 4.0 ships

- `case limited(Limitation)`, remove the 3.x `static func limited(_:)`, remove `String` raw values and `CaseIterable`.
- `limitation: Limitation?` (`isLimited` stays).
- Hand-written `Codable` with the legacy decoding path (section 6).
- Providers report the reason; UI uses `LimitedAction`.
- MIGRATION.md "3.x to 4.0", README, Articles part 1, the skill (`plugin/skills/swiftpermissions/`), CHANGELOG.

### Before and after

```swift
// 3.x
switch status {
case .authorized:                 showLibrary()
case .limited:
    if permission == .photoLibrary || permission == .contacts {
        showLibrary(banner: .selectMore)
    } else {
        showLibrary()
    }
case .provisional:                break
case .denied:                     await AppSettings.open(for: permission)
case .notDetermined, .restricted, .unavailable:
    showUnavailableState()
}
if status == .limited { analytics.log("limited") }

// 4.0
switch status {
case .authorized:                 showLibrary()
case .limited(.selectedItems):    showLibrary(banner: .selectMore)
case .limited:                    showLibrary()
case .provisional:                break
case .denied:                     await AppSettings.open(for: permission)
case .notDetermined, .restricted, .unavailable:
    showUnavailableState()
}
if status.isLimited { analytics.log("limited") }
```

### Measured on this repo

Counted on `develop` across `Sources`, `Tests`, `Example`, the README, the Articles and the skill:

| Pattern | Sites | In 4.0 |
| --- | --- | --- |
| `case .limited:` in a `switch` | 6 | compiles unchanged |
| `== .limited` | 7 (5 in `Sources`, 2 in tests) | `isLimited` or `== .limited(.reason)` |
| `.limited` as a value (stubs, sets, `#expect`) | about 30, nearly all in tests | `.limited(.reason)` |
| `PermissionStatus.allCases` | 4, all in tests | explicit list |
| `status.rawValue` | 3 in the README, 1 in Core | `description` / `Codable` |

So in app-shaped code (the README and Example) the break is limited to `rawValue` in the logging samples. The value-construction sites are in tests, which is also where apps will feel it (stubs). That is why the 3.6 `static func limited(_:)` shim is worth checking.

## 6. Codable and persistence

Two stores persist statuses:

- `PermissionFlowProgress` stores `PermissionFlowStepOutcome`, which synthesises `Codable` and so stores the status's `Codable` form, today a plain string: `{"outcomes":{"photoLibrary":{"skipped":{"_0":"limited"}}}}`.
- `UserDefaultsRequestHistory` stores `status.rawValue` under `<prefix><permission>.lastResult`.

### 4.0 format

One string per status, so stored JSON and defaults stay readable and both stores keep one format:

| Status | Stored |
| --- | --- |
| `.authorized` etc. | `"authorized"` (unchanged) |
| `.limited(.selectedItems)` | `"limited.selectedItems"` |

```swift
extension PermissionStatus: Codable {
    public init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard let status = PermissionStatus(storageValue: value) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Unknown status '\(value)'"))
        }
        self = status
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageValue)
    }
}

extension PermissionStatus {
    /// `"authorized"`, `"limited.selectedItems"`, …
    var storageValue: String { … }

    /// Reads ``storageValue``, and the 3.x value `"limited"`.
    init?(storageValue: String, permission: Permission? = nil) {
        switch storageValue {
        case "limited":
            self = .limited(.legacy(for: permission))
        case let value where value.hasPrefix("limited."):
            guard let limitation = Limitation(rawValue: String(value.dropFirst("limited.".count))) else { return nil }
            self = .limited(limitation)
        // … the other cases by name
        }
    }
}
```

### Decoding 3.x values

A 3.x `"limited"` has no reason. Both stores are keyed by permission, so they can supply one from a fixed table in Core:

```swift
extension Limitation {
    /// The reason a 3.x provider meant by `.limited`. Only for reading 3.x data.
    static func legacy(for permission: Permission?) -> Limitation {
        switch permission {
        case .photoLibrary?, .contacts?: .selectedItems
        case .locationAlways?:           .whenInUse
        case .calendar?:                 .writeOnly
        default:                         .partial
        }
    }
}
```

This is the permission-based guess the change removes from the UI, but it only runs on old data, in one place, and every built-in permission that reported `.limited` in 3.x is in it.

- `PermissionFlowProgress.init(from:)` already decodes the outcomes dictionary by hand. It decodes each outcome with the permission at hand, so a 3.x `"limited"` gets the right reason. `PermissionFlowStepOutcome` gets a hand-written `Codable` with the same `{"skipped":{"_0":…}}` shape, plus an internal initializer that takes the permission.
- `UserDefaultsRequestHistory.lastResult(_:)` calls `PermissionStatus(storageValue:permission:)`. In practice its three permissions (Screen Recording, Accessibility, Local Network) never report `.limited`, so this is only for completeness.
- A bare `JSONDecoder().decode(PermissionStatus.self, …)` of `"limited"` reads `.limited(.partial)`.
- Stale reasons are low risk. A finished flow step is never re-checked, and `PermissionFlowResult.statuses` from saved progress is "last known", as documented.

## 7. Custom providers

A third-party `PermissionProvider` that returns `.limited` today must pick a reason in 4.0. `.partial` fits most cases. Its `canRequest(from:)` changes from `status == .limited` to `status.isLimited` or a specific reason. MIGRATION.md says so.

## 8. Alternatives considered

- **`limitation` property only, no payload.** Add `Limitation?` next to `.limited` and keep the enum as is. No break, but the status and its reason can disagree, every provider has to report two things, and `PermissionStatus` values in streams, stores and `PermissionChange` would lose the reason. Rejected; it's the 3.x stepping stone at most.
- **New top-level cases** (`.selectedItems`, `.whenInUse`, …). Every `case .limited:` breaks, `isGranted` grows with every case, and "some kind of limited" needs a helper. Rejected.
- **Fold `.provisional` in** as `.limited(.quietDelivery)`. One fewer case and one rule for "granted with conditions", but a bigger break and a blurred meaning (section 3). Not recommended; open question 2.
- **`Limitation` as an open struct** with static members, like `Permission`. Third parties could add reasons, but apps couldn't switch exhaustively and the UI would need a property per reason to choose an action. Rejected.
- **`Limitation` as an `OptionSet`**, so location can be `[.whenInUse, .reducedAccuracy]`. It models accuracy, but `case .limited(.selectedItems)` no longer pattern-matches cleanly and most combinations are impossible. Rejected; accuracy stays outside the status.
- **Store the reason under a separate key** (`{"status":"limited","limitation":"selectedItems"}`). 3.x readers would decode it unchanged, but the history's defaults value stops being a single string and the outcome JSON gets deeper. The single-string format plus a tolerant 3.6 decoder gets the same rollback safety.

## 9. Decisions

Decided by the maintainer on 2026-10-06.

1. **`whenInUse`**, matching `Permission.locationWhenInUse` and Core Location.
2. **`.provisional` stays its own case.** It's a different kind of grant, not a reduced one.
3. **`PermissionRow` offers Open Settings for a limited grant** when no prompt or picker is available, as `PermissionPrompt` already does.
4. **`title` stays "Limited"**, and `Limitation.title` names the reason ("Selected Items", "While Using", "Write Only", "Partial").
5. **3.6 tries the `static func limited(_:)` shim.** If it doesn't compile on Swift 6.1 through 6.4, 3.6 ships only `isLimited` and stubs change in 4.0.
6. **3.6 deprecates `rawValue`** with a hand-written `RawRepresentable`, so callers get a warning before 4.0.
7. **`description` in 4.0 is `"limited.selectedItems"`**, the same as the stored form.
8. **Health `.partial` gets a doc note** that HealthKit hides read authorization, so it reflects share types only. Behaviour is unchanged.
