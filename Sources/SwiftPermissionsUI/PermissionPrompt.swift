import SwiftPermissionsCore
import SwiftUI

/// Explains why a permission is needed and offers the right next step for its status:
/// ask (not determined), open Settings (denied), or nothing the user can do (restricted,
/// unavailable).
///
/// Show it before the system prompt as a "pre-permission" screen. The system prompt can
/// only be shown once, so asking when the user already understands the value is what
/// moves acceptance rates.
///
/// Pass `onDefer` to also offer **Not Now**, so users can decline without spending the
/// system prompt. The package stores nothing: your app decides when to ask again.
///
/// ```swift
/// @AppStorage("cameraDeferredAt") private var deferredAt: Double = 0
///
/// PermissionPrompt(.camera, message: "Scan receipts.", store: permissions) {
///     deferredAt = Date().timeIntervalSince1970   // ask again in a week, say
/// }
/// ```
///
/// Pass `onSelectMore` for permissions with a limited-access picker (photos, contacts):
/// while access is ``PermissionStatus/limited`` the prompt offers **Select More…** instead
/// of **Open Settings**. The framework products provide the pickers.
public struct PermissionPrompt: View {
    private let permission: Permission
    private let message: String?
    private let onDefer: (() -> Void)?
    private let onSelectMore: (() -> Void)?
    @ObservedObject private var store: PermissionStore
    // openURL rather than AppSettings.open, so the view also compiles in app extensions.
    @Environment(\.openURL) private var openURL

    /// - Parameters:
    ///   - message: Why your app needs this permission. Shown while it can still be requested.
    ///   - onDefer: Called when the user taps **Not Now**. When `nil`, there's no such button.
    ///     The button only appears while a prompt can still be shown.
    ///   - onSelectMore: Called when the user taps **Select More…**, shown instead of
    ///     **Open Settings** while access is limited. Present the system's limited-access
    ///     picker from it. When `nil`, limited access offers **Open Settings**.
    public init(
        _ permission: Permission,
        message: String? = nil,
        store: PermissionStore,
        onDefer: (() -> Void)? = nil,
        onSelectMore: (() -> Void)? = nil
    ) {
        self.permission = permission
        self.message = message
        self.store = store
        self.onDefer = onDefer
        self.onSelectMore = onSelectMore
    }

    private var status: PermissionStatus { store[permission] ?? .notDetermined }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: permission.systemImage)
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(permission.displayName)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            action
        }
        .padding()
        .accessibilityElement(children: .contain)
        .task { await store.load([permission]) }
        .refreshesPermissions(store)
    }

    private var detail: String {
        switch status {
        case .notDetermined:
            message ?? "Allow access to \(permission.displayName) to use this feature."
        case .denied:
            "Access to \(permission.displayName) is turned off. You can turn it on in Settings."
        case .restricted:
            "Access to \(permission.displayName) is restricted on this device."
        case .unavailable:
            "\(permission.displayName) isn't available on this device."
        case .authorized, .limited, .provisional:
            "Access to \(permission.displayName) is allowed."
        }
    }

    private var actions: PromptActions {
        PromptActions(
            status: status,
            canRequest: store.canRequest(permission),
            hasSettingsURL: AppSettings.url(for: permission) != nil,
            canDefer: onDefer != nil,
            canSelectMore: onSelectMore != nil
        )
    }

    @ViewBuilder private var action: some View {
        let decision = actions
        switch decision.primary {
        case .request:
            Button("Continue") {
                Task { await store.request(permission) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isPending(permission))
        case .selectMore:
            if let onSelectMore {
                Button("Select More…", action: onSelectMore)
                    .buttonStyle(.bordered)
            }
        case .openSettings:
            if let settings = AppSettings.url(for: permission) {
                Button("Open Settings") {
                    openURL(settings)
                }
                .buttonStyle(.bordered)
            }
        case .nothing:
            EmptyView()
        }
        if decision.offersDefer, let onDefer {
            Button("Not Now", action: onDefer)
                .disabled(store.isPending(permission))
        }
    }
}

/// Which buttons a ``PermissionPrompt`` shows. Kept separate from the view so the
/// decision can be unit tested.
struct PromptActions: Equatable {
    enum Primary: Equatable {
        /// Show the system prompt (or the upgrade prompt).
        case request
        /// Access is limited: show the app's limited-access picker.
        case selectMore
        /// Only Settings can change the status.
        case openSettings
        /// Nothing the user can do: restricted, unavailable, or already granted.
        case nothing
    }

    let primary: Primary
    /// Whether to offer **Not Now** next to the primary action.
    let offersDefer: Bool

    init(
        status: PermissionStatus,
        canRequest: Bool,
        hasSettingsURL: Bool,
        canDefer: Bool,
        canSelectMore: Bool = false
    ) {
        if canRequest {
            primary = .request
        } else if status == .limited && canSelectMore {
            primary = .selectMore
        } else if (status.requiresSettings || status == .limited) && hasSettingsURL {
            primary = .openSettings
        } else {
            primary = .nothing
        }
        // Deferring only makes sense while the prompt hasn't been spent.
        offersDefer = canDefer && primary == .request
    }
}
