import SwiftPermissionsCore
import SwiftUI

/// A list row with the permission's icon, name, status and the next action.
///
/// Pass `onSelectMore` for permissions with a limited-access picker (photos, contacts).
/// While only selected items are shared (``Limitation/selectedItems``) the row then offers
/// **Select More…** instead of **Settings**. The framework products provide the pickers:
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
    ///   only selected photos or contacts are shared and no upgrade prompt is available.
    ///   Present the system's limited-access picker from it. When `nil`, the row offers
    ///   **Settings** instead.
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
            canSelectMore: onSelectMore != nil,
            limitation: status?.limitation(for: permission)
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
    /// Only selected items are shared: show the app's limited-access picker.
    case selectMore
    /// Only Settings can change the status, or widen a limited grant.
    case openSettings
    /// Nothing to offer: not loaded yet, granted, restricted or unavailable.
    case nothing

    /// - Parameter limitation: Why access is limited, when `status` is `.limited`.
    ///   `nil` reads as ``Limitation/partial``.
    init(
        status: PermissionStatus?,
        isPending: Bool,
        canRequest: Bool,
        hasSettingsURL: Bool,
        canSelectMore: Bool,
        limitation: Limitation? = nil
    ) {
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
        } else if status.isLimited {
            switch LimitedAction(limitation ?? .partial, canSelectMore: canSelectMore, hasSettingsURL: hasSettingsURL) {
            case .selectMore: self = .selectMore
            case .openSettings: self = .openSettings
            case .nothing: self = .nothing
            }
        } else if status.requiresSettings && hasSettingsURL {
            self = .openSettings
        } else {
            self = .nothing
        }
    }
}
