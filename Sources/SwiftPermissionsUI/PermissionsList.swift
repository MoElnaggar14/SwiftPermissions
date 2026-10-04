import SwiftPermissionsCore
import SwiftUI

/// A list of ``PermissionRow``s with an "Allow All" button, e.g. for onboarding or a
/// privacy settings screen. Embed it in your own navigation container.
public struct PermissionsList: View {
    private let permissions: [Permission]
    private let footer: String?
    @ObservedObject private var store: PermissionStore

    public init(_ permissions: [Permission], footer: String? = nil, store: PermissionStore) {
        self.permissions = permissions
        self.footer = footer
        self.store = store
    }

    private var requestable: [Permission] {
        permissions.filter { store[$0]?.canRequest == true }
    }

    public var body: some View {
        List {
            Section {
                ForEach(permissions, id: \.self) { permission in
                    PermissionRow(permission, store: store)
                }
            } footer: {
                if let footer { Text(footer) }
            }
            if !requestable.isEmpty {
                Section {
                    Button("Allow All") {
                        Task { await store.request(requestable) }
                    }
                    .disabled(!store.pending.isEmpty)
                }
            }
        }
        .refreshesPermissions(store)
    }
}
