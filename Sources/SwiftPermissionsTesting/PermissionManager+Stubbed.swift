import SwiftPermissionsCore

public extension PermissionManager {
    /// A real ``PermissionManager`` backed only by the given stubs, with usage-description
    /// validation turned off. Prefer this over mocking ``PermissionManaging``: your tests
    /// then exercise the real coalescing, caching and publishing logic.
    static func stubbed(_ providers: StubPermissionProvider...) -> PermissionManager {
        PermissionManager(
            registry: PermissionProviderRegistry(providers),
            usageDescriptions: InfoPlist([:]),
            validatesUsageDescriptions: false
        )
    }

    /// A manager where each permission starts in the given status, and requests resolve with `onRequest`.
    /// Handy for SwiftUI previews.
    static func stubbed(
        _ statuses: [Permission: PermissionStatus],
        onRequest outcome: StubPermissionProvider.RequestOutcome = .grant
    ) -> PermissionManager {
        PermissionManager(
            registry: PermissionProviderRegistry(
                statuses.map { StubPermissionProvider($0.key, status: $0.value, onRequest: outcome) }
            ),
            usageDescriptions: InfoPlist([:]),
            validatesUsageDescriptions: false
        )
    }
}
