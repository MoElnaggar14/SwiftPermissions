import AppKit
import SwiftPermissions
import SwiftPermissionsAccessibility
import SwiftPermissionsInputMonitoring
import SwiftPermissionsLocalNetwork
import SwiftPermissionsScreenRecording
import SwiftUI

/// The macOS permissions, each with a row that requests it or opens System Settings.
///
/// Run it with `swift run --package-path Example/MacChecks`, or open the package in Xcode
/// and press ⌘R. macOS attributes the grants to the app that launched it (Terminal or
/// Xcode), so that's the entry to look for in System Settings → Privacy & Security.
@main
struct MacChecksApp: App {
    @StateObject private var store: PermissionStore

    init() {
        // Remembers that a request was made, so a declined request still reads Denied
        // after a relaunch instead of Not Determined.
        let history = UserDefaultsRequestHistory(keyPrefix: "MacChecks.")
        let manager = PermissionManager(permissions: [
            .screenRecording(history: history),
            .accessibility(history: history),
            .inputMonitoring,
            .localNetwork(history: history)
        ])
        _store = StateObject(wrappedValue: PermissionStore(manager: manager))
        // A SwiftPM executable starts as a background process; make it a regular app.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("SwiftPermissions Mac checks") {
            // PermissionsList refreshes the rows whenever the app becomes active.
            PermissionsList(
                [.screenRecording, .accessibility, .inputMonitoring, .localNetwork],
                footer: "Grant or deny in System Settings, then come back: the rows refresh. Quit and relaunch to check that a denial is remembered.",
                store: store
            )
            .frame(minWidth: 420, minHeight: 360)
        }
    }
}
