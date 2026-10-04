@preconcurrency import UserNotifications

/// User notification authorization.
public struct NotificationsPermissionProvider: PermissionProvider {
    public let permission = Permission.notifications
    private let options: UNAuthorizationOptions

    /// - Parameter options: What to ask for. Include `.provisional` to deliver quietly
    ///   without showing a prompt.
    public init(options: UNAuthorizationOptions = NotificationsPermissionProvider.defaultOptions) {
        self.options = options
    }

    public static var defaultOptions: UNAuthorizationOptions {
        #if os(tvOS)
        [.badge]
        #else
        [.alert, .badge, .sound]
        #endif
    }

    public func status() async -> PermissionStatus {
        Self.map(await UNUserNotificationCenter.current().notificationSettings().authorizationStatus)
    }

    public func request() async throws -> PermissionStatus {
        _ = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
        return await status()
    }

    static func map(_ status: UNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        default:
            #if os(iOS)
            // App Clip ephemeral authorization.
            if status == .ephemeral { return .authorized }
            #endif
            return .denied
        }
    }
}
