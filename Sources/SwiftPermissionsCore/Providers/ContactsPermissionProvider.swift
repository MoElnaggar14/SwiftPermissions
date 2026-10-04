#if os(iOS) || os(macOS) || os(watchOS) || os(visionOS)
@preconcurrency import Contacts

/// Address book access.
public struct ContactsPermissionProvider: PermissionProvider {
    public let permission = Permission.contacts
    public let requiredUsageDescriptionKeys = ["NSContactsUsageDescription"]

    public init() {}

    public func status() async -> PermissionStatus {
        Self.map(CNContactStore.authorizationStatus(for: .contacts))
    }

    public func request() async throws -> PermissionStatus {
        _ = try await CNContactStore().requestAccess(for: .contacts)
        return await status()
    }

    static func map(_ status: CNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        case .authorized: return .authorized
        default:
            // `.limited` (iOS 18) — compared by raw value so older SDK deployment targets compile.
            return status.rawValue == 4 ? .limited : .denied
        }
    }
}
#endif
