import SwiftPermissionsCore
import SwiftUI

/// Asks for several permissions in sequence, with a priming screen before each system
/// prompt. A typical onboarding flow.
///
/// ```swift
/// @AppStorage("onboardingPermissions") private var progress = PermissionFlowProgress()
///
/// PermissionFlow(store: permissions, steps: [
///     .init(.notifications, title: "Stay in the loop", message: "Get a ping when your order ships."),
///     .init(.locationWhenInUse, title: "Find stores near you", message: "See what's in stock nearby."),
///     .init(.photoLibrary, title: "Share your receipts", message: "Attach photos of receipts.", optional: true),
/// ], progress: $progress) { statuses in
///     showingOnboarding = false
/// }
/// ```
///
/// - A step is skipped without a screen when its permission can't show a prompt: it's
///   already decided, restricted or unavailable.
/// - Each screen offers the actions of ``PermissionPrompt``: **Continue** (which shows the
///   system prompt), **Not Now**, **Open Settings** and **Select More…**.
/// - **Not Now** on an optional step moves on. On a required step it pauses the flow,
///   and the flow starts from that step next time.
/// - Pass `progress` to persist how far the flow got. The package stores nothing.
///
/// The flow is rendered from a ``PermissionFlowState``. Removing the view cancels a
/// request in flight, and that step is shown again next time.
public struct PermissionFlow: View {
    private let steps: [PermissionFlowStep]
    private let externalProgress: Binding<PermissionFlowProgress>?
    private let onSelectMore: ((Permission) -> Void)?
    private let onFinish: ([Permission: PermissionStatus]) -> Void
    @ObservedObject private var store: PermissionStore
    @State private var localProgress = PermissionFlowProgress()
    @State private var isPaused = false
    /// The step whose status has been checked, so its screen can show.
    @State private var checked: Permission?
    /// The permission whose request is running. Driven by `task(id:)`, so the request is
    /// cancelled when the view goes away.
    @State private var requesting: Permission?
    @State private var reportedEnd = false
    // openURL rather than AppSettings.open, so the view also compiles in app extensions.
    @Environment(\.openURL) private var openURL

    /// - Parameters:
    ///   - steps: The permissions to ask for, in order, with their priming copy.
    ///   - progress: Where the flow keeps its progress. Bind it to storage, such as
    ///     `@AppStorage`, to continue from where the flow stopped on the next launch.
    ///     When `nil`, progress lasts as long as the view.
    ///   - onSelectMore: Called when the user taps **Select More…**, offered while a
    ///     step's access is limited. Present the system's limited-access picker from it.
    ///   - onFinish: Called when the flow ends, with the last known status of each step:
    ///     every step has an outcome, or the user paused on a required step. To tell
    ///     them apart, check `PermissionFlowState(steps:progress:).isFinished`.
    public init(
        store: PermissionStore,
        steps: [PermissionFlowStep],
        progress: Binding<PermissionFlowProgress>? = nil,
        onSelectMore: ((Permission) -> Void)? = nil,
        onFinish: @escaping ([Permission: PermissionStatus]) -> Void
    ) {
        self.store = store
        self.steps = steps
        self.externalProgress = progress
        self.onSelectMore = onSelectMore
        self.onFinish = onFinish
    }

    private var progress: Binding<PermissionFlowProgress> {
        externalProgress ?? $localProgress
    }

    private var state: PermissionFlowState {
        var state = PermissionFlowState(steps: steps, progress: progress.wrappedValue)
        if isPaused { state.pause() }
        return state
    }

    private func update(_ transition: (inout PermissionFlowState) -> Void) {
        var state = self.state
        transition(&state)
        progress.wrappedValue = state.progress
        isPaused = state.isPaused
    }

    public var body: some View {
        let state = self.state
        Group {
            if let step = state.currentStep {
                if checked == step.permission {
                    stepScreen(step, in: state)
                } else {
                    ProgressView()
                }
            } else {
                Color.clear
            }
        }
        .task(id: state.currentStep?.permission) { await checkCurrentStep() }
        .task(id: requesting) { await runRequest() }
        .refreshesPermissions(store)
    }

    /// Reads the current step's status and skips it when no prompt can appear.
    private func checkCurrentStep() async {
        guard let step = state.currentStep else {
            if !reportedEnd {
                reportedEnd = true
                onFinish(state.statuses)
            }
            return
        }
        reportedEnd = false
        let permission = step.permission
        await store.load([permission])
        guard !Task.isCancelled else { return }
        let status = store[permission] ?? .notDetermined
        let canRequest = store.canRequest(permission)
        update { _ = $0.skipIfDecided(permission, status: status, canRequest: canRequest) }
        checked = permission
    }

    private func runRequest() async {
        guard let permission = requesting else { return }
        let status = await store.request(permission)
        // The view went away mid-prompt: leave the step for next time.
        guard !Task.isCancelled else { return }
        update { state in
            if let status {
                state.recordAnswer(permission, status: status)
            } else {
                state.recordFailure(permission)
            }
        }
        requesting = nil
    }

    private func stepScreen(_ step: PermissionFlowStep, in state: PermissionFlowState) -> some View {
        let number = (state.steps.firstIndex(of: step) ?? 0) + 1
        return VStack(spacing: 16) {
            Image(systemName: step.permission.systemImage)
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(step.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(step.message ?? "Allow access to \(step.permission.displayName) to use this feature.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            actions(for: step.permission)
            Text("Step \(number) of \(state.steps.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func actions(for permission: Permission) -> some View {
        let status = store[permission] ?? .notDetermined
        let busy = requesting != nil || store.isPending(permission)
        let decision = PromptActions(
            status: status,
            canRequest: store.canRequest(permission),
            hasSettingsURL: AppSettings.url(for: permission) != nil,
            canDefer: true,
            canSelectMore: onSelectMore != nil
        )
        switch decision.primary {
        case .request:
            Button("Continue") { requesting = permission }
                .buttonStyle(.borderedProminent)
                .disabled(busy)
        case .selectMore:
            if let onSelectMore {
                Button("Select More…") { onSelectMore(permission) }
                    .buttonStyle(.bordered)
            }
        case .openSettings:
            if let settings = AppSettings.url(for: permission) {
                Button("Open Settings") { openURL(settings) }
                    .buttonStyle(.bordered)
            }
        case .nothing:
            EmptyView()
        }
        if decision.offersDefer {
            Button("Not Now") { update { $0.notNow(permission, status: status) } }
                .disabled(busy)
        } else {
            // The status changed while the screen was up, so no prompt can appear: move on.
            Button("Next") {
                let canRequest = store.canRequest(permission)
                update { _ = $0.skipIfDecided(permission, status: status, canRequest: canRequest) }
            }
            .disabled(busy)
        }
    }
}
