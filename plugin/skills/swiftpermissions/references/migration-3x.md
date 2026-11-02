# Migrating from SwiftPermissions 3.x to 4.0

Source of truth: MIGRATION.md in the repository. 4.0 has one breaking change: `PermissionStatus.limited` carries a `Limitation`, `case limited(Limitation)`. Code already on the 3.6 replacements compiles unchanged.

## Find the call sites

```bash
grep -rnE '(==|!=|:|\[|,|\()[[:space:]]*\.limited([^(A-Za-z]|$)' --include=*.swift . | grep -v 'case \.limited'
grep -rnE 'PermissionStatus\.allCases|PermissionStatus\(rawValue:|status\.rawValue' --include=*.swift .
```

`Permission.rawValue` is unchanged; only `PermissionStatus` lost its raw value.

## Apply the mapping

| 3.x | 4.0 |
| --- | --- |
| `case .limited:` in a `switch` | unchanged; matches every reason |
| `status == .limited` | `status.isLimited`, or `status == .limited(.selectedItems)` for one reason |
| `.limited` as a value (stubs, sets, expectations) | `.limited(.selectedItems)`, `.limited(.whenInUse)`, `.limited(.writeOnly)` or `.limited(.partial)`: pick the one the permission reports (table below) |
| `upgradableFrom: [.limited]` | `upgradableFrom: [.limited(.whenInUse)]` (location) or `[.limited(.writeOnly)]` (calendar) |
| `status.rawValue` | `status.description` |
| `PermissionStatus(rawValue: s)` | `JSONDecoder().decode(PermissionStatus.self, …)`; store with `Codable` |
| `PermissionStatus.allCases` | an explicit list of the statuses needed |
| `if permission == .photoLibrary { … }` to guess what `.limited` meant | `case .limited(.selectedItems):` |

Which reason each built-in permission reports:

| Permission | Reason |
| --- | --- |
| `.photoLibrary`, `.contacts` (iOS 18) | `.selectedItems` |
| `.locationAlways` granted When In Use | `.whenInUse` |
| `.calendar` granted write-only | `.writeOnly` |
| `.health` (some share types), anything else | `.partial` |

## Watch for

- **Analytics and logs.** `description` of a limited status is now `"limited.selectedItems"`, not `"limited"`. If dashboards group by `"limited"`, send `status.isLimited` or the reason as a separate property, and tell the user.
- **Stored data.** `PermissionFlowProgress` and `UserDefaultsRequestHistory` read 3.x values: a stored `"limited"` takes the permission's reason from the table. Nothing to migrate by hand. Rolling back is safe to 3.6 only.
- **Custom providers** that return `.limited` must pick a reason (usually `.partial`) and compare that reason in `canRequest(from:)`.
- **UI.** `PermissionRow` now shows "Limited · Selected Items". If snapshot tests pin the row's text, update them.

Then build and run the tests. A remaining `== .limited` fails with "member 'limited' expects argument of type 'Limitation'".
