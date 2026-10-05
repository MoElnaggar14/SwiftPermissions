import SwiftPermissionsCore
#if os(iOS) || os(watchOS)
@preconcurrency import Intents

/// SiriKit access. Requires the Siri capability (entitlement) in addition to the usage description.
public struct SiriPermissionProvider: PermissionProvider {
    public let permission = Permission.siri
    public let requiredUsageDescriptionKeys = ["NSSiriUsageDescription"]

    public init() {}

    public func status() async -> PermissionStatus {
        Self.map(INPreferences.siriAuthorizationStatus())
    }

    public func request() async throws -> PermissionStatus {
        let status: INSiriAuthorizationStatus = await withCheckedContinuation { continuation in
            INPreferences.requestSiriAuthorization { continuation.resume(returning: $0) }
        }
        return Self.map(status)
    }

    static func map(_ status: INSiriAuthorizationStatus) -> PermissionStatus {
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
    /// Siri. Needs `NSSiriUsageDescription` and the Siri capability
    /// (`com.apple.developer.siri` entitlement).
    static var siri: PermissionRegistration { PermissionRegistration(SiriPermissionProvider()) }
}
#endif
