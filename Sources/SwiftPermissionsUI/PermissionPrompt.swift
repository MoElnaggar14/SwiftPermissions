import SwiftPermissionsCore
import SwiftUI

/// Explains why a permission is needed and offers the right next step for its status:
/// ask (not determined), open Settings (denied), or nothing the user can do (restricted,
/// unavailable).
///
/// Show it before the system prompt as a "pre-permission" screen. The system prompt can
/// only be shown once, so asking when the user already understands the value is what
/// moves acceptance rates.
public struct PermissionPrompt: View {
    private let permission: Permission
    private let message: String?
    @ObservedObject private var store: PermissionStore

    /// - Parameter message: Why your app needs this permission. Shown while it can still be requested.
    public init(_ permission: Permission, message: String? = nil, store: PermissionStore) {
        self.permission = permission
        self.message = message
        self.store = store
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

    @ViewBuilder private var action: some View {
        if store.canRequest(permission) {
            Button("Continue") {
                Task { await store.request(permission) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isPending(permission))
        } else if status.requiresSettings || status == .limited, AppSettings.url(for: permission) != nil {
            Button("Open Settings") {
                Task { await store.openSettings(for: permission) }
            }
            .buttonStyle(.bordered)
        }
    }
}
