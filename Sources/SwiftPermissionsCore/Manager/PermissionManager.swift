import Foundation

/// The default ``PermissionManaging`` implementation.
///
/// - Uses a ``PermissionProviderRegistry`` to talk to the system, so it never knows
///   about individual frameworks.
/// - Coalesces concurrent requests for the same permission into one system prompt.
/// - Checks the Info.plist usage descriptions before prompting, and throws
///   ``PermissionError/missingUsageDescription(_:keys:)`` instead of letting the system
///   terminate the app.
/// - Remembers the last status it saw for each permission and publishes changes through
///   ``updates(for:)`` and ``changes()``.
///
/// Statuses can change outside the app (in Settings). Call ``refresh()`` when the app
/// becomes active. `PermissionStore` in SwiftPermissionsUI does this for you.
///
/// ```swift
/// import SwiftPermissionsCamera
///
/// let permissions = PermissionManager(permissions: [.camera])
/// switch try await permissions.request(.camera) {
/// case .authorized: startCapture()
/// case .denied: showSettingsHint()
/// default: break
/// }
/// ```
public actor PermissionManager: PermissionManaging {
    public nonisolated let registry: PermissionProviderRegistry
    private let usageDescriptions: any UsageDescriptionSource
    private let validatesUsageDescriptions: Bool

    private var lastKnown: [Permission: PermissionStatus] = [:]
    private var inFlight: [Permission: (id: UUID, task: Task<PermissionStatus, any Error>)] = [:]
    private nonisolated let broadcaster = ChangeBroadcaster()

    /// A manager for the permissions your app uses.
    ///
    /// Each framework is its own product that adds a registration, e.g. `.camera` from
    /// `SwiftPermissionsCamera`. Requesting a permission that isn't registered throws
    /// ``PermissionError/providerNotRegistered(_:)`` naming the product to add.
    ///
    /// - Parameters:
    ///   - permissions: What to support, e.g. `[.camera, .photoLibrary, .notifications]`.
    ///   - usageDescriptions: Where to look up `NS…UsageDescription` keys. Defaults to the main bundle.
    ///   - validatesUsageDescriptions: Whether to check usage descriptions before prompting.
    public init(
        permissions: [PermissionRegistration],
        usageDescriptions: any UsageDescriptionSource = InfoPlist.main,
        validatesUsageDescriptions: Bool = true
    ) {
        self.init(
            registry: PermissionProviderRegistry(registering: permissions),
            usageDescriptions: usageDescriptions,
            validatesUsageDescriptions: validatesUsageDescriptions
        )
    }

    /// - Parameters:
    ///   - registry: The providers to use. Defaults to notifications only; prefer
    ///     ``init(permissions:usageDescriptions:validatesUsageDescriptions:)``.
    ///   - usageDescriptions: Where to look up `NS…UsageDescription` keys. Defaults to the main bundle.
    ///   - validatesUsageDescriptions: Whether to check usage descriptions before prompting.
    public init(
        registry: PermissionProviderRegistry = PermissionProviderRegistry(registering: [.notifications]),
        usageDescriptions: any UsageDescriptionSource = InfoPlist.main,
        validatesUsageDescriptions: Bool = true
    ) {
        self.registry = registry
        self.usageDescriptions = usageDescriptions
        self.validatesUsageDescriptions = validatesUsageDescriptions
    }

    deinit {
        broadcaster.finishAll()
    }

    // MARK: - PermissionStatusReading

    public func status(of permission: Permission) async -> PermissionStatus {
        let status = await currentStatus(of: permission)
        publish(status, for: permission)
        return status
    }

    private func currentStatus(of permission: Permission) async -> PermissionStatus {
        guard let provider = registry.provider(for: permission) else { return .unavailable }
        return await provider.status()
    }

    // MARK: - PermissionRequesting

    public func request(_ permission: Permission) async throws(PermissionError) -> PermissionStatus {
        let pending: (id: UUID, task: Task<PermissionStatus, any Error>)
        if let current = inFlight[permission] {
            pending = current
        } else {
            pending = try makeRequestTask(for: permission)
        }
        // Only the request that's still current may clear the slot: a caller
        // resuming late must not remove a newer request started meanwhile.
        func finish() {
            if inFlight[permission]?.id == pending.id { inFlight[permission] = nil }
        }
        let status: PermissionStatus
        do {
            // A cancelled caller stops waiting; the prompt stays up for the others.
            status = try await awaitValue(of: pending.task)
        } catch is CancellationError {
            // The prompt is still running, so keep it in flight: a new request joins
            // it instead of stacking a second prompt.
            throw .cancelled(permission)
        } catch let error as PermissionError {
            finish()
            throw error
        } catch {
            finish()
            throw .requestFailed(permission, reason: String(describing: error))
        }
        finish()
        publish(status, for: permission)
        return status
    }

    private func makeRequestTask(
        for permission: Permission
    ) throws(PermissionError) -> (id: UUID, task: Task<PermissionStatus, any Error>) {
        guard let provider = registry.provider(for: permission) else {
            throw .providerNotRegistered(permission)
        }
        let missing = validatesUsageDescriptions ? missingKeys(for: provider) : []
        let task = Task<PermissionStatus, any Error> {
            let current = await provider.status()
            guard provider.canRequest(from: current) else { return current }
            // Only a prompt needs the usage description; reading a status never does.
            guard missing.isEmpty else { throw PermissionError.missingUsageDescription(permission, keys: missing) }
            return try await provider.request()
        }
        let pending = (id: UUID(), task: task)
        inFlight[permission] = pending
        return pending
    }

    // MARK: - PermissionObserving

    public nonisolated func updates(for permission: Permission) -> AsyncStream<PermissionStatus> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: PermissionStatus.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let id = broadcaster.subscribe(
            to: permission,
            send: { continuation.yield($0.status) },
            finish: { continuation.finish() }
        )
        continuation.onTermination = { [broadcaster] _ in broadcaster.unsubscribe(id) }
        Task { await self.deliverCurrentStatus(of: permission, to: id) }
        return stream
    }

    public nonisolated func changes() -> AsyncStream<PermissionChange> {
        let (stream, continuation) = AsyncStream.makeStream(of: PermissionChange.self)
        let id = broadcaster.subscribe(
            send: { continuation.yield($0) },
            finish: { continuation.finish() }
        )
        continuation.onTermination = { [broadcaster] _ in broadcaster.unsubscribe(id) }
        return stream
    }

    // MARK: - Refresh & diagnostics

    /// Re-reads every permission that has been read, requested or observed, and
    /// publishes the ones that changed (for example after the user visited Settings).
    public func refresh() async {
        let tracked = Set(lastKnown.keys).union(broadcaster.observedPermissions)
        for permission in tracked {
            _ = await status(of: permission)
        }
    }

    /// Usage-description keys missing from the Info.plist, per permission.
    ///
    /// Call this from a unit test or at launch in debug builds to catch a missing key
    /// before a reviewer (or a crash) does.
    public nonisolated func missingUsageDescriptions(
        for permissions: some Sequence<Permission>
    ) -> [Permission: [String]] {
        var result: [Permission: [String]] = [:]
        for permission in permissions {
            guard let provider = registry.provider(for: permission) else { continue }
            let missing = missingKeys(for: provider)
            if !missing.isEmpty { result[permission] = missing }
        }
        return result
    }

    // MARK: - Private

    private nonisolated func missingKeys(for provider: any PermissionProvider) -> [String] {
        provider.requiredUsageDescriptionKeys.filter { usageDescriptions.usageDescription(forKey: $0) == nil }
    }

    private func publish(_ status: PermissionStatus, for permission: Permission) {
        guard lastKnown[permission] != status else { return }
        lastKnown[permission] = status
        broadcaster.send(PermissionChange(permission: permission, status: status))
    }

    /// Gives a new subscriber the current status exactly once: either through
    /// the broadcast (if the status changed) or directly, unless it already
    /// received a value in the meantime.
    private func deliverCurrentStatus(of permission: Permission, to subscriber: UUID) async {
        let current = await currentStatus(of: permission)
        publish(current, for: permission)
        broadcaster.sendIfUndelivered(PermissionChange(permission: permission, status: current), to: subscriber)
    }
}
