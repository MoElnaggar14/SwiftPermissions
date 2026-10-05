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

    /// Whether a prompt can still be shown from `status`. Defaults to
    /// `status == .notDetermined`. Providers that support an upgrade prompt
    /// (when-in-use → always location, write-only → full calendar, provisional
    /// → full notifications) return `true` for the partial status too.
    func canRequest(from status: PermissionStatus) -> Bool

    /// Shows the system prompt and returns the resulting status.
    ///
    /// Only called when ``canRequest(from:)`` is `true` for the current status.
    /// A user declining should be reported as a status (usually `.denied`),
    /// not thrown.
    func request() async throws -> PermissionStatus
}

public extension PermissionProvider {
    var requiredUsageDescriptionKeys: [String] { [] }

    func canRequest(from status: PermissionStatus) -> Bool {
        status == .notDetermined
    }
}
