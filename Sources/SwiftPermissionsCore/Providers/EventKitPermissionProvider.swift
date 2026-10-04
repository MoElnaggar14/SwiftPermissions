#if os(iOS) || os(macOS) || os(watchOS) || os(visionOS)
@preconcurrency import EventKit

/// Calendar or reminders access.
///
/// On iOS 17 / macOS 14 / watchOS 10 and later, EventKit distinguishes full access from
/// write-only access, each with its own Info.plist key. Earlier systems only have full access.
public struct EventKitPermissionProvider: PermissionProvider {
    private enum Access: Sendable { case fullEvents, writeOnlyEvents, reminders }

    public let permission: Permission
    private let access: Access

    public static let calendar = EventKitPermissionProvider(permission: .calendar, access: .fullEvents)
    public static let calendarWriteOnly = EventKitPermissionProvider(
        permission: .calendarWriteOnly,
        access: .writeOnlyEvents
    )
    public static let reminders = EventKitPermissionProvider(permission: .reminders, access: .reminders)

    private init(permission: Permission, access: Access) {
        self.permission = permission
        self.access = access
    }

    private var entityType: EKEntityType { access == .reminders ? .reminder : .event }

    public var requiredUsageDescriptionKeys: [String] {
        if #available(iOS 17, macOS 14, watchOS 10, *) {
            switch access {
            case .fullEvents: return ["NSCalendarsFullAccessUsageDescription"]
            case .writeOnlyEvents: return ["NSCalendarsWriteOnlyAccessUsageDescription"]
            case .reminders: return ["NSRemindersFullAccessUsageDescription"]
            }
        }
        return access == .reminders ? ["NSRemindersUsageDescription"] : ["NSCalendarsUsageDescription"]
    }

    public func status() async -> PermissionStatus {
        Self.map(EKEventStore.authorizationStatus(for: entityType), wantsFullAccess: access != .writeOnlyEvents)
    }

    public func request() async throws -> PermissionStatus {
        let store = EKEventStore()
        if #available(iOS 17, macOS 14, watchOS 10, *) {
            switch access {
            case .fullEvents: _ = try await store.requestFullAccessToEvents()
            case .writeOnlyEvents: _ = try await store.requestWriteOnlyAccessToEvents()
            case .reminders: _ = try await store.requestFullAccessToReminders()
            }
        } else {
            _ = try await store.requestAccess(to: entityType)
        }
        return await status()
    }

    static func map(_ status: EKAuthorizationStatus, wantsFullAccess: Bool) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        default:
            // `.authorized` (pre-17) and `.fullAccess` share raw value 3; `.writeOnly` is 4.
            switch status.rawValue {
            case 3: return .authorized
            case 4: return wantsFullAccess ? .limited : .authorized
            default: return .denied
            }
        }
    }
}
#endif
