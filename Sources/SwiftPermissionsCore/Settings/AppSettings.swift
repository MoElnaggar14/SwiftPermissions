import Foundation
#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Opens the place where the user can change a permission they previously declined.
@MainActor
public enum AppSettings {
    /// Opens the app's page in Settings (iOS, tvOS, visionOS) or the matching
    /// Privacy & Security pane (macOS). Does nothing on watchOS.
    ///
    /// Unavailable in app extensions, which can't open Settings. In SwiftUI, prefer
    /// `openURL(AppSettings.url(for:))`, which works everywhere.
    ///
    /// - Returns: `true` if a settings URL was opened.
    @discardableResult
    @available(iOSApplicationExtension, unavailable)
    @available(macCatalystApplicationExtension, unavailable)
    @available(tvOSApplicationExtension, unavailable)
    @available(visionOSApplicationExtension, unavailable)
    public static func open(for permission: Permission? = nil) async -> Bool {
        guard let url = url(for: permission) else { return false }
        #if canImport(UIKit) && !os(watchOS)
        return await UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        return NSWorkspace.shared.open(url)
        #else
        return false
        #endif
    }

    /// The URL ``open(for:)`` would open, or `nil` on platforms without one.
    public static func url(for permission: Permission? = nil) -> URL? {
        #if canImport(UIKit) && !os(watchOS)
        #if os(iOS)
        if #available(iOS 16, *), permission == .notifications {
            return URL(string: UIApplication.openNotificationSettingsURLString)
        }
        #endif
        return URL(string: UIApplication.openSettingsURLString)
        #elseif os(macOS)
        if permission == .notifications {
            return URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
        }
        let base = "x-apple.systempreferences:com.apple.preference.security"
        guard let anchor = permission.flatMap(macOSPrivacyAnchor) else { return URL(string: base) }
        return URL(string: "\(base)?\(anchor)")
        #else
        return nil
        #endif
    }

    #if os(macOS)
    private static func macOSPrivacyAnchor(_ permission: Permission) -> String? {
        let anchors: [Permission: String] = [
            .camera: "Privacy_Camera",
            .microphone: "Privacy_Microphone",
            .photoLibrary: "Privacy_Photos",
            .photoLibraryAddOnly: "Privacy_Photos",
            .contacts: "Privacy_Contacts",
            .calendar: "Privacy_Calendars",
            .calendarWriteOnly: "Privacy_Calendars",
            .reminders: "Privacy_Reminders",
            .locationWhenInUse: "Privacy_LocationServices",
            .locationAlways: "Privacy_LocationServices",
            .speechRecognition: "Privacy_SpeechRecognition",
            .bluetooth: "Privacy_Bluetooth",
            .tracking: "Privacy_Advertising",
            .screenRecording: "Privacy_ScreenCapture",
            .accessibility: "Privacy_Accessibility",
            .inputMonitoring: "Privacy_ListenEvent"
        ]
        return anchors[permission]
    }
    #endif
}
