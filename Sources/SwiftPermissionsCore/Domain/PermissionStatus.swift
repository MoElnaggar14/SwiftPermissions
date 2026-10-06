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
///
/// ## Moving to 4.0
///
/// In 4.0 `limited` carries a ``Limitation`` (`case limited(Limitation)`). `case .limited:`
/// in a `switch` keeps compiling. To be ready for the rest:
///
/// - Use ``isLimited`` instead of `status == .limited`.
/// - Build the value with ``limited(_:)``, e.g. `.limited(.selectedItems)` in stubs.
/// - Use ``description`` instead of the deprecated `rawValue` for logging, and the
///   `Codable` form for storage.
public enum PermissionStatus: Sendable, Hashable, CaseIterable, CustomStringConvertible {
    /// The user hasn't been asked yet. Requesting will show the system prompt.
    case notDetermined
    /// The user declined. Only the Settings app can change this.
    case denied
    /// Access is blocked by a policy the user can't change (parental controls, MDM).
    case restricted
    /// Full access.
    case authorized
    /// Partial access, e.g. selected photos, write-only calendar, or when-in-use location
    /// when ``Permission/locationAlways`` was asked for. ``Limitation`` lists the reasons.
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

    /// The status's name, e.g. `"authorized"`. Use it instead of `rawValue` for logging.
    public var description: String { storageValue }
}

public extension PermissionStatus {
    /// Whether the status is ``limited``, whatever the reason.
    ///
    /// Use it instead of `status == .limited`, which won't compile in 4.0, where `limited`
    /// carries a ``Limitation``.
    var isLimited: Bool { self == .limited }

    /// Builds ``limited``. In 3.x the reason is dropped; in 4.0 this is the case itself, so
    /// code such as `StubPermissionProvider(.photoLibrary, status: .limited(.selectedItems))`
    /// compiles unchanged.
    static func limited(_ limitation: Limitation) -> PermissionStatus { .limited }
}

// MARK: - Storage

extension PermissionStatus {
    /// The form statuses are stored and logged in: the case name, e.g. `"authorized"`.
    var storageValue: String {
        switch self {
        case .notDetermined: "notDetermined"
        case .denied: "denied"
        case .restricted: "restricted"
        case .authorized: "authorized"
        case .limited: "limited"
        case .provisional: "provisional"
        case .unavailable: "unavailable"
        }
    }

    /// Reads ``storageValue``, and the 4.0 form of a limited status
    /// (`"limited.selectedItems"`, …) as ``limited``. Data written by 4.0 then still reads
    /// after rolling back to 3.x.
    init?(storageValue: String) {
        switch storageValue {
        case "notDetermined": self = .notDetermined
        case "denied": self = .denied
        case "restricted": self = .restricted
        case "authorized": self = .authorized
        case "limited": self = .limited
        case "provisional": self = .provisional
        case "unavailable": self = .unavailable
        default:
            let prefix = "limited."
            guard storageValue.hasPrefix(prefix),
                  Limitation(rawValue: String(storageValue.dropFirst(prefix.count))) != nil else {
                return nil
            }
            self = .limited
        }
    }
}

extension PermissionStatus: Codable {
    public init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard let status = PermissionStatus(storageValue: value) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown status '\(value)'")
            )
        }
        self = status
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageValue)
    }
}

// Written by hand, rather than as `String` raw values, so `rawValue` can be deprecated
// before 4.0 removes it: a case with a payload can't have a raw value.
extension PermissionStatus: RawRepresentable {
    public typealias RawValue = String

    @available(*, deprecated, message: "PermissionStatus loses raw values in 4.0. Decode it with Codable instead.")
    public init?(rawValue: String) {
        self.init(storageValue: rawValue)
    }

    @available(*, deprecated, message: "PermissionStatus loses raw values in 4.0. Use description or Codable instead.")
    public var rawValue: String { storageValue }
}
