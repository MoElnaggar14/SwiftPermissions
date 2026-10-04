import SwiftPermissionsCore
import SwiftUI

/// Shows `granted` once the permission is granted, and `fallback` otherwise.
///
/// ```swift
/// PermissionGate(.camera, store: permissions) {
///     CameraPreview()
/// }
/// ```
///
/// By default the fallback is a ``PermissionPrompt``. Supply your own for a custom design:
///
/// ```swift
/// PermissionGate(.microphone, store: permissions) {
///     Recorder()
/// } fallback: { status in
///     MicrophoneOnboarding(status: status)
/// }
/// ```
public struct PermissionGate<Granted: View, Fallback: View>: View {
    private let permission: Permission
    @ObservedObject private var store: PermissionStore
    private let granted: () -> Granted
    private let fallback: (PermissionStatus) -> Fallback

    public init(
        _ permission: Permission,
        store: PermissionStore,
        @ViewBuilder granted: @escaping () -> Granted,
        @ViewBuilder fallback: @escaping (PermissionStatus) -> Fallback
    ) {
        self.permission = permission
        self.store = store
        self.granted = granted
        self.fallback = fallback
    }

    public var body: some View {
        Group {
            if let status = store[permission] {
                if status.isGranted {
                    granted()
                } else {
                    fallback(status)
                }
            } else {
                ProgressView()
            }
        }
        .task { await store.load([permission]) }
        .refreshesPermissions(store)
    }
}

public extension PermissionGate where Fallback == PermissionPrompt {
    /// A gate whose fallback is a ``PermissionPrompt`` with an optional explanation.
    init(
        _ permission: Permission,
        message: String? = nil,
        store: PermissionStore,
        @ViewBuilder granted: @escaping () -> Granted
    ) {
        self.init(permission, store: store, granted: granted) { _ in
            PermissionPrompt(permission, message: message, store: store)
        }
    }
}
