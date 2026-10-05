import SwiftPermissionsCore
#if os(iOS) || os(watchOS) || os(visionOS)
@preconcurrency import HealthKit

/// HealthKit access for a specific set of data types.
///
/// HealthKit hides read authorization by design: an app can't tell whether the user
/// allowed or denied reading a type. This provider therefore reports:
///
/// - ``PermissionStatus/notDetermined`` while HealthKit would still show its sheet.
/// - The aggregated sharing (write) status when you write types: ``PermissionStatus/authorized``
///   if all are allowed, ``PermissionStatus/denied`` if none, ``PermissionStatus/limited`` otherwise.
/// - ``PermissionStatus/authorized`` once the sheet has been shown, for read-only setups.
///   Your queries may still return no data if the user declined.
///
/// Register it with the types you use. The app needs the HealthKit capability; without
/// it (or with no types) the status is ``PermissionStatus/unavailable``.
///
/// ```swift
/// let permissions = PermissionManager(permissions: [
///     .health(read: [HKQuantityType(.stepCount)])
/// ])
/// ```
///
/// Only request share access for types your app can write: HealthKit raises an
/// exception (which Swift can't catch) for read-only types such as characteristics.
public struct HealthPermissionProvider: PermissionProvider, @unchecked Sendable {
    // HKHealthStore is documented as thread-safe and the type sets are immutable.
    public let permission = Permission.health
    private let store = HKHealthStore()
    private let shareTypes: Set<HKSampleType>
    private let readTypes: Set<HKObjectType>

    public init(share shareTypes: Set<HKSampleType> = [], read readTypes: Set<HKObjectType> = []) {
        self.shareTypes = shareTypes
        self.readTypes = readTypes
    }

    public var requiredUsageDescriptionKeys: [String] {
        var keys: [String] = []
        if !readTypes.isEmpty { keys.append("NSHealthShareUsageDescription") }
        if !shareTypes.isEmpty { keys.append("NSHealthUpdateUsageDescription") }
        return keys
    }

    public func status() async -> PermissionStatus {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        let requestStatus: HKAuthorizationRequestStatus
        do {
            requestStatus = try await store.statusForAuthorizationRequest(toShare: shareTypes, read: readTypes)
        } catch {
            // Missing HealthKit entitlement, or no data types: nothing can be requested.
            return .unavailable
        }
        if requestStatus == .shouldRequest { return .notDetermined }
        guard !shareTypes.isEmpty else { return .authorized }
        return Self.aggregate(shareTypes.map { store.authorizationStatus(for: $0) })
    }

    public func request() async throws -> PermissionStatus {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        return await status()
    }

    static func aggregate(_ statuses: [HKAuthorizationStatus]) -> PermissionStatus {
        if statuses.contains(.notDetermined) { return .notDetermined }
        let authorized = statuses.filter { $0 == .sharingAuthorized }.count
        switch authorized {
        case statuses.count: return .authorized
        case 0: return .denied
        default: return .limited
        }
    }
}

public extension PermissionRegistration {
    /// HealthKit for the given data types. Needs the HealthKit capability and
    /// `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription`.
    static func health(share: Set<HKSampleType> = [], read: Set<HKObjectType> = []) -> PermissionRegistration {
        PermissionRegistration(HealthPermissionProvider(share: share, read: read))
    }
}
#endif
