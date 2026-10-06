/// Identifies a capability the app needs the user's consent for.
///
/// `Permission` is an open set: the library ships the system permissions as static
/// members, and you can declare your own (for example, a permission backed by a
/// third-party SDK) and register a ``PermissionProvider`` for it.
///
/// ```swift
/// extension Permission {
///     static let pushToTalk = Permission("pushToTalk", displayName: "Push to Talk")
/// }
/// ```
public struct Permission: Hashable, Sendable, Codable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String
    /// A short, human-readable English name, suitable for settings rows and logs.
    public let displayName: String

    public init(_ rawValue: String, displayName: String? = nil) {
        self.rawValue = rawValue
        self.displayName = displayName ?? rawValue
    }

    public init(rawValue: String) {
        self = Permission.builtIn.first { $0.rawValue == rawValue } ?? Permission(rawValue)
    }

    public init(from decoder: any Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue }

    // Identity is the raw value only; the display name is presentation.
    public static func == (lhs: Permission, rhs: Permission) -> Bool { lhs.rawValue == rhs.rawValue }
    public func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }
}

// MARK: - System permissions

public extension Permission {
    static let camera = Permission("camera", displayName: "Camera")
    static let microphone = Permission("microphone", displayName: "Microphone")
    /// Read and write access to the photo library.
    static let photoLibrary = Permission("photoLibrary", displayName: "Photos")
    /// Add-only access to the photo library (saving images without reading the library).
    static let photoLibraryAddOnly = Permission("photoLibraryAddOnly", displayName: "Add to Photos")
    static let contacts = Permission("contacts", displayName: "Contacts")
    /// Full access to calendar events.
    static let calendar = Permission("calendar", displayName: "Calendar")
    /// Write-only access to calendar events (iOS 17+, macOS 14+). Falls back to full access on older systems.
    static let calendarWriteOnly = Permission("calendarWriteOnly", displayName: "Add Calendar Events")
    static let reminders = Permission("reminders", displayName: "Reminders")
    static let locationWhenInUse = Permission("locationWhenInUse", displayName: "Location While Using")
    static let locationAlways = Permission("locationAlways", displayName: "Location Always")
    static let notifications = Permission("notifications", displayName: "Notifications")
    static let motion = Permission("motion", displayName: "Motion & Fitness")
    /// App Tracking Transparency.
    static let tracking = Permission("tracking", displayName: "Tracking")
    static let bluetooth = Permission("bluetooth", displayName: "Bluetooth")
    static let speechRecognition = Permission("speechRecognition", displayName: "Speech Recognition")
    /// Apple Music and the local media library.
    static let mediaLibrary = Permission("mediaLibrary", displayName: "Media & Apple Music")
    static let siri = Permission("siri", displayName: "Siri")
    /// Face ID / Touch ID / Optic ID. See ``BiometricsPermissionProvider`` for what the status can and can't tell you.
    static let biometrics = Permission("biometrics", displayName: "Biometrics")
    /// HealthKit. Requires a ``HealthPermissionProvider`` configured with the data types you need.
    static let health = Permission("health", displayName: "Health")
    /// AlarmKit alarms and timers that sound through Silent mode and Focus (iOS 26+).
    static let alarms = Permission("alarms", displayName: "Alarms & Timers")

    /// Every permission the library knows about, whether or not it is available on the current platform.
    static let builtIn: [Permission] = [
        .camera, .microphone, .photoLibrary, .photoLibraryAddOnly, .contacts,
        .calendar, .calendarWriteOnly, .reminders, .locationWhenInUse, .locationAlways,
        .notifications, .motion, .tracking, .bluetooth, .speechRecognition,
        .mediaLibrary, .siri, .biometrics, .health, .alarms
    ]
}
