import SwiftPermissionsCore
#if os(macOS)
import ApplicationServices
import Foundation

/// Accessibility on macOS: observing and controlling other apps through the Accessibility API.
///
/// There's no usage description. ``request()`` shows the system alert that sends the user
/// to System Settings > Privacy & Security > Accessibility, and returns before they
/// decide. macOS only says whether the app is trusted, so the status is
/// ``PermissionStatus/notDetermined`` until this provider has asked in the current
/// launch, and ``PermissionStatus/denied`` after that, until the user turns it on.
public struct AccessibilityPermissionProvider: PermissionProvider {
    public let permission = Permission.accessibility

    private let trust: any AccessibilityTrust
    private let requested = RequestedFlag()

    public init() {
        self.init(trust: SystemAccessibilityTrust())
    }

    init(trust: any AccessibilityTrust) {
        self.trust = trust
    }

    public func status() async -> PermissionStatus {
        Self.map(trusted: trust.isTrusted(), requested: requested.isSet)
    }

    public func request() async throws -> PermissionStatus {
        let trusted = trust.promptForTrust()
        requested.set()
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
}
#endif
