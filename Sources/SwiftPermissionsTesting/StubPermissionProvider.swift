import SwiftPermissionsCore

/// A scriptable ``PermissionProvider`` for unit tests and SwiftUI previews.
///
/// ```swift
/// let camera = StubPermissionProvider(.camera, status: .notDetermined, onRequest: .grant)
/// let manager = PermissionManager.stubbed(camera)
///
/// let status = try await manager.request(.camera)
/// XCTAssertEqual(status, .authorized)
/// XCTAssertEqual(await camera.requestCount, 1)
/// ```
public actor StubPermissionProvider: PermissionProvider {
    /// What happens when the system prompt would be shown.
    public enum RequestOutcome: Sendable {
        /// The user allows access (`.authorized`).
        case grant
        /// The user declines (`.denied`).
        case deny
        /// The prompt ends with a specific status.
        case status(PermissionStatus)
        /// The framework throws.
        case fail(any Error & Sendable)
    }

    public nonisolated let permission: Permission
    public nonisolated let requiredUsageDescriptionKeys: [String]

    public private(set) var currentStatus: PermissionStatus
    public private(set) var requestCount = 0
    public private(set) var statusReadCount = 0
    private var outcome: RequestOutcome
    private let requestDelayNanoseconds: UInt64

    /// - Parameters:
    ///   - requestDelay: Seconds the simulated prompt stays on screen. Useful for testing concurrency.
    public init(
        _ permission: Permission,
        status: PermissionStatus = .notDetermined,
        onRequest outcome: RequestOutcome = .grant,
        requiredUsageDescriptionKeys: [String] = [],
        requestDelay: Double = 0
    ) {
        self.permission = permission
        self.currentStatus = status
        self.outcome = outcome
        self.requiredUsageDescriptionKeys = requiredUsageDescriptionKeys
        self.requestDelayNanoseconds = UInt64(max(0, requestDelay) * 1_000_000_000)
    }

    public func status() async -> PermissionStatus {
        statusReadCount += 1
        return currentStatus
    }

    public func request() async throws -> PermissionStatus {
        requestCount += 1
        if requestDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: requestDelayNanoseconds)
        }
        switch outcome {
        case .grant: currentStatus = .authorized
        case .deny: currentStatus = .denied
        case let .status(status): currentStatus = status
        case let .fail(error): throw error
        }
        return currentStatus
    }

    /// Simulates the user changing the permission outside the app, e.g. in Settings.
    public func setStatus(_ status: PermissionStatus) {
        currentStatus = status
    }

    public func setOutcome(_ outcome: RequestOutcome) {
        self.outcome = outcome
    }
}
