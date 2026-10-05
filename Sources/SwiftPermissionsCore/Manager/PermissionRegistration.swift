/// One or more providers to register with a ``PermissionManager``.
///
/// Each framework lives in its own product, and each product adds static members
/// here, so you register exactly what you link:
///
/// ```swift
/// import SwiftPermissionsCamera    // .camera, .microphone
/// import SwiftPermissionsPhotos    // .photoLibrary, .photoLibraryAddOnly
///
/// let permissions = PermissionManager(permissions: [.camera, .photoLibrary])
/// ```
///
/// Linking only what you use matters: App Store review scans the binary, and code that
/// can request a permission (location, contacts, …) makes it ask for that permission's
/// usage description even if your app never requests it.
public struct PermissionRegistration: Sendable {
    public let providers: [any PermissionProvider]

    public init(_ providers: [any PermissionProvider]) {
        self.providers = providers
    }

    public init(_ provider: any PermissionProvider) {
        self.init([provider])
    }

    /// Registers a custom or reconfigured provider.
    public static func provider(_ provider: any PermissionProvider) -> PermissionRegistration {
        PermissionRegistration(provider)
    }
}

public extension PermissionProviderRegistry {
    /// A registry with the given registrations. Later registrations replace earlier
    /// ones for the same permission.
    init(registering registrations: [PermissionRegistration]) {
        self.init(registrations.flatMap(\.providers))
    }
}

extension Permission {
    /// The product whose provider handles this built-in permission, and how to register it.
    var registrationHint: (product: String, registration: String)? {
        switch self {
        case .camera: ("SwiftPermissionsCamera", ".camera")
        case .microphone: ("SwiftPermissionsCamera", ".microphone")
        case .photoLibrary: ("SwiftPermissionsPhotos", ".photoLibrary")
        case .photoLibraryAddOnly: ("SwiftPermissionsPhotos", ".photoLibraryAddOnly")
        case .contacts: ("SwiftPermissionsContacts", ".contacts")
        case .calendar: ("SwiftPermissionsCalendar", ".calendar")
        case .calendarWriteOnly: ("SwiftPermissionsCalendar", ".calendarWriteOnly")
        case .reminders: ("SwiftPermissionsCalendar", ".reminders")
        case .locationWhenInUse: ("SwiftPermissionsLocation", ".locationWhenInUse")
        case .locationAlways: ("SwiftPermissionsLocation", ".locationAlways")
        case .notifications: ("SwiftPermissionsCore", ".notifications")
        case .motion: ("SwiftPermissionsMotion", ".motion")
        case .tracking: ("SwiftPermissionsTracking", ".tracking")
        case .bluetooth: ("SwiftPermissionsBluetooth", ".bluetooth")
        case .speechRecognition: ("SwiftPermissionsSpeech", ".speechRecognition")
        case .mediaLibrary: ("SwiftPermissionsMediaLibrary", ".mediaLibrary")
        case .siri: ("SwiftPermissionsSiri", ".siri")
        case .biometrics: ("SwiftPermissionsBiometrics", ".biometrics")
        case .health: ("SwiftPermissionsHealth", ".health(share:read:)")
        default: nil
        }
    }
}
