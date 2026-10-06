/// Why access is ``PermissionStatus/limited`` rather than ``PermissionStatus/authorized``.
///
/// In 3.x the status doesn't carry the reason yet: providers work it out internally and
/// ``PermissionStatus/limited(_:)`` drops it. In 4.0 the case becomes `limited(Limitation)`,
/// so `case .limited(.selectedItems):` can tell selected photos from when-in-use location.
///
/// The set of cases is fixed for the 3.x and 4.x releases, like ``PermissionStatus``.
public enum Limitation: String, Sendable, Hashable, Codable, CaseIterable {
    /// Only items the user picked: selected photos, or selected contacts (iOS 18).
    /// The system picker can add more.
    case selectedItems
    /// When-in-use location, when Always was asked for.
    case whenInUse
    /// Write-only calendar access, when full access was asked for.
    case writeOnly
    /// Some of the requested items, e.g. some HealthKit share types. Also the reason for
    /// permissions that don't say anything more specific.
    case partial
}

extension Limitation {
    /// The reason the built-in provider for `permission` means when it reports `.limited`.
    ///
    /// 3.x statuses don't carry the reason, so the UI and the decoders of 3.x data read it
    /// from this one table. Anything not listed, including custom permissions, is `.partial`.
    package static func reported(for permission: Permission) -> Limitation {
        switch permission {
        case .photoLibrary, .contacts: .selectedItems
        case .locationAlways: .whenInUse
        case .calendar: .writeOnly
        default: .partial
        }
    }
}
