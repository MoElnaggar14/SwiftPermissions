/// The user's current decision for a ``Permission``, normalised across Apple's frameworks.
///
/// Each framework has its own authorization enum; providers map them onto this one so
/// your app logic has a single vocabulary. Nothing is collapsed that matters for UX:
/// `limited` access says why it's limited, `provisional` notifications and parental
/// `restricted` controls each keep their own case.
///
/// ```swift
/// switch try await permissions.request(.photoLibrary) {
/// case .authorized:              showLibrary()
/// case .limited(.selectedItems): showLibrary(banner: .selectMore)
/// case .limited:                 showLibrary()      // any other reason
/// case .provisional:             break
/// case .denied:                  await AppSettings.open(for: .photoLibrary)
/// case .notDetermined, .restricted, .unavailable: showUnavailableState()
/// }
/// ```
///
/// ## Stability
///
/// The set of cases, and of ``Limitation`` reasons, is fixed for the 4.x releases, so you
/// can switch over it exhaustively without a `default`. New permissions map onto these
/// cases. Adding a case would break exhaustive switches, so it only happens in a major
/// release.
///
/// ## Storing and logging
///
/// ``description`` and the `Codable` form are the same string: the case name, e.g.
/// `"authorized"`, and `"limited.selectedItems"` for a limited status. A 3.x `"limited"`
/// still decodes, as ``Limitation/partial``.
public enum PermissionStatus: Sendable, Hashable, CustomStringConvertible {
    /// The user hasn't been asked yet. Requesting will show the system prompt.
    case notDetermined
    /// The user declined. Only the Settings app can change this.
    case denied
    /// Access is blocked by a policy the user can't change (parental controls, MDM).
    case restricted
    /// Full access.
    case authorized
    /// Partial access, and why: selected photos or contacts, when-in-use location when
    /// ``Permission/locationAlways`` was asked for, write-only calendar, or some HealthKit
    /// share types. `case .limited:` matches every reason.
    case limited(Limitation)
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

    /// The status's name, e.g. `"authorized"` or `"limited.selectedItems"`. The same
    /// string as the `Codable` form, so it's safe to log and to compare with stored values.
    public var description: String { storageValue }
}

public extension PermissionStatus {
    /// Why access is limited, or `nil` for any other status.
    var limitation: Limitation? {
        switch self {
        case let .limited(limitation): limitation
        case .notDetermined, .denied, .restricted, .authorized, .provisional, .unavailable: nil
        }
    }

    /// Whether the status is ``limited(_:)``, whatever the reason.
    var isLimited: Bool { limitation != nil }
}

// MARK: - Storage

extension PermissionStatus {
    private static let limitedPrefix = "limited."

    /// The form statuses are stored and logged in: the case name, e.g. `"authorized"`, and
    /// `"limited.<reason>"` for a limited status.
    var storageValue: String {
        switch self {
        case .notDetermined: "notDetermined"
        case .denied: "denied"
        case .restricted: "restricted"
        case .authorized: "authorized"
        case let .limited(limitation): Self.limitedPrefix + limitation.rawValue
        case .provisional: "provisional"
        case .unavailable: "unavailable"
        }
    }

    /// Reads ``storageValue``, and the 3.x value `"limited"`, which has no reason.
    ///
    /// - Parameter permission: The permission the value was stored for, when known. A 3.x
    ///   `"limited"` then reads as the reason that permission's built-in provider meant
    ///   (``Limitation/legacy(for:)``); without it, as ``Limitation/partial``.
    init?(storageValue: String, permission: Permission? = nil) {
        switch storageValue {
        case "notDetermined": self = .notDetermined
        case "denied": self = .denied
        case "restricted": self = .restricted
        case "authorized": self = .authorized
        case "limited": self = .limited(.legacy(for: permission))
        case "provisional": self = .provisional
        case "unavailable": self = .unavailable
        default:
            guard storageValue.hasPrefix(Self.limitedPrefix),
                  let limitation = Limitation(rawValue: String(storageValue.dropFirst(Self.limitedPrefix.count)))
            else {
                return nil
            }
            self = .limited(limitation)
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
