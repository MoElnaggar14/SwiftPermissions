import SwiftPermissionsCore
#if os(iOS) || os(macOS) || os(watchOS) || os(visionOS)
@preconcurrency import Contacts

/// Address book access.
public struct ContactsPermissionProvider: PermissionProvider {
    public let permission = Permission.contacts
    public let requiredUsageDescriptionKeys = ["NSContactsUsageDescription"]

    public init() {}

    public func status() async -> PermissionStatus {
        Self.map(CNContactStore.authorizationStatus(for: .contacts))
    }

    public func request() async throws -> PermissionStatus {
        // Declining surfaces as a thrown CNError ("access denied"), not `false`.
        // The resulting status is what matters, so read it back either way.
        _ = try? await CNContactStore().requestAccess(for: .contacts)
        return await status()
    }

    static func map(_ status: CNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        case .authorized: return .authorized
        default:
            // `.limited` (iOS 18) — compared by raw value so older SDK deployment targets compile.
            return status.rawValue == 4 ? .limited(.selectedItems) : .denied
        }
    }

    /// Why ``map(_:)`` reports `.limited`, or `nil` when it doesn't. 4.0 puts it in the status.
    static func mapLimitation(_ status: CNAuthorizationStatus) -> Limitation? {
        map(status).isLimited ? .selectedItems : nil
    }
}

public extension PermissionRegistration {
    /// Contacts. Needs `NSContactsUsageDescription`.
    static var contacts: PermissionRegistration { PermissionRegistration(ContactsPermissionProvider()) }
}

#if os(iOS) && !targetEnvironment(macCatalyst)
import ContactsUI
import SwiftUI

@available(iOS 18.0, *)
public extension View {
    /// Presents the system picker where people with ``PermissionStatus/limited`` contacts
    /// access can share more contacts with your app.
    ///
    /// Drive it from the "Select More…" action of a `PermissionRow` or `PermissionPrompt`:
    ///
    /// ```swift
    /// @State private var pickingContacts = false
    ///
    /// PermissionRow(.contacts, store: permissions, onSelectMore: { pickingContacts = true })
    ///     .limitedContactsPicker(isPresented: $pickingContacts)
    /// ```
    ///
    /// The status stays `.limited`; only the selection changes. iOS only (not Mac Catalyst).
    ///
    /// - Parameters:
    ///   - isPresented: Whether the picker is showing. Reset to `false` when it closes.
    ///   - onSelection: Called with the identifiers of the contacts the user newly shared.
    ///     Contacts the user removed aren't listed.
    @MainActor
    func limitedContactsPicker(
        isPresented: Binding<Bool>,
        onSelection: @escaping ([String]) -> Void = { _ in }
    ) -> some View {
        contactAccessPicker(isPresented: isPresented, completionHandler: onSelection)
    }
}
#endif
#endif
