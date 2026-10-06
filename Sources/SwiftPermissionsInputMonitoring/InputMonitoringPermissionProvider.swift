import SwiftPermissionsCore
#if os(macOS)
import IOKit.hid

/// Input Monitoring on macOS: receiving keyboard and other input events while other apps
/// are in front, for example with a `CGEventTap` or an `IOHIDManager`.
///
/// There's no usage description. ``request()`` shows the system alert that sends the user
/// to System Settings > Privacy & Security > Input Monitoring. Unlike Screen Recording
/// and Accessibility, macOS reports whether the user was asked, so all three statuses
/// survive relaunches.
public struct InputMonitoringPermissionProvider: PermissionProvider {
    public let permission = Permission.inputMonitoring

    private let access: any InputMonitoringAccess

    public init() {
        self.init(access: SystemInputMonitoringAccess())
    }

    init(access: any InputMonitoringAccess) {
        self.access = access
    }

    public func status() async -> PermissionStatus {
        Self.map(access.check())
    }

    public func request() async throws -> PermissionStatus {
        if access.request() { return .authorized }
        // The user was just asked, so "unknown" now means they haven't allowed it.
        let status = Self.map(access.check())
        return status == .notDetermined ? .denied : status
    }

    static func map(_ access: InputMonitoringAccessState) -> PermissionStatus {
        switch access {
        case .granted: .authorized
        case .denied: .denied
        case .unknown: .notDetermined
        }
    }
}

/// `IOHIDAccessType`, as a Swift enum.
enum InputMonitoringAccessState: Sendable {
    case granted, denied, unknown
}

/// The IOKit calls, behind a protocol so tests never touch TCC.
protocol InputMonitoringAccess: Sendable {
    /// `IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)`. Never prompts.
    func check() -> InputMonitoringAccessState
    /// `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)`: prompts if the user wasn't asked yet.
    func request() -> Bool
}

struct SystemInputMonitoringAccess: InputMonitoringAccess {
    func check() -> InputMonitoringAccessState {
        let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        if access == kIOHIDAccessTypeGranted { return .granted }
        if access == kIOHIDAccessTypeDenied { return .denied }
        return .unknown
    }

    func request() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }
}

public extension PermissionRegistration {
    /// Input Monitoring (macOS). No usage description; the user grants it in System Settings.
    static var inputMonitoring: PermissionRegistration {
        PermissionRegistration(InputMonitoringPermissionProvider())
    }
}
#endif
