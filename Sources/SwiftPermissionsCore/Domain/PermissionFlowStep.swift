/// One step of a permission flow: a permission and the priming copy shown before its
/// system prompt.
///
/// ```swift
/// let steps: [PermissionFlowStep] = [
///     .init(.notifications, title: "Stay in the loop", message: "Get a ping when your order ships."),
///     .init(.photoLibrary, title: "Share your receipts", message: "Attach photos of receipts.", optional: true)
/// ]
/// ```
public struct PermissionFlowStep: Sendable, Equatable, Identifiable {
    public let permission: Permission
    /// The heading of the priming screen.
    public let title: String
    /// Why the app needs the permission, shown above the actions.
    public let message: String?
    /// Whether **Not Now** moves on to the next step. On a required step, **Not Now**
    /// pauses the flow instead, and the flow starts from that step next time.
    public let isOptional: Bool

    public var id: Permission { permission }

    public init(_ permission: Permission, title: String, message: String? = nil, optional: Bool = false) {
        self.permission = permission
        self.title = title
        self.message = message
        self.isOptional = optional
    }
}

/// How a step of a permission flow ended.
public enum PermissionFlowStepOutcome: Sendable, Equatable, Codable {
    /// The permission couldn't show a prompt when the flow reached it: it was already
    /// decided, restricted or unavailable. No priming screen was shown.
    case skipped(PermissionStatus)
    /// The user went through the system prompt and ended with this status.
    case answered(PermissionStatus)
    /// The user tapped **Not Now** on an optional step. The system prompt wasn't spent.
    case deferred(PermissionStatus)
    /// The request failed, for example because of a missing usage description.
    case failed

    /// The permission's status when the step ended, if known.
    public var status: PermissionStatus? {
        switch self {
        case let .skipped(status), let .answered(status), let .deferred(status): status
        case .failed: nil
        }
    }
}
