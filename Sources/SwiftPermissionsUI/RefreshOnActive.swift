import SwiftPermissionsCore
import SwiftUI

/// Re-reads permission statuses when the scene becomes active, since the user may have
/// changed them in Settings while the app was in the background.
struct RefreshOnActive: ViewModifier {
    let store: PermissionStore
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await store.refresh() }
        }
    }
}

public extension View {
    /// Keeps `store` up to date when the user returns from Settings.
    func refreshesPermissions(_ store: PermissionStore) -> some View {
        modifier(RefreshOnActive(store: store))
    }
}
