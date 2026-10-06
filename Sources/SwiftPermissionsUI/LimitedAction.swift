import SwiftPermissionsCore

/// What a limited grant offers once no prompt can appear. The one place that decides it
/// for ``PermissionRow``, ``PermissionPrompt`` and ``PermissionFlow``.
enum LimitedAction: Equatable {
    /// Show the app's limited-access picker (selected photos or contacts).
    case selectMore
    /// Only Settings can widen access.
    case openSettings
    /// Nothing the user can do from here.
    case nothing

    init(_ limitation: Limitation, canSelectMore: Bool, hasSettingsURL: Bool) {
        switch limitation {
        case .selectedItems where canSelectMore:
            self = .selectMore
        case .selectedItems, .whenInUse, .writeOnly:
            self = hasSettingsURL ? .openSettings : .nothing
        case .partial:
            // Health has no Settings pane for the app, and a new request only covers
            // types that weren't asked for yet.
            self = .nothing
        }
    }
}

extension PermissionStatus {
    /// The reason for a `.limited` status of `permission`, or `nil` for any other status.
    ///
    /// 3.x statuses don't carry the reason, so it comes from what the built-in provider
    /// reports. In 4.0 it's the status's own payload.
    func limitation(for permission: Permission) -> Limitation? {
        isLimited ? Limitation.reported(for: permission) : nil
    }
}
