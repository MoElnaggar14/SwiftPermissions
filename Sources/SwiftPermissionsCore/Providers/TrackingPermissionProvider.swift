#if canImport(AppTrackingTransparency) && !os(watchOS)
@preconcurrency import AppTrackingTransparency

/// App Tracking Transparency.
///
/// The system ignores the request (and reports `.notDetermined`) while the app isn't
/// active, so the provider waits until the app is active before asking. That makes it
/// safe in a batch right after another permission alert.
public struct TrackingPermissionProvider: PermissionProvider {
    public let permission = Permission.tracking
    public let requiredUsageDescriptionKeys = ["NSUserTrackingUsageDescription"]

    public init() {}

    public func status() async -> PermissionStatus {
        Self.map(ATTrackingManager.trackingAuthorizationStatus)
    }

    public func request() async throws -> PermissionStatus {
        #if canImport(UIKit)
        await AppActivation.waitUntilActive()
        #endif
        return Self.map(await ATTrackingManager.requestTrackingAuthorization())
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
