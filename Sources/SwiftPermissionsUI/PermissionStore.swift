import Combine
import SwiftPermissionsCore

/// Main-actor state for SwiftUI: the last known status of each permission, which
/// requests are on screen, and the last error.
///
/// Create one per app (or per feature) and pass it down. It stays in sync with every
/// change the underlying manager publishes, including requests made elsewhere.
///
/// ```swift
/// @StateObject private var permissions = PermissionStore()
///
/// var body: some View {
///     PermissionGate(.camera, store: permissions) {
///         CameraView()
///     }
/// }
/// ```
@MainActor
public final class PermissionStore: ObservableObject {
    /// Last known status per permission. A permission is absent until it's been loaded.
    @Published public private(set) var statuses: [Permission: PermissionStatus] = [:]
    /// Permissions whose system prompt is currently showing.
    @Published public private(set) var pending: Set<Permission> = []
    /// The most recent request failure, e.g. a missing usage description.
    @Published public var lastError: PermissionError?

    private let manager: any PermissionManaging
    nonisolated(unsafe) private var observation: Task<Void, Never>?

    public init(manager: any PermissionManaging = PermissionManager()) {
        self.manager = manager
        let changes = manager.changes()
        observation = Task { [weak self] in
            for await change in changes {
                self?.statuses[change.permission] = change.status
            }
        }
    }

    deinit {
        observation?.cancel()
    }

    public subscript(permission: Permission) -> PermissionStatus? {
        statuses[permission]
    }

    public func isGranted(_ permission: Permission) -> Bool {
        statuses[permission]?.isGranted ?? false
    }

    public func isPending(_ permission: Permission) -> Bool {
        pending.contains(permission)
    }

    /// Reads the current status of each permission without prompting.
    public func load(_ permissions: some Sequence<Permission>) async {
        for permission in permissions {
            statuses[permission] = await manager.status(of: permission)
        }
    }

    /// Re-reads every loaded permission. Call when the app becomes active; the views in
    /// this module do it automatically.
    public func refresh() async {
        await load(Array(statuses.keys))
    }

    /// Requests `permission`, showing the system prompt if needed.
    ///
    /// - Returns: The resulting status, or `nil` if the request failed (see ``lastError``).
    @discardableResult
    public func request(_ permission: Permission) async -> PermissionStatus? {
        pending.insert(permission)
        defer { pending.remove(permission) }
        do throws(PermissionError) {
            let status = try await manager.request(permission)
            statuses[permission] = status
            return status
        } catch {
            lastError = error
            return nil
        }
    }

    /// Requests each permission in order.
    @discardableResult
    public func request(_ permissions: [Permission]) async -> PermissionBatchResult {
        pending.formUnion(permissions)
        defer { pending.subtract(permissions) }
        let result = await manager.request(permissions)
        statuses.merge(result.statuses) { _, new in new }
        if let failure = result.failures.values.first {
            lastError = failure
        }
        return result
    }

    /// Sends the user to the place where they can change `permission`.
    public func openSettings(for permission: Permission? = nil) async {
        await AppSettings.open(for: permission)
    }
}
