#if os(iOS) || os(macOS) || os(visionOS)
@preconcurrency import LocalAuthentication

/// Face ID / Touch ID / Optic ID.
///
/// Biometrics aren't a regular permission: there's no API to ask for consent without
/// also authenticating, and iOS shows its one-time Face ID consent automatically on the
/// first evaluation. So the status describes whether biometrics are usable right now:
///
/// - ``PermissionStatus/authorized``: enrolled and usable.
/// - ``PermissionStatus/denied``: the user turned off Face ID for this app in Settings.
/// - ``PermissionStatus/restricted``: locked out after too many failed attempts.
/// - ``PermissionStatus/unavailable``: no biometric hardware, or nothing enrolled.
///
/// The status is never ``PermissionStatus/notDetermined``, so ``PermissionManager``
/// never triggers an authentication from `request(_:)`. Authenticate where the feature
/// actually needs it, with ``authenticate(reason:)``.
public struct BiometricsPermissionProvider: PermissionProvider {
    public let permission = Permission.biometrics

    public init() {}

    public var requiredUsageDescriptionKeys: [String] {
        #if os(iOS)
        ["NSFaceIDUsageDescription"]
        #else
        []
        #endif
    }

    public func status() async -> PermissionStatus {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return .authorized
        }
        return Self.map(error.flatMap { LAError.Code(rawValue: $0.code) }, biometryType: context.biometryType)
    }

    public func request() async throws -> PermissionStatus {
        await status()
    }

    /// Runs a biometric authentication and reports whether it succeeded.
    public func authenticate(reason: String) async throws -> Bool {
        try await LAContext().evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
    }

    static func map(_ code: LAError.Code?, biometryType: LABiometryType) -> PermissionStatus {
        switch code {
        case .biometryLockout?:
            return .restricted
        case .biometryNotAvailable?:
            // Hardware present but unavailable to this app: the user declined Face ID for it.
            return biometryType == .none ? .unavailable : .denied
        default:
            return .unavailable
        }
    }
}
#endif
