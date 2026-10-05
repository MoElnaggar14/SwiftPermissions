import SwiftPermissionsCore
import SwiftUI

/// A list row with the permission's icon, name, status and the next action.
public struct PermissionRow: View {
    private let permission: Permission
    @ObservedObject private var store: PermissionStore
    // openURL rather than AppSettings.open, so the view also compiles in app extensions.
    @Environment(\.openURL) private var openURL

    public init(_ permission: Permission, store: PermissionStore) {
        self.permission = permission
        self.store = store
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
        if store.isPending(permission) {
            ProgressView()
        } else if let status, store.canRequest(permission) {
            Button(status == .notDetermined ? "Allow" : "Allow More") {
                Task { await store.request(permission) }
            }
            .buttonStyle(.borderedProminent)
        } else if let status, status.requiresSettings, let settings = AppSettings.url(for: permission) {
            Button("Settings") {
                openURL(settings)
            }
            .buttonStyle(.bordered)
        }
    }
}
