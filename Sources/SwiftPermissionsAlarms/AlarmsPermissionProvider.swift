import SwiftPermissionsCore
#if os(iOS)
#if canImport(AlarmKit) && !targetEnvironment(macCatalyst)
@preconcurrency import AlarmKit
#endif

/// AlarmKit alarms and timers (iOS 26+), which sound through Silent mode and Focus.
///
/// Before iOS 26, on Mac Catalyst, and when built with an SDK that has no AlarmKit, the
/// status is ``PermissionStatus/unavailable``. An app with an older deployment target
/// can register it without availability checks.
public struct AlarmsPermissionProvider: PermissionProvider {
    public let permission = Permission.alarms
    public let requiredUsageDescriptionKeys = ["NSAlarmKitUsageDescription"]

    public init() {}

    public func status() async -> PermissionStatus {
        #if canImport(AlarmKit) && !targetEnvironment(macCatalyst)
        if #available(iOS 26.0, *) {
            return Self.map(AlarmManager.shared.authorizationState)
        }
        #endif
        return .unavailable
    }

    public func request() async throws -> PermissionStatus {
        #if canImport(AlarmKit) && !targetEnvironment(macCatalyst)
        if #available(iOS 26.0, *) {
            // iOS shows no prompt while the app is inactive, so the answer would never come.
            await AppActivation.waitUntilActive()
            return Self.map(try await AlarmManager.shared.requestAuthorization())
        }
        #endif
        return .unavailable
    }

    #if canImport(AlarmKit) && !targetEnvironment(macCatalyst)
    @available(iOS 26.0, *)
    static func map(_ state: AlarmManager.AuthorizationState) -> PermissionStatus {
        switch state {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        @unknown default: .denied
        }
    }
    #endif
}

public extension PermissionRegistration {
    /// AlarmKit alarms and timers (iOS 26+; `.unavailable` earlier). Needs `NSAlarmKitUsageDescription`.
    static var alarms: PermissionRegistration { PermissionRegistration(AlarmsPermissionProvider()) }
}
#endif
