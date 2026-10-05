/// The set of ``PermissionProvider``s a ``PermissionManager`` can use, keyed by permission.
public struct PermissionProviderRegistry: Sendable {
    private var providers: [Permission: any PermissionProvider]

    public init(_ providers: [any PermissionProvider] = []) {
        self.providers = [:]
        providers.forEach { register($0) }
    }

    /// Adds `provider`, replacing any provider already registered for the same permission.
    public mutating func register(_ provider: any PermissionProvider) {
        providers[provider.permission] = provider
    }

    /// A copy of the registry with `provider` added.
    public func registering(_ provider: any PermissionProvider) -> Self {
        var copy = self
        copy.register(provider)
        return copy
    }

    public func provider(for permission: Permission) -> (any PermissionProvider)? {
        providers[permission]
    }

    /// Every permission with a registered provider.
    public var permissions: Set<Permission> { Set(providers.keys) }
}
