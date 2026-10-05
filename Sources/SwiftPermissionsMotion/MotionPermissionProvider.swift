import SwiftPermissionsCore
#if os(iOS) || os(watchOS)
@preconcurrency import CoreMotion

/// Motion & Fitness activity access.
///
/// Core Motion has no explicit request API; the prompt appears on first data access.
/// This provider triggers it with an empty activity query.
public struct MotionPermissionProvider: PermissionProvider {
    public let permission = Permission.motion
    public let requiredUsageDescriptionKeys = ["NSMotionUsageDescription"]

    public init() {}

    public func status() async -> PermissionStatus {
        guard CMMotionActivityManager.isActivityAvailable() else { return .unavailable }
        return Self.map(CMMotionActivityManager.authorizationStatus())
    }

    public func request() async throws -> PermissionStatus {
        guard CMMotionActivityManager.isActivityAvailable() else { return .unavailable }
        let manager = CMMotionActivityManager()
        let now = Date()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            manager.queryActivityStarting(from: now, to: now, to: .main) { _, _ in
                continuation.resume()
            }
        }
        // The query only calls back while the manager is alive.
        withExtendedLifetime(manager) {}
        return await status()
    }

    static func map(_ status: CMAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .restricted: .restricted
        case .authorized: .authorized
        @unknown default: .denied
        }
    }
}

public extension PermissionRegistration {
    /// Motion & Fitness. Needs `NSMotionUsageDescription`.
    static var motion: PermissionRegistration { PermissionRegistration(MotionPermissionProvider()) }
}
#endif
