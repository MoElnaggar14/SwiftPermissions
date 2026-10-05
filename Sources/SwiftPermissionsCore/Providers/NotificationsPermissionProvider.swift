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

    /// Provisional authorization can be upgraded to full by asking without `.provisional`.
    public func canRequest(from status: PermissionStatus) -> Bool {
        #if os(tvOS)
        status == .notDetermined
        #else
        status == .notDetermined || (status == .provisional && !options.contains(.provisional))
        #endif
    }

    public func request() async throws -> PermissionStatus {
        // The resulting status is the answer, even if the request reports an error.
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: options)
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

public extension PermissionRegistration {
    /// User notifications with ``NotificationsPermissionProvider/defaultOptions``.
    /// Needs no usage description, so it's part of Core.
    static var notifications: PermissionRegistration {
        PermissionRegistration(NotificationsPermissionProvider())
    }

    /// User notifications with custom options, e.g. `[.alert, .sound, .provisional]`.
    static func notifications(options: UNAuthorizationOptions) -> PermissionRegistration {
        PermissionRegistration(NotificationsPermissionProvider(options: options))
    }
}
