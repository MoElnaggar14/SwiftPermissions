/// Why access is ``PermissionStatus/limited(_:)`` rather than ``PermissionStatus/authorized``.
///
/// `case .limited(.selectedItems):` tells selected photos from when-in-use location, and
/// `case .limited:` matches every reason.
///
/// The set of cases is fixed for the 4.x releases, like ``PermissionStatus``. A custom
/// provider with no more specific reason reports ``partial``.
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
    /// The reason a 3.x built-in provider meant when it reported `.limited` for
    /// `permission`. Only for reading data stored by 3.x, which has no reason.
    ///
    /// Anything not listed, including custom permissions and an unknown permission, is
    /// ``partial``.
    package static func legacy(for permission: Permission?) -> Limitation {
        guard let permission else { return .partial }
        switch permission {
        case .photoLibrary, .contacts: return .selectedItems
        case .locationAlways: return .whenInUse
        case .calendar: return .writeOnly
        default: return .partial
        }
    }
}
