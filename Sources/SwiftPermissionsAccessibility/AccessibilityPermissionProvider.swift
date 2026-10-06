import SwiftPermissionsCore
#if os(macOS)
import ApplicationServices
import Foundation

/// Accessibility on macOS: observing and controlling other apps through the Accessibility API.
///
/// There's no usage description. ``request()`` shows the system alert that sends the user
/// to System Settings > Privacy & Security > Accessibility, and returns before they
/// decide. macOS only says whether the app is trusted, so the status is
/// ``PermissionStatus/notDetermined`` until the provider's ``PermissionRequestHistory``
/// has a request on record, and ``PermissionStatus/denied`` after that, until the user
/// turns it on. The default history is in memory, so that's per launch; pass a
/// ``UserDefaultsRequestHistory`` to remember across launches.
public struct AccessibilityPermissionProvider: PermissionProvider {
    public let permission = Permission.accessibility

    private let trust: any AccessibilityTrust
    private let history: any PermissionRequestHistory

    /// - Parameter history: Remembers that the provider asked. Defaults to an in-memory
    ///   history that's lost when the app quits.
    public init(history: any PermissionRequestHistory = InMemoryRequestHistory()) {
        self.init(trust: SystemAccessibilityTrust(), history: history)
    }

    init(trust: any AccessibilityTrust, history: any PermissionRequestHistory = InMemoryRequestHistory()) {
        self.trust = trust
        self.history = history
    }

    public func status() async -> PermissionStatus {
        Self.map(trusted: trust.isTrusted(), requested: history.hasRequested(permission))
    }

    public func request() async throws -> PermissionStatus {
        let trusted = trust.promptForTrust()
        history.recordRequest(permission)
        return Self.map(trusted: trusted, requested: true)
    }

    static func map(trusted: Bool, requested: Bool) -> PermissionStatus {
        if trusted { return .authorized }
        return requested ? .denied : .notDetermined
    }
}

/// The ApplicationServices calls, behind a protocol so tests never touch TCC.
protocol AccessibilityTrust: Sendable {
    /// Whether the process is trusted. Never prompts.
    func isTrusted() -> Bool
    /// Shows the system alert if the process isn't trusted, and returns whether it is.
    func promptForTrust() -> Bool
}

struct SystemAccessibilityTrust: AccessibilityTrust {
    func isTrusted() -> Bool { AXIsProcessTrusted() }

    func promptForTrust() -> Bool {
        // The value of `kAXTrustedCheckOptionPrompt`. That constant is a mutable C global,
        // which Swift 6 strict concurrency won't let us read.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

public extension PermissionRegistration {
    /// Accessibility (macOS). No usage description; the user grants it in System Settings.
    static var accessibility: PermissionRegistration {
        PermissionRegistration(AccessibilityPermissionProvider())
    }

    /// Accessibility (macOS), remembering requests in `history`, for example a
    /// ``UserDefaultsRequestHistory`` so a declined request still reads `.denied` after a relaunch.
    static func accessibility(history: any PermissionRequestHistory) -> PermissionRegistration {
        PermissionRegistration(AccessibilityPermissionProvider(history: history))
    }
}
#endif
