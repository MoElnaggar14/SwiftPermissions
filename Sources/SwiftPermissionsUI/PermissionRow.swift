import SwiftPermissionsCore
import SwiftUI

/// A list row with the permission's icon, name, status and the next action.
///
/// Pass `onSelectMore` for permissions with a limited-access picker (photos, contacts).
/// While the status is ``PermissionStatus/limited`` the row then offers **Select More…**
/// instead of nothing. The framework products provide the pickers:
///
/// ```swift
/// PermissionRow(.photoLibrary, store: permissions) {
///     Task { await PhotoLibraryPermissionProvider.readWrite.presentLimitedLibraryPicker(from: controller) }
/// }
/// ```
public struct PermissionRow: View {
    private let permission: Permission
    private let onSelectMore: (() -> Void)?
    @ObservedObject private var store: PermissionStore
    // openURL rather than AppSettings.open, so the view also compiles in app extensions.
    @Environment(\.openURL) private var openURL

    /// - Parameter onSelectMore: Called when the user taps **Select More…**, shown while
    ///   access is limited and no upgrade prompt is available. Present the system's
    ///   limited-access picker from it. When `nil`, there's no such button.
    public init(_ permission: Permission, store: PermissionStore, onSelectMore: (() -> Void)? = nil) {
        self.permission = permission
        self.store = store
        self.onSelectMore = onSelectMore
    }

    private var status: PermissionStatus? { store[permission] }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: permission.systemImage)
                .frame(width: 28)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.displayName)
                if let status {
                    Label(status.title, systemImage: status.systemImage)
                        .font(.caption)
                        .foregroundStyle(status.tint)
                }
            }
            Spacer(minLength: 8)
            action
        }
        .accessibilityElement(children: .combine)
        .task { await store.load([permission]) }
    }

    @ViewBuilder private var action: some View {
        switch RowAction(
            status: status,
            isPending: store.isPending(permission),
            canRequest: store.canRequest(permission),
            hasSettingsURL: AppSettings.url(for: permission) != nil,
            canSelectMore: onSelectMore != nil
        ) {
        case .progress:
            ProgressView()
        case .request(let upgrade):
            Button(upgrade ? "Allow More" : "Allow") {
                Task { await store.request(permission) }
            }
            .buttonStyle(.borderedProminent)
        case .selectMore:
            if let onSelectMore {
                Button("Select More…", action: onSelectMore)
                    .buttonStyle(.bordered)
            }
        case .openSettings:
            if let settings = AppSettings.url(for: permission) {
                Button("Settings") {
                    openURL(settings)
                }
                .buttonStyle(.bordered)
            }
        case .nothing:
            EmptyView()
        }
    }
}

/// Which button a ``PermissionRow`` shows. Kept separate from the view so the decision
/// can be unit tested.
enum RowAction: Equatable {
    /// A request is in flight.
    case progress
    /// Show the system prompt. `upgrade` is `true` when something is already granted.
    case request(upgrade: Bool)
    /// Access is limited: show the app's limited-access picker.
    case selectMore
    /// Only Settings can change the status.
    case openSettings
    /// Nothing to offer: not loaded yet, granted, restricted or unavailable.
    case nothing

    init(status: PermissionStatus?, isPending: Bool, canRequest: Bool, hasSettingsURL: Bool, canSelectMore: Bool) {
        guard !isPending else {
            self = .progress
            return
        }
        guard let status else {
            self = .nothing
            return
        }
        if canRequest {
            self = .request(upgrade: status != .notDetermined)
        } else if status == .limited && canSelectMore {
            self = .selectMore
        } else if status.requiresSettings && hasSettingsURL {
            self = .openSettings
        } else {
            self = .nothing
        }
    }
}
