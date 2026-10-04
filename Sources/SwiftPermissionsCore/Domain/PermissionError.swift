/// Why a permission couldn't be requested.
public enum PermissionError: Error, Sendable, Equatable, CustomStringConvertible {
    /// No ``PermissionProvider`` is registered for the permission. On the standard registry
    /// this means the permission doesn't exist on the current platform.
    case providerNotRegistered(Permission)
    /// The app's Info.plist is missing a usage description. Apple terminates the app if
    /// the system prompt is shown without one, so the request is stopped before that happens.
    case missingUsageDescription(Permission, keys: [String])
    /// The underlying framework reported an error.
    case requestFailed(Permission, reason: String)

    public var permission: Permission {
        switch self {
        case let .providerNotRegistered(permission),
             let .missingUsageDescription(permission, _),
             let .requestFailed(permission, _):
            permission
        }
    }

    public var description: String {
        switch self {
        case let .providerNotRegistered(permission):
            "No provider registered for '\(permission)'. It may be unavailable on this platform."
        case let .missingUsageDescription(permission, keys):
            "Add \(keys.joined(separator: ", ")) to Info.plist before requesting '\(permission)'."
        case let .requestFailed(permission, reason):
            "Requesting '\(permission)' failed: \(reason)"
        }
    }
}
