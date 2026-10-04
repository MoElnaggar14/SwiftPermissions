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
/// let permissions = PermissionManager()
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
    private var inFlight: [Permission: Task<PermissionStatus, any Error>] = [:]
    private nonisolated let broadcaster = ChangeBroadcaster()

    /// - Parameters:
    ///   - registry: The providers to use. Defaults to every system permission available on this platform.
    ///   - usageDescriptions: Where to look up `NS…UsageDescription` keys. Defaults to the main bundle.
    ///   - validatesUsageDescriptions: Whether to check usage descriptions before prompting.
    public init(
        registry: PermissionProviderRegistry = .standard,
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
        guard let provider = registry.provider(for: permission) else { return .unavailable }
        let status = await provider.status()
        publish(status, for: permission)
        return status
    }

    // MARK: - PermissionRequesting

    public func request(_ permission: Permission) async throws(PermissionError) -> PermissionStatus {
        let task: Task<PermissionStatus, any Error>
        if let pending = inFlight[permission] {
            task = pending
        } else {
            task = try makeRequestTask(for: permission)
        }
        let status: PermissionStatus
        do {
            status = try await task.value
        } catch let error as PermissionError {
            inFlight[permission] = nil
            throw error
        } catch {
            inFlight[permission] = nil
            throw .requestFailed(permission, reason: String(describing: error))
        }
        inFlight[permission] = nil
        publish(status, for: permission)
        return status
    }

    private func makeRequestTask(
        for permission: Permission
    ) throws(PermissionError) -> Task<PermissionStatus, any Error> {
        guard let provider = registry.provider(for: permission) else {
            throw .providerNotRegistered(permission)
        }
        if validatesUsageDescriptions {
            let missing = missingKeys(for: provider)
            guard missing.isEmpty else { throw .missingUsageDescription(permission, keys: missing) }
        }
        let task = Task<PermissionStatus, any Error> {
            let current = await provider.status()
            guard current == .notDetermined else { return current }
            return try await provider.request()
        }
        inFlight[permission] = task
        return task
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
        Task { await self.yieldCurrentStatus(of: permission, to: continuation) }
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

    private func yieldCurrentStatus(
        of permission: Permission,
        to continuation: AsyncStream<PermissionStatus>.Continuation
    ) async {
        let previous = lastKnown[permission]
        let current = await status(of: permission)
        // `status(of:)` already broadcast the value if it changed; otherwise send it here
        // so a new observer always starts with the current status.
        if previous == current {
            continuation.yield(current)
        }
    }
}
