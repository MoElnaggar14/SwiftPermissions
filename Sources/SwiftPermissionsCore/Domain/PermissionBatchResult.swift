/// A status change observed by a ``PermissionManager``.
public struct PermissionChange: Sendable, Equatable {
    public let permission: Permission
    public let status: PermissionStatus

    public init(permission: Permission, status: PermissionStatus) {
        self.permission = permission
        self.status = status
    }
}

/// The outcome of requesting several permissions in sequence.
public struct PermissionBatchResult: Sendable, Equatable {
    /// Final status for every permission that could be requested.
    public let statuses: [Permission: PermissionStatus]
    /// Permissions that couldn't be requested, and why.
    public let failures: [Permission: PermissionError]

    public init(statuses: [Permission: PermissionStatus] = [:], failures: [Permission: PermissionError] = [:]) {
        self.statuses = statuses
        self.failures = failures
    }

    /// `true` when every requested permission ended up granted.
    public var allGranted: Bool {
        failures.isEmpty && statuses.values.allSatisfy(\.isGranted)
    }

    /// Permissions the user declined or that are restricted.
    public var notGranted: Set<Permission> {
        Set(statuses.filter { !$0.value.isGranted }.keys).union(failures.keys)
    }
}
