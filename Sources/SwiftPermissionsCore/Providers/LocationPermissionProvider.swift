@preconcurrency import CoreLocation

/// Location access, when-in-use or always.
///
/// For ``Permission/locationAlways``, when-in-use authorization is reported as
/// ``PermissionStatus/limited``. iOS only offers the "upgrade to Always" prompt once,
/// so after that the user has to change it in Settings.
public struct LocationPermissionProvider: PermissionProvider {
    private enum Level: Sendable { case whenInUse, always }

    public let permission: Permission
    private let level: Level

    public static let whenInUse = LocationPermissionProvider(permission: .locationWhenInUse, level: .whenInUse)
    #if !os(tvOS)
    public static let always = LocationPermissionProvider(permission: .locationAlways, level: .always)
    #endif

    private init(permission: Permission, level: Level) {
        self.permission = permission
        self.level = level
    }

    public var requiredUsageDescriptionKeys: [String] {
        #if os(macOS)
        // macOS uses one key for both levels.
        ["NSLocationWhenInUseUsageDescription"]
        #else
        level == .always
            ? ["NSLocationWhenInUseUsageDescription", "NSLocationAlwaysAndWhenInUseUsageDescription"]
            : ["NSLocationWhenInUseUsageDescription"]
        #endif
    }

    public func status() async -> PermissionStatus {
        let status = await MainActor.run { CLLocationManager().authorizationStatus }
        return Self.map(status, wantsAlways: level == .always)
    }

    public func request() async throws -> PermissionStatus {
        let request = await LocationAuthorizationRequest()
        let status = await request.run(always: level == .always)
        return Self.map(status, wantsAlways: level == .always)
    }

    static func map(_ status: CLAuthorizationStatus, wantsAlways: Bool) -> PermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .restricted: .restricted
        case .authorizedAlways: .authorized
        case .authorizedWhenInUse: wantsAlways ? .limited : .authorized
        @unknown default: .denied
        }
    }
}

/// Bridges one `CLLocationManager` authorization prompt to async/await.
///
/// `CLLocationManager` reports the current status to its delegate as soon as it's set,
/// before the user answers, so `.notDetermined` callbacks are ignored. Each request owns
/// its own manager and continuation, so concurrent requests can't overwrite each other.
@MainActor
private final class LocationAuthorizationRequest: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    func run(always: Bool) async -> CLAuthorizationStatus {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.delegate = self
            #if os(tvOS)
            manager.requestWhenInUseAuthorization()
            #else
            if always {
                manager.requestAlwaysAuthorization()
            } else {
                manager.requestWhenInUseAuthorization()
            }
            #endif
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status != .notDetermined, let continuation else { return }
        self.continuation = nil
        manager.delegate = nil
        continuation.resume(returning: status)
    }
}
