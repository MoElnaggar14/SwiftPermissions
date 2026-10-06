import SwiftPermissionsCore
#if os(macOS)
import CoreGraphics

/// Screen Recording on macOS: capturing the screen, or windows of other apps.
///
/// There's no usage description. The first ``request()`` shows the system alert, which
/// sends the user to System Settings > Privacy & Security > Screen Recording; later
/// requests show nothing. macOS only says whether access is granted, so the status is
/// ``PermissionStatus/notDetermined`` until the provider's ``PermissionRequestHistory``
/// has a request on record, and ``PermissionStatus/denied`` after that. The default history
/// is in memory, so that's per launch; pass a ``UserDefaultsRequestHistory`` to remember
/// across launches. A grant always reads ``PermissionStatus/authorized``. The app may have
/// to be relaunched before a new grant takes effect.
public struct ScreenRecordingPermissionProvider: PermissionProvider {
    public let permission = Permission.screenRecording

    private let access: any ScreenCaptureAccess
    private let history: any PermissionRequestHistory

    /// - Parameter history: Remembers that the provider asked. Defaults to an in-memory
    ///   history that's lost when the app quits.
    public init(history: any PermissionRequestHistory = InMemoryRequestHistory()) {
        self.init(access: SystemScreenCaptureAccess(), history: history)
    }

    init(access: any ScreenCaptureAccess, history: any PermissionRequestHistory = InMemoryRequestHistory()) {
        self.access = access
        self.history = history
    }

    public func status() async -> PermissionStatus {
        Self.map(granted: access.preflight(), requested: history.hasRequested(permission))
    }

    public func request() async throws -> PermissionStatus {
        let granted = access.request()
        history.recordRequest(permission)
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

    /// Screen Recording (macOS), remembering requests in `history`, for example a
    /// ``UserDefaultsRequestHistory`` so a declined request still reads `.denied` after a relaunch.
    static func screenRecording(history: any PermissionRequestHistory) -> PermissionRegistration {
        PermissionRegistration(ScreenRecordingPermissionProvider(history: history))
    }
}
#endif
