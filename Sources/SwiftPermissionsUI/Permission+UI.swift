import SwiftPermissionsCore
import SwiftUI

public extension Permission {
    /// An SF Symbol name representing the permission.
    var systemImage: String {
        switch self {
        case .camera: "camera.fill"
        case .microphone: "mic.fill"
        case .photoLibrary, .photoLibraryAddOnly: "photo.on.rectangle"
        case .contacts: "person.crop.circle.fill"
        case .calendar, .calendarWriteOnly: "calendar"
        case .reminders: "checklist"
        case .locationWhenInUse, .locationAlways: "location.fill"
        case .notifications: "bell.badge.fill"
        case .motion: "figure.walk"
        case .tracking: "hand.raised.fill"
        case .bluetooth: "antenna.radiowaves.left.and.right"
        case .speechRecognition: "waveform"
        case .mediaLibrary: "music.note"
        case .siri: "mic.circle.fill"
        case .biometrics: "faceid"
        case .health: "heart.fill"
        case .alarms: "alarm.fill"
        case .localNetwork: "network"
        default: "lock.shield.fill"
        }
    }
}

public extension PermissionStatus {
    /// A short English label, e.g. "Allowed".
    var title: String {
        switch self {
        case .notDetermined: "Not Asked"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .authorized: "Allowed"
        case .limited: "Limited"
        case .provisional: "Provisional"
        case .unavailable: "Unavailable"
        }
    }

    var systemImage: String {
        switch self {
        case .notDetermined: "questionmark.circle"
        case .denied: "xmark.circle.fill"
        case .restricted: "lock.circle.fill"
        case .authorized: "checkmark.circle.fill"
        case .limited, .provisional: "checkmark.circle"
        case .unavailable: "slash.circle"
        }
    }

    var tint: Color {
        switch self {
        case .notDetermined, .unavailable: .gray
        case .denied: .red
        case .restricted: .orange
        case .authorized: .green
        case .limited, .provisional: .yellow
        }
    }
}
