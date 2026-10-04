/// Knows how to read and request one ``Permission`` from the system.
///
/// Providers are the extension point of the library (Strategy pattern): the manager
/// never switches over permission kinds, it looks up a provider. To support a new
/// permission, or to change how an existing one is requested, implement this protocol
/// and register it on a ``PermissionProviderRegistry``.
public protocol PermissionProvider: Sendable {
    var permission: Permission { get }

    /// Info.plist keys that must contain a non-empty usage description before the
    /// system prompt can be shown. All of them are required.
    var requiredUsageDescriptionKeys: [String] { get }

    /// The current status. Must never show UI.
    func status() async -> PermissionStatus

    /// Shows the system prompt and returns the resulting status.
    ///
    /// Only called when ``status()`` is ``PermissionStatus/notDetermined``.
    func request() async throws -> PermissionStatus
}

public extension PermissionProvider {
    var requiredUsageDescriptionKeys: [String] { [] }
}
