@preconcurrency import CoreLocation
import Foundation
import SwiftPermissionsCore

/// A snapshot of a `CLServiceSession.Diagnostic`: why a service session's authorization
/// requirement is, or isn't, met.
///
/// Every flag is `false` when nothing is wrong. It's a plain value on every platform, so
/// you can build one in tests.
public struct LocationSessionDiagnostic: Sendable, Equatable {
    /// The user denied location for this app.
    public var authorizationDenied = false
    /// Location Services are off system-wide.
    public var authorizationDeniedGlobally = false
    /// Location is blocked by a policy the user can't change (parental controls, MDM).
    public var authorizationRestricted = false
    /// The app isn't in use enough for Core Location to show the prompt now,
    /// e.g. it's in the background.
    public var insufficientlyInUse = false
    /// The app sets `NSLocationRequireExplicitServiceSession` and needs a session for
    /// location updates.
    public var serviceSessionRequired = false
    /// The session asked for precise location and the user kept approximate location.
    public var fullAccuracyDenied = false
    /// The session asked for Always and the user kept When In Use.
    public var alwaysAuthorizationDenied = false
    /// The authorization prompt is on screen.
    public var authorizationRequestInProgress = false

    /// A diagnostic with every flag `false`.
    public init() {}
}

public extension LocationPermissionProvider {
    /// Maps a session diagnostic onto ``PermissionStatus``.
    ///
    /// The diagnostic says what's wrong, not what's granted, so the app's current
    /// authorization fills in the rest: with no flag set, the status is the one
    /// ``status()`` reports. Accuracy isn't a status; read ``LocationSessionDiagnostic/fullAccuracyDenied``.
    internal static func map(
        _ diagnostic: LocationSessionDiagnostic,
        authorization: CLAuthorizationStatus,
        wantsAlways: Bool
    ) -> PermissionStatus {
        if diagnostic.authorizationRestricted { return .restricted }
        if diagnostic.authorizationDeniedGlobally {
            // As in `status()`: with Location Services off no prompt can appear.
            return authorization == .notDetermined ? .unavailable : .denied
        }
        if diagnostic.authorizationDenied { return .denied }
        let status = map(authorization, wantsAlways: wantsAlways)
        if wantsAlways && diagnostic.alwaysAuthorizationDenied && status == .authorized {
            return .limited
        }
        return status
    }
}

