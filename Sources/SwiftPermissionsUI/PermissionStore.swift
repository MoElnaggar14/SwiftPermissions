import Combine
import SwiftPermissionsCore

/// Main-actor state for SwiftUI: the last known status of each permission, which
/// requests are on screen, and the last error.
///
/// Create one per app and pass it down: concurrent requests for the same permission
/// are merged into one prompt per manager. It stays in sync with every change the
/// underlying manager publishes, including requests made elsewhere.
///
/// ```swift
/// @StateObject private var permissions = PermissionStore(permissions: [.camera, .notifications])
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
    /// Permissions whose system prompt can still be shown, including upgrades from a
    /// partial status (see ``PermissionRequesting/canRequest(_:)``).
    @Published public private(set) var requestable: Set<Permission> = []
    /// The most recent request failure, e.g. a missing usage description.
    @Published public var lastError: PermissionError?

    private let manager: any PermissionManaging
    nonisolated(unsafe) private var observation: Task<Void, Never>?

    /// A store backed by a new ``PermissionManager`` for `permissions`.
    public convenience init(permissions: [PermissionRegistration]) {
        self.init(manager: PermissionManager(permissions: permissions))
    }

    public init(manager: any PermissionManaging = PermissionManager()) {
        self.manager = manager
        let changes = manager.changes()
        observation = Task { [weak self] in
            for await change in changes {
                await self?.record(change.status, for: change.permission)
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

    /// Whether requesting `permission` can show a prompt, including an upgrade
    /// (for example when-in-use → Always location).
    public func canRequest(_ permission: Permission) -> Bool {
        requestable.contains(permission)
    }

    private func record(_ status: PermissionStatus, for permission: Permission) async {
        statuses[permission] = status
        if await manager.canRequest(permission) {
            requestable.insert(permission)
        } else {
            requestable.remove(permission)
        }
    }

    /// Reads the current status of each permission without prompting.
    public func load(_ permissions: some Sequence<Permission>) async {
        for permission in permissions {
            await record(await manager.status(of: permission), for: permission)
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
            await record(status, for: permission)
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
        for (permission, status) in result.statuses {
            await record(status, for: permission)
        }
        if let failure = result.failures.values.first {
            lastError = failure
        }
        return result
    }

    /// Sends the user to the place where they can change `permission`. Unavailable in app
    /// extensions; the built-in views use SwiftUI's `openURL` instead.
    @available(iOSApplicationExtension, unavailable)
    @available(macCatalystApplicationExtension, unavailable)
    @available(tvOSApplicationExtension, unavailable)
    @available(visionOSApplicationExtension, unavailable)
    public func openSettings(for permission: Permission? = nil) async {
        await AppSettings.open(for: permission)
    }
}
