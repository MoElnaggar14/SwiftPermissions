/// Reads the current status of permissions without ever prompting.
public protocol PermissionStatusReading: Sendable {
    func status(of permission: Permission) async -> PermissionStatus
}

/// Asks the user for permissions.
public protocol PermissionRequesting: Sendable {
    /// Shows the system prompt if the permission is ``PermissionStatus/notDetermined``,
    /// otherwise returns the current status without prompting.
    func request(_ permission: Permission) async throws(PermissionError) -> PermissionStatus
}

/// Streams permission status changes.
public protocol PermissionObserving: Sendable {
    /// Emits the current status first, then every change, until the stream is cancelled.
    func updates(for permission: Permission) -> AsyncStream<PermissionStatus>
    /// Emits every status change for every permission.
    func changes() -> AsyncStream<PermissionChange>
}

/// Everything a feature usually needs. Depend on the narrowest protocol that does the job.
public typealias PermissionManaging = PermissionStatusReading & PermissionRequesting & PermissionObserving

// MARK: - Conveniences

public extension PermissionStatusReading {
    func statuses(of permissions: some Sequence<Permission>) async -> [Permission: PermissionStatus] {
        var result: [Permission: PermissionStatus] = [:]
        for permission in permissions {
            result[permission] = await status(of: permission)
        }
        return result
    }

    func isGranted(_ permission: Permission) async -> Bool {
        await status(of: permission).isGranted
    }

    func areAllGranted(_ permissions: some Sequence<Permission>) async -> Bool {
        for permission in permissions {
            if await !status(of: permission).isGranted { return false }
        }
        return true
    }
}

public extension PermissionRequesting {
    /// Requests each permission in order. System prompts can't overlap, so this never
    /// shows more than one at a time. A failure doesn't stop the remaining requests.
    func request(_ permissions: some Sequence<Permission>) async -> PermissionBatchResult {
        var statuses: [Permission: PermissionStatus] = [:]
        var failures: [Permission: PermissionError] = [:]
        for permission in permissions {
            do throws(PermissionError) {
                statuses[permission] = try await request(permission)
            } catch {
                failures[permission] = error
            }
        }
        return PermissionBatchResult(statuses: statuses, failures: failures)
    }
}