#if !os(macOS)
/// A Core Location service session (`CLServiceSession`) that the app owns.
///
/// While a session is alive, Core Location knows the app needs location at the session's
/// authorization level. It shows the authorization prompt when the app is in use and
/// the user hasn't decided yet, and keeps reporting diagnostics that explain why location
/// isn't available. Apps that set `NSLocationRequireExplicitServiceSession` in Info.plist
/// get location updates only while they hold a session.
///
/// Keep the session for as long as the feature needs location, for example in the model
/// of a map screen, and end it when the feature goes away. ``invalidate()`` ends it, and
/// so does releasing the last reference. Nothing in this package keeps a session alive
/// for you.
///
/// Create one with ``LocationPermissionProvider/startServiceSession(fullAccuracyPurposeKey:)``.
@available(iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
public final class LocationServiceSession: Sendable {
    /// One diagnostic from Core Location, with the status it implies.
    public struct Update: Sendable, Equatable {
        /// The location status, for the provider that started the session.
        public let status: PermissionStatus
        /// The diagnostic Core Location reported.
        public let diagnostic: LocationSessionDiagnostic

        public init(status: PermissionStatus, diagnostic: LocationSessionDiagnostic) {
            self.status = status
            self.diagnostic = diagnostic
        }
    }

    /// Updates for each diagnostic Core Location reports, until the session ends.
    ///
    /// The stream has one consumer; iterate it from one task. It finishes when the
    /// session is invalidated or released. For the current status at any time, call
    /// ``LocationPermissionProvider/status()``.
    public let updates: AsyncStream<Update>

    private let session: CLServiceSession
    private let continuation: AsyncStream<Update>.Continuation
    private let task: Task<Void, Never>

    init(session: CLServiceSession, wantsAlways: Bool) {
        let (stream, continuation) = AsyncStream.makeStream(of: Update.self)
        self.updates = stream
        self.session = session
        self.continuation = continuation
        // The task holds the Core Location session, never `self`, so releasing the
        // handle still runs `deinit`.
        self.task = Task {
            do {
                for try await diagnostic in session.diagnostics {
                    if Task.isCancelled { break }
                    let snapshot = LocationSessionDiagnostic(diagnostic)
                    let authorization = await MainActor.run { CLLocationManager().authorizationStatus }
                    let status = LocationPermissionProvider.map(
                        snapshot,
                        authorization: authorization,
                        wantsAlways: wantsAlways
                    )
                    continuation.yield(Update(status: status, diagnostic: snapshot))
                }
            } catch {
                // The diagnostics sequence ended; there's nothing to recover.
            }
            continuation.finish()
        }
    }

    deinit {
        invalidate()
    }

    /// Ends the session. Core Location stops treating location as needed by it, and
    /// ``updates`` finishes. Safe to call more than once.
    public func invalidate() {
        session.invalidate()
        task.cancel()
        continuation.finish()
    }
}

@available(iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension LocationSessionDiagnostic {
    init(_ diagnostic: CLServiceSession.Diagnostic) {
        self.init()
        authorizationDenied = diagnostic.authorizationDenied
        authorizationDeniedGlobally = diagnostic.authorizationDeniedGlobally
        authorizationRestricted = diagnostic.authorizationRestricted
        insufficientlyInUse = diagnostic.insufficientlyInUse
        serviceSessionRequired = diagnostic.serviceSessionRequired
        fullAccuracyDenied = diagnostic.fullAccuracyDenied
        alwaysAuthorizationDenied = diagnostic.alwaysAuthorizationDenied
        authorizationRequestInProgress = diagnostic.authorizationRequestInProgress
    }
}

public extension LocationPermissionProvider {
    /// Starts a Core Location service session at this provider's level (When In Use or
    /// Always). It's an alternative to ``request()``, which stays the default.
    ///
    /// The session shows the authorization prompt if the user hasn't decided yet, and
    /// reports why location isn't available through ``LocationServiceSession/updates``.
    /// It lasts until you call ``LocationServiceSession/invalidate()`` or release it, so
    /// keep it for as long as the feature needs location.
    ///
    /// Pass `fullAccuracyPurposeKey` to also ask for precise location. It names an entry
    /// in the `NSLocationTemporaryUsageDescriptionDictionary` Info.plist dictionary.
    ///
    /// - Throws: ``PermissionError/missingUsageDescription(_:keys:)`` when a usage
    ///   description or the purpose string is missing, before any prompt.
    @available(iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func startServiceSession(fullAccuracyPurposeKey: String? = nil) async throws -> LocationServiceSession {
        let info = InfoPlist.main
        var missing = requiredUsageDescriptionKeys.filter { info.usageDescription(forKey: $0) == nil }
        if let purposeKey = fullAccuracyPurposeKey {
            let purposes = Bundle.main.object(forInfoDictionaryKey: Self.temporaryUsageDescriptionsKey)
            if !Self.hasPurpose(purposeKey, in: purposes) {
                missing.append("\(Self.temporaryUsageDescriptionsKey).\(purposeKey)")
            }
        }
        guard missing.isEmpty else {
            throw PermissionError.missingUsageDescription(permission, keys: missing)
        }
        #if os(iOS)
        // The prompt can't appear until the app is active.
        await AppActivation.waitUntilActive()
        #endif
        let session: CLServiceSession
        if let fullAccuracyPurposeKey {
            session = CLServiceSession(
                authorization: serviceSessionRequirement,
                fullAccuracyPurposeKey: fullAccuracyPurposeKey
            )
        } else {
            session = CLServiceSession(authorization: serviceSessionRequirement)
        }
        return LocationServiceSession(session: session, wantsAlways: wantsAlways)
    }

    @available(iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    private var serviceSessionRequirement: CLServiceSession.AuthorizationRequirement {
        #if os(tvOS) || os(visionOS)
        // No Always authorization on tvOS and visionOS.
        .whenInUse
        #else
        wantsAlways ? .always : .whenInUse
        #endif
    }
}
#endif
