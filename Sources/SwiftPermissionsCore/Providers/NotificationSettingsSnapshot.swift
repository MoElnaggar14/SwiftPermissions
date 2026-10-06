@preconcurrency import UserNotifications

/// Whether one way of presenting notifications is turned on in Settings.
public enum NotificationFeatureSetting: String, Sendable, Codable, CaseIterable {
    case enabled
    case disabled
    /// The platform or device doesn't have this feature (e.g. lock screen on watchOS).
    case notSupported
}

/// How alerts appear while the device is unlocked.
public enum NotificationAlertStyle: String, Sendable, Codable, CaseIterable {
    /// Alerts don't appear on screen (the user chose "None").
    case off
    /// Temporary banners.
    case banner
    /// Persistent alerts that stay until dismissed.
    case alert
    case notSupported
}

/// When notification previews (the message body) are shown.
public enum NotificationPreviews: String, Sendable, Codable, CaseIterable {
    case always
    case whenUnlocked
    case never
    case notSupported
}

/// The user's notification settings beyond the top-level authorization.
///
/// A user can allow notifications and still never see them: alerts can be off, banners
/// set to None, and the lock screen and Notification Center hidden. Support teams know
/// this as "notifications are authorized but silent". ``isEffectivelySilent`` answers it.
///
/// ```swift
/// let settings = await NotificationsPermissionProvider().settings()
/// if settings.isEffectivelySilent {
///     showNotificationTip()   // e.g. "Turn on Banners in Settings to see reminders"
/// }
/// ```
///
/// Critical alerts need the `com.apple.developer.usernotifications.critical-alerts`
/// entitlement; without it ``criticalAlert`` reads `.notSupported` or `.disabled`.
public struct NotificationSettingsSnapshot: Sendable, Equatable, Codable {
    public var authorization: PermissionStatus
    public var alert: NotificationFeatureSetting
    public var sound: NotificationFeatureSetting
    public var badge: NotificationFeatureSetting
    public var lockScreen: NotificationFeatureSetting
    public var notificationCenter: NotificationFeatureSetting
    public var criticalAlert: NotificationFeatureSetting
    public var timeSensitive: NotificationFeatureSetting
    /// Whether notifications are delivered in the Scheduled Summary instead of immediately.
    public var scheduledDelivery: NotificationFeatureSetting
    public var alertStyle: NotificationAlertStyle
    public var previews: NotificationPreviews

    public init(
        authorization: PermissionStatus,
        alert: NotificationFeatureSetting = .notSupported,
        sound: NotificationFeatureSetting = .notSupported,
        badge: NotificationFeatureSetting = .notSupported,
        lockScreen: NotificationFeatureSetting = .notSupported,
        notificationCenter: NotificationFeatureSetting = .notSupported,
        criticalAlert: NotificationFeatureSetting = .notSupported,
        timeSensitive: NotificationFeatureSetting = .notSupported,
        scheduledDelivery: NotificationFeatureSetting = .notSupported,
        alertStyle: NotificationAlertStyle = .notSupported,
        previews: NotificationPreviews = .notSupported
    ) {
        self.authorization = authorization
        self.alert = alert
        self.sound = sound
        self.badge = badge
        self.lockScreen = lockScreen
        self.notificationCenter = notificationCenter
        self.criticalAlert = criticalAlert
        self.timeSensitive = timeSensitive
        self.scheduledDelivery = scheduledDelivery
        self.alertStyle = alertStyle
        self.previews = previews
    }

    /// `true` when the user won't see or hear a notification arrive: it isn't allowed,
    /// or alerts, lock screen, Notification Center and sound are all off.
    ///
    /// A badge alone counts as silent, except where badges are the only presentation
    /// (tvOS).
    public var isEffectivelySilent: Bool {
        guard authorization.isGranted else { return true }
        let presentations = [alert, lockScreen, notificationCenter, sound]
        if presentations.allSatisfy({ $0 == .notSupported }) {
            return badge != .enabled
        }
        return !presentations.contains(.enabled)
    }
}

// MARK: - Reading the settings

public extension NotificationsPermissionProvider {
    /// The user's current notification settings. Never shows UI.
    func settings() async -> NotificationSettingsSnapshot {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return NotificationSettingsSnapshot(settings)
    }
}

extension NotificationSettingsSnapshot {
    init(_ settings: UNNotificationSettings) {
        self.init(authorization: NotificationsPermissionProvider.map(settings.authorizationStatus))
        #if !os(watchOS)
        badge = Self.map(settings.badgeSetting)
        #endif
        #if !os(tvOS)
        alert = Self.map(settings.alertSetting)
        sound = Self.map(settings.soundSetting)
        notificationCenter = Self.map(settings.notificationCenterSetting)
        criticalAlert = Self.map(settings.criticalAlertSetting)
        timeSensitive = Self.map(settings.timeSensitiveSetting)
        scheduledDelivery = Self.map(settings.scheduledDeliverySetting)
        #endif
        #if !os(tvOS) && !os(watchOS)
        lockScreen = Self.map(settings.lockScreenSetting)
        alertStyle = Self.map(settings.alertStyle)
        previews = Self.map(settings.showPreviewsSetting)
        #endif
    }

    static func map(_ setting: UNNotificationSetting) -> NotificationFeatureSetting {
        switch setting {
        case .enabled: .enabled
        case .disabled: .disabled
        case .notSupported: .notSupported
        @unknown default: .notSupported
        }
    }

    #if !os(tvOS) && !os(watchOS)
    static func map(_ style: UNAlertStyle) -> NotificationAlertStyle {
        switch style {
        case .none: .off
        case .banner: .banner
        case .alert: .alert
        @unknown default: .notSupported
        }
    }

    static func map(_ previews: UNShowPreviewsSetting) -> NotificationPreviews {
        switch previews {
        case .always: .always
        case .whenAuthenticated: .whenUnlocked
        case .never: .never
        @unknown default: .notSupported
        }
    }
    #endif
}
