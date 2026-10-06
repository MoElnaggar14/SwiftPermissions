import SwiftPermissionsCore
#if os(macOS)
import CoreGraphics

/// Screen Recording on macOS: capturing the screen, or windows of other apps.
///
/// There's no usage description. The first ``request()`` shows the system alert, which
/// sends the user to System Settings > Privacy & Security > Screen Recording; later
/// requests show nothing. macOS only says whether access is granted, so the status is
/// ``PermissionStatus/notDetermined`` until this provider has asked in the current
/// launch, and ``PermissionStatus/denied`` after that. The app may have to be relaunched
/// before a new grant takes effect.
public struct ScreenRecordingPermissionProvider: PermissionProvider {
    public let permission = Permission.screenRecording

    private let access: any ScreenCaptureAccess
    private let requested = RequestedFlag()

    public init() {
        self.init(access: SystemScreenCaptureAccess())
    }

    init(access: any ScreenCaptureAccess) {
        self.access = access
    }

    public func status() async -> PermissionStatus {
        Self.map(granted: access.preflight(), requested: requested.isSet)
    }

    public func request() async throws -> PermissionStatus {
        let granted = access.request()
        requested.set()
        return Self.map(granted: granted, requested: true)
    }

    static func map(granted: Bool, requested: Bool) -> PermissionStatus {
        if granted { return .authorized }
        return requested ? .denied : .notDetermined
    }
}

/// The CoreGraphics calls, behind a protocol so tests never touch TCC.
protocol ScreenCaptureAccess: Sendable {
    /// Whether access is granted. Never prompts.
    func preflight() -> Bool
    /// Shows the system alert the first time, and returns whether access is granted.
    func request() -> Bool
}

struct SystemScreenCaptureAccess: ScreenCaptureAccess {
    func preflight() -> Bool { CGPreflightScreenCaptureAccess() }
    func request() -> Bool { CGRequestScreenCaptureAccess() }
}

public extension PermissionRegistration {
    /// Screen Recording (macOS). No usage description; the user grants it in System Settings.
    static var screenRecording: PermissionRegistration {
        PermissionRegistration(ScreenRecordingPermissionProvider())
    }
}
#endif
