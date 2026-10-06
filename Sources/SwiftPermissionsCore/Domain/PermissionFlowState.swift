/// The state machine behind a multi-permission onboarding flow: which step comes next,
/// which steps are skipped, and when the flow pauses or finishes.
///
/// It's a plain value with no UI. `PermissionFlow` in `SwiftPermissionsUI` renders it,
/// and you can drive it yourself, for example from a UIKit coordinator:
///
/// ```swift
/// var flow = PermissionFlowState(steps: steps, progress: savedProgress)
/// while let step = await flow.advance(using: permissions) {
///     // Show your priming screen for `step`, then on Continue:
///     await flow.requestCurrent(using: permissions)
///     // or on Not Now: flow.notNow(step.permission, status: .notDetermined)
/// }
/// savedProgress = flow.progress
/// ```
///
/// Each transition names the permission it's for and does nothing unless that's the
/// current step, so an answer that arrives late can't complete the wrong step.
public struct PermissionFlowState: Sendable, Equatable {
    /// Where the flow is.
    public enum Phase: Sendable, Equatable {
        /// The step waiting for the user (or to be checked and skipped).
        case step(PermissionFlowStep)
        /// The user tapped **Not Now** on this required step. The flow starts here next time.
        case paused(PermissionFlowStep)
        /// Every step has an outcome.
        case finished
    }

    /// The steps, in order. A permission that appears twice keeps its first step.
    public let steps: [PermissionFlowStep]
    /// The outcome of each finished step. Persist it to resume the flow next launch.
    public private(set) var progress: PermissionFlowProgress
    /// Whether the user paused the flow. Not part of ``progress``, so a flow restored
    /// from saved progress always resumes.
    public private(set) var isPaused = false

    /// - Parameter progress: Progress saved from an earlier run. Outcomes for permissions
    ///   that aren't in `steps` are kept but ignored.
    public init(steps: [PermissionFlowStep], progress: PermissionFlowProgress = PermissionFlowProgress()) {
        var seen = Set<Permission>()
        self.steps = steps.filter { seen.insert($0.permission).inserted }
        self.progress = progress
    }

    /// The first step without an outcome, or `nil` once every step has one.
    private var firstPendingStep: PermissionFlowStep? {
        steps.first { progress[$0.permission] == nil }
    }

    public var phase: Phase {
        guard let step = firstPendingStep else { return .finished }
        return isPaused ? .paused(step) : .step(step)
    }

    /// The step waiting for the user, or `nil` when the flow is paused or finished.
    public var currentStep: PermissionFlowStep? {
        guard case let .step(step) = phase else { return nil }
        return step
    }

    /// Whether every step has an outcome.
    public var isFinished: Bool { firstPendingStep == nil }

    /// Steps that don't have an outcome yet, in order.
    public var pendingSteps: [PermissionFlowStep] {
        steps.filter { progress[$0.permission] == nil }
    }

    /// The last known status of every step that has one.
    public var statuses: [Permission: PermissionStatus] {
        var result: [Permission: PermissionStatus] = [:]
        for step in steps {
            if let status = progress[step.permission]?.status {
                result[step.permission] = status
            }
        }
        return result
    }

    // MARK: Transitions

    private func isCurrent(_ permission: Permission) -> Bool {
        currentStep?.permission == permission
    }

    /// Checks the current step against the permission's status: when no prompt can
    /// appear (already decided, restricted or unavailable) the step is skipped.
    ///
    /// - Parameter canRequest: Whether a prompt can still appear, including an upgrade;
    ///   see ``PermissionRequesting/canRequest(_:)``.
    /// - Returns: Whether the step was skipped.
    @discardableResult
    public mutating func skipIfDecided(_ permission: Permission, status: PermissionStatus, canRequest: Bool) -> Bool {
        guard isCurrent(permission), !canRequest || status == .unavailable else { return false }
        progress.record(.skipped(status), for: permission)
        return true
    }

    /// Records the status the system prompt ended with, and moves on.
    public mutating func recordAnswer(_ permission: Permission, status: PermissionStatus) {
        guard isCurrent(permission) else { return }
        progress.record(.answered(status), for: permission)
    }

    /// Records that the request failed, and moves on.
    public mutating func recordFailure(_ permission: Permission) {
        guard isCurrent(permission) else { return }
        progress.record(.failed, for: permission)
    }

    /// The user tapped **Not Now**. An optional step is deferred and the flow moves on;
    /// a required step pauses the flow, which starts from it next time.
    ///
    /// - Parameter status: The permission's status, recorded for an optional step.
    public mutating func notNow(_ permission: Permission, status: PermissionStatus) {
        guard let step = currentStep, step.permission == permission else { return }
        if step.isOptional {
            progress.record(.deferred(status), for: permission)
        } else {
            isPaused = true
        }
    }

    /// Stops the flow without recording anything for the current step, for example when
    /// the user closes it. Resume it, or restore it from ``progress`` next launch.
    public mutating func pause() {
        guard !isFinished else { return }
        isPaused = true
    }

    /// Continues a paused flow at the step it stopped on.
    public mutating func resume() {
        isPaused = false
    }
}

// MARK: - Driving a manager

public extension PermissionFlowState {
    /// Skips every step that can't show a prompt, reading statuses from `permissions`
    /// without prompting, and returns the step to prime next.
    ///
    /// - Returns: The current step, or `nil` when the flow is paused, finished, or the
    ///   calling task was cancelled.
    @discardableResult
    mutating func advance(
        using permissions: some PermissionStatusReading & PermissionRequesting
    ) async -> PermissionFlowStep? {
        while let step = currentStep {
            let status = await permissions.status(of: step.permission)
            let canRequest = await permissions.canRequest(step.permission)
            if Task.isCancelled { return nil }
            if !skipIfDecided(step.permission, status: status, canRequest: canRequest) {
                return step
            }
        }
        return nil
    }

    /// Requests the current step's permission and records the answer.
    ///
    /// When the calling task is cancelled while the prompt is up, nothing is recorded, so
    /// the step is shown again when the flow resumes. Any other failure is recorded as
    /// ``PermissionFlowStepOutcome/failed`` and the flow moves on.
    ///
    /// - Returns: The resulting status, or `nil` if there was no current step or the
    ///   request failed.
    @discardableResult
    mutating func requestCurrent(using permissions: some PermissionRequesting) async -> PermissionStatus? {
        guard let step = currentStep else { return nil }
        do throws(PermissionError) {
            let status = try await permissions.request(step.permission)
            recordAnswer(step.permission, status: status)
            return status
        } catch {
            if case .cancelled = error { return nil }
            recordFailure(step.permission)
            return nil
        }
    }
}
