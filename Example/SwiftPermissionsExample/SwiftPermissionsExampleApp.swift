import SwiftPermissions
import SwiftPermissionsBiometrics
import SwiftPermissionsBluetooth
import SwiftPermissionsCalendar
import SwiftPermissionsCamera
import SwiftPermissionsContacts
import SwiftPermissionsLocalNetwork
import SwiftPermissionsLocation
import SwiftPermissionsMotion
import SwiftPermissionsPhotos
import SwiftPermissionsSpeech
import SwiftPermissionsTracking
import SwiftUI

/// The composition root: one manager for the whole app, injected into the store and
/// the change log. A real app links and registers only the permissions it requests;
/// this demo registers every one that works without an extra entitlement (Siri and
/// HealthKit need capabilities, so they're left out).
@main
struct SwiftPermissionsExampleApp: App {
    private let manager: PermissionManager
    @StateObject private var store: PermissionStore

    init() {
        let manager = PermissionManager(permissions: ExamplePermissions.registrations)
        self.manager = manager
        _store = StateObject(wrappedValue: PermissionStore(manager: manager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(changes: manager)
                .environmentObject(store)
        }
    }
}

enum ExamplePermissions {
    /// The system has no API to read Local Network access, so the provider remembers
    /// the last result here. Without it, a relaunch reads Not Determined until the next request.
    static let history = UserDefaultsRequestHistory()

    static let registrations: [PermissionRegistration] = [
        .camera, .microphone, .photoLibrary, .photoLibraryAddOnly, .contacts,
        .calendar, .reminders, .locationWhenInUse, .locationAlways, .notifications,
        .bluetooth, .tracking, .motion, .speechRecognition, .biometrics,
        .localNetwork(history: history)
    ]

    static let all: [Permission] = [
        .camera, .microphone, .photoLibrary, .photoLibraryAddOnly, .contacts,
        .calendar, .reminders, .locationWhenInUse, .locationAlways, .notifications,
        .bluetooth, .tracking, .motion, .speechRecognition, .biometrics, .localNetwork
    ]
}
