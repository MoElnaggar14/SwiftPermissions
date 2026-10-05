@preconcurrency import CoreLocation
#if os(iOS)
import UIKit
#endif

/// Location access, when-in-use or always.
///
/// For ``Permission/locationAlways``, when-in-use authorization is reported as
/// ``PermissionStatus/limited``. On iOS, requesting from `.limited` asks for the upgrade
/// to Always. iOS offers that prompt at most once; if it doesn't appear (or the user
/// keeps "While Using"), the request returns `.limited` instead of waiting forever.
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

    public func canRequest(from status: PermissionStatus) -> Bool {
        #if os(iOS)
        status == .notDetermined || (level == .always && status == .limited)
        #else
        status == .notDetermined
        #endif
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
    /// Asking for Always while When-In-Use is granted.
    private var isUpgrade = false
    private var upgradePromptShown = false
    private var observations: [OneShotObservationToken] = []

    func run(always: Bool) async -> CLAuthorizationStatus {
        #if os(iOS)
        isUpgrade = always && manager.authorizationStatus == .authorizedWhenInUse
        #endif
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.delegate = self
            #if os(iOS)
            if isUpgrade { watchForUpgradeOutcome() }
            #endif
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
        guard status != .notDetermined else { return }
        // During an upgrade the delegate first reports the existing When-In-Use
        // status; only a different status is an answer.
        #if os(iOS)
        if isUpgrade && status == .authorizedWhenInUse { return }
        #endif
        finish(with: status)
    }

    private func finish(with status: CLAuthorizationStatus) {
        guard let continuation else { return }
        self.continuation = nil
        manager.delegate = nil
        observations.forEach { $0.cancel() }
        observations.removeAll()
        continuation.resume(returning: status)
    }

    #if os(iOS)
    /// The upgrade prompt may not appear at all (iOS shows it once), and keeping
    /// "While Using" produces no callback. The app resigning active means a prompt
    /// is on screen; becoming active again means it was answered. No resign within
    /// a short window means no prompt is coming.
    private func watchForUpgradeOutcome() {
        observations.append(OneShotObservationToken(name: UIApplication.willResignActiveNotification) { [weak self] in
            self?.upgradePromptShown = true
        })
        observations.append(OneShotObservationToken(name: UIApplication.didBecomeActiveNotification) { [weak self] in
            guard let self, self.upgradePromptShown else { return }
            self.finish(with: self.manager.authorizationStatus)
        })
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard let self, !self.upgradePromptShown else { return }
            self.finish(with: self.manager.authorizationStatus)
        }
    }
    #endif
}

#if os(iOS)
/// A main-actor notification observer that can be cancelled.
@MainActor
private final class OneShotObservationToken {
    private var token: (any NSObjectProtocol)?

    init(name: Notification.Name, handler: @escaping @Sendable @MainActor () -> Void) {
        token = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
    }

    func cancel() {
        if let token { NotificationCenter.default.removeObserver(token) }
        token = nil
    }
}
#else
@MainActor
private final class OneShotObservationToken {
    func cancel() {}
}
#endif
