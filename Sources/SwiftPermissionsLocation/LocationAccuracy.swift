@preconcurrency import CoreLocation
import Foundation
import SwiftPermissionsCore

/// How precise the locations the app receives are.
///
/// Since iOS 14, users can grant location with **Precise** turned off. Location is still
/// ``PermissionStatus/authorized``, but coordinates are only accurate to an area several
/// kilometres wide.
public enum LocationAccuracy: Sendable, Equatable {
    /// Precise location.
    case full
    /// Approximate location: the user turned off Precise.
    case reduced
}

public extension LocationPermissionProvider {
    /// The Info.plist dictionary that holds the purpose strings for
    /// ``requestTemporaryFullAccuracy(purposeKey:)``.
    static let temporaryUsageDescriptionsKey = "NSLocationTemporaryUsageDescriptionDictionary"

    /// The accuracy the user granted, or `nil` while location isn't authorized
    /// (any status other than ``PermissionStatus/authorized`` or ``PermissionStatus/limited``).
    func accuracy() async -> LocationAccuracy? {
        let (status, accuracy) = await MainActor.run {
            let manager = CLLocationManager()
            return (manager.authorizationStatus, manager.accuracyAuthorization)
        }
        return Self.map(status, accuracy)
    }

    #if !os(tvOS)
    /// Asks the user for precise location for this session, when they granted only
    /// approximate location. Returns the accuracy afterwards; `.full` straight away if
    /// it already is.
    ///
    /// `purposeKey` names an entry in the `NSLocationTemporaryUsageDescriptionDictionary`
    /// Info.plist dictionary, whose string the system shows as the reason. The key is
    /// checked first, as usage descriptions are.
    ///
    /// - Throws: ``PermissionError/missingUsageDescription(_:keys:)`` when the purpose
    ///   string is missing, and ``PermissionError/requestFailed(_:reason:)`` when location
    ///   isn't authorized yet or Core Location reports an error.
    func requestTemporaryFullAccuracy(purposeKey: String) async throws -> LocationAccuracy {
        let info = Bundle.main.object(forInfoDictionaryKey: Self.temporaryUsageDescriptionsKey)
        guard Self.hasPurpose(purposeKey, in: info) else {
            throw PermissionError.missingUsageDescription(
                permission,
                keys: ["\(Self.temporaryUsageDescriptionsKey).\(purposeKey)"]
            )
        }
        guard let current = await accuracy() else {
            throw PermissionError.requestFailed(permission, reason: "Location isn't authorized yet; request it first.")
        }
        if current == .full { return .full }
        #if os(iOS)
        await AppActivation.waitUntilActive()
        #endif
        do {
            let (status, accuracy) = try await Self.askForTemporaryFullAccuracy(purposeKey: purposeKey)
            return Self.map(status, accuracy) ?? .reduced
        } catch {
            throw PermissionError.requestFailed(permission, reason: error.localizedDescription)
        }
    }

    @MainActor
    private static func askForTemporaryFullAccuracy(
        purposeKey: String
    ) async throws -> (CLAuthorizationStatus, CLAccuracyAuthorization) {
        let manager = CLLocationManager()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: purposeKey) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        return (manager.authorizationStatus, manager.accuracyAuthorization)
    }
    #endif

    // MARK: - Mapping

    /// `nil` unless location is authorized; reduced accuracy is reported as such, never
    /// as ``PermissionStatus/limited``, which for location means "when in use".
    internal static func map(
        _ status: CLAuthorizationStatus,
        _ accuracy: CLAccuracyAuthorization
    ) -> LocationAccuracy? {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            switch accuracy {
            case .fullAccuracy: return .full
            case .reducedAccuracy: return .reduced
            @unknown default: return .reduced
            }
        default:
            return nil
        }
    }

    /// Whether the temporary-usage dictionary has a non-empty string for `purposeKey`.
    internal static func hasPurpose(_ purposeKey: String, in dictionary: Any?) -> Bool {
        guard let purposes = dictionary as? [String: Any], let text = purposes[purposeKey] as? String else {
            return false
        }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
