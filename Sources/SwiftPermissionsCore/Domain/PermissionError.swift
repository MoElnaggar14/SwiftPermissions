/// Why a permission couldn't be requested.
public enum PermissionError: Error, Sendable, Equatable, CustomStringConvertible {
    /// No ``PermissionProvider`` is registered for the permission: add its product and
    /// pass it to ``PermissionManager/init(permissions:usageDescriptions:validatesUsageDescriptions:)``.
    case providerNotRegistered(Permission)
    /// The app's Info.plist is missing a usage description. Apple terminates the app if
    /// the system prompt is shown without one, so the request is stopped before that happens.
    case missingUsageDescription(Permission, keys: [String])
    /// The underlying framework reported an error.
    case requestFailed(Permission, reason: String)
    /// The calling task was cancelled while waiting for the user's answer.
    case cancelled(Permission)

    public var permission: Permission {
        switch self {
        case let .providerNotRegistered(permission),
             let .missingUsageDescription(permission, _),
             let .requestFailed(permission, _),
             let .cancelled(permission):
            permission
        }
    }

    public var description: String {
        switch self {
        case let .providerNotRegistered(permission):
            if let hint = permission.registrationHint {
                "No provider registered for '\(permission)'. Link the \(hint.product) product and pass "
                    + "\(hint.registration) to PermissionManager(permissions:). "
                    + "If you did, '\(permission)' isn't available on this platform."
            } else {
                "No provider registered for '\(permission)'. Register its PermissionProvider with "
                    + "PermissionManager(permissions: [.provider(…)])."
            }
        case let .missingUsageDescription(permission, keys):
            "Add \(keys.joined(separator: ", ")) to Info.plist before requesting '\(permission)'."
        case let .requestFailed(permission, reason):
            "Requesting '\(permission)' failed: \(reason)"
        case let .cancelled(permission):
            "The request for '\(permission)' was cancelled before the user answered."
        }
    }
}
