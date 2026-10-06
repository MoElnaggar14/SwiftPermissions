/// How a multi-permission flow ended: every step done, or paused by the user.
///
/// `PermissionFlow` in `SwiftPermissionsUI` hands it to `onFinish`, and
/// ``PermissionFlowState/result`` produces it when you drive the flow yourself.
public struct PermissionFlowResult: Sendable, Equatable {
    /// Why the flow ended.
    public enum Reason: Sendable, Equatable {
        /// Every step has an outcome.
        case completed
        /// The user tapped **Not Now** on this required step. The flow starts from it next time.
        case paused(at: Permission)
    }

    /// Why the flow ended.
    public let reason: Reason
    /// The last known status of every step that has one.
    public let statuses: [Permission: PermissionStatus]

    public init(reason: Reason, statuses: [Permission: PermissionStatus]) {
        self.reason = reason
        self.statuses = statuses
    }

    /// Whether every step has an outcome.
    public var isCompleted: Bool { reason == .completed }
}
