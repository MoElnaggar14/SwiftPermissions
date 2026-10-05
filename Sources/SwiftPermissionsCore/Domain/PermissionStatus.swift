/// The user's current decision for a ``Permission``, normalised across Apple's frameworks.
///
/// Each framework has its own authorization enum; providers map them onto this one so
/// your app logic has a single vocabulary. Nothing is collapsed that matters for UX:
/// `limited` photo access, `provisional` notifications and parental `restricted`
/// controls each keep their own case.
///
/// ## Stability
///
/// The set of cases is fixed for the 3.x releases, so you can switch over it exhaustively
/// without a `default`. New permissions map onto these cases. Adding a case would break
/// exhaustive switches, so it only happens in a major release.
public enum PermissionStatus: String, Sendable, Codable, CaseIterable, CustomStringConvertible {
    /// The user hasn't been asked yet. Requesting will show the system prompt.
    case notDetermined
    /// The user declined. Only the Settings app can change this.
    case denied
    /// Access is blocked by a policy the user can't change (parental controls, MDM).
    case restricted
    /// Full access.
    case authorized
    /// Partial access, e.g. selected photos, write-only calendar, or when-in-use location
    /// when ``Permission/locationAlways`` was asked for.
    case limited
    /// Notifications delivered quietly without having asked the user (iOS 12+).
    case provisional
    /// The capability doesn't exist on this platform or device (no camera, no HealthKit, ...).
    case unavailable

    /// Whether the feature can be used, at least partially.
    public var isGranted: Bool {
        switch self {
        case .authorized, .limited, .provisional: true
        case .notDetermined, .denied, .restricted, .unavailable: false
        }
    }

    /// Whether calling ``PermissionRequesting/request(_:)`` will show a system prompt.
    public var canRequest: Bool { self == .notDetermined }

    /// Whether the only path forward is sending the user to Settings.
    public var requiresSettings: Bool { self == .denied }

    public var description: String { rawValue }
}
