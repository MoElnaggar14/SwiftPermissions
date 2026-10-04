#if canImport(AppTrackingTransparency) && !os(watchOS)
@preconcurrency import AppTrackingTransparency

/// App Tracking Transparency.
///
/// The system ignores the request (and reports `.notDetermined`) while the app isn't
/// active, so request it from a foreground interaction, not from `application(_:didFinishLaunching…)`.
public struct TrackingPermissionProvider: PermissionProvider {
    public let permission = Permission.tracking
    public let requiredUsageDescriptionKeys = ["NSUserTrackingUsageDescription"]

    public init() {}

    public func status() async -> PermissionStatus {
        Self.map(ATTrackingManager.trackingAuthorizationStatus)
    }

    public func request() async throws -> PermissionStatus {
        Self.map(await ATTrackingManager.requestTrackingAuthorization())
    }

    static func map(_ status: ATTrackingManager.AuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .restricted: .restricted
        case .authorized: .authorized
        @unknown default: .denied
        }
    }
}
#endif
