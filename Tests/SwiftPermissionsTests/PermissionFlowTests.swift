import Foundation
import SwiftPermissionsTesting
import Testing

private let steps: [PermissionFlowStep] = [
    .init(.notifications, title: "Stay in the loop"),
    .init(.locationWhenInUse, title: "Find stores near you"),
    .init(.photoLibrary, title: "Share your receipts", optional: true)
]

@Suite("PermissionFlowState transitions")
struct PermissionFlowStateTests {
    @Test func startsAtTheFirstStep() {
        let flow = PermissionFlowState(steps: steps)

        #expect(flow.currentStep?.permission == .notifications)
        #expect(flow.phase == .step(steps[0]))
        #expect(!flow.isFinished)
        #expect(flow.pendingSteps == steps)
        #expect(flow.statuses.isEmpty)
        #expect(flow.result == nil)
    }

    @Test func noStepsIsFinishedAtOnce() {
        let flow = PermissionFlowState(steps: [])

        #expect(flow.phase == .finished)
        #expect(flow.currentStep == nil)
        #expect(flow.result == PermissionFlowResult(reason: .completed, statuses: [:]))
    }

    @Test func duplicatePermissionsKeepTheFirstStep() {
        let flow = PermissionFlowState(steps: steps + [.init(.notifications, title: "Again")])

        #expect(flow.steps == steps)
    }

    @Test(arguments: [PermissionStatus.authorized, .denied, .restricted, .limited(.partial), .provisional])
    func decidedStepIsSkipped(status: PermissionStatus) {
        var flow = PermissionFlowState(steps: steps)

        let skipped = flow.skipIfDecided(.notifications, status: status, canRequest: false)

        #expect(skipped)
        #expect(flow.progress[.notifications] == .skipped(status))
        #expect(flow.currentStep?.permission == .locationWhenInUse)
    }

    @Test func unavailableStepIsSkippedEvenIfReportedRequestable() {
        var flow = PermissionFlowState(steps: steps)

        let skipped = flow.skipIfDecided(.notifications, status: .unavailable, canRequest: true)
        #expect(skipped)
        #expect(flow.progress[.notifications] == .skipped(.unavailable))
    }

    @Test func requestableStepIsNotSkipped() {
        var flow = PermissionFlowState(steps: steps)

        let skipped = flow.skipIfDecided(.notifications, status: .notDetermined, canRequest: true)
        #expect(!skipped)
        #expect(flow.currentStep?.permission == .notifications)
    }

    @Test func upgradeableStepIsNotSkipped() {
        // When-in-use location asked for Always: still a prompt to show.
        var flow = PermissionFlowState(steps: [.init(.locationAlways, title: "Always")])

        let skipped = flow.skipIfDecided(.locationAlways, status: .limited(.whenInUse), canRequest: true)
        #expect(!skipped)
    }

    @Test func answerMovesToTheNextStep() {
        var flow = PermissionFlowState(steps: steps)

        flow.recordAnswer(.notifications, status: .denied)

        #expect(flow.progress[.notifications] == .answered(.denied))
        #expect(flow.statuses == [.notifications: .denied])
        #expect(flow.currentStep?.permission == .locationWhenInUse)
    }

    @Test func failureMovesToTheNextStep() {
        var flow = PermissionFlowState(steps: steps)

        flow.recordFailure(.notifications)

        #expect(flow.progress[.notifications] == .failed)
        #expect(flow.statuses.isEmpty)
        #expect(flow.currentStep?.permission == .locationWhenInUse)
    }

    @Test func transitionsForAnotherStepAreIgnored() {
        var flow = PermissionFlowState(steps: steps)

        flow.recordAnswer(.photoLibrary, status: .authorized)
        flow.recordFailure(.locationWhenInUse)
        flow.notNow(.photoLibrary, status: .notDetermined)
        let skipped = flow.skipIfDecided(.locationWhenInUse, status: .denied, canRequest: false)
        #expect(!skipped)

        #expect(flow.progress == PermissionFlowProgress())
        #expect(flow.currentStep?.permission == .notifications)
    }

    @Test func notNowOnAnOptionalStepDefersAndMovesOn() {
        var flow = PermissionFlowState(steps: [steps[2], steps[0]])

        flow.notNow(.photoLibrary, status: .notDetermined)

        #expect(flow.progress[.photoLibrary] == .deferred(.notDetermined))
        #expect(flow.currentStep?.permission == .notifications)
        #expect(!flow.isPaused)
    }

    @Test func notNowOnARequiredStepPausesThere() {
        var flow = PermissionFlowState(steps: steps)

        flow.notNow(.notifications, status: .notDetermined)

        #expect(flow.isPaused)
        #expect(flow.phase == .paused(steps[0]))
        #expect(flow.currentStep == nil)
        #expect(flow.progress[.notifications] == nil)
        #expect(flow.result == PermissionFlowResult(reason: .paused(at: .notifications), statuses: [:]))
        #expect(flow.result?.isCompleted == false)
    }

    @Test func pausedFlowIgnoresTransitionsUntilResumed() {
        var flow = PermissionFlowState(steps: steps)
        flow.pause()

        flow.recordAnswer(.notifications, status: .authorized)
        #expect(flow.progress[.notifications] == nil)

        flow.resume()
        #expect(flow.currentStep?.permission == .notifications)
    }

    @Test func pausingAFinishedFlowDoesNothing() {
        var flow = PermissionFlowState(steps: [steps[0]])
        flow.recordAnswer(.notifications, status: .authorized)

        flow.pause()

        #expect(!flow.isPaused)
        #expect(flow.phase == .finished)
    }

    @Test func finishesWhenEveryStepHasAnOutcome() {
        var flow = PermissionFlowState(steps: steps)

        flow.recordAnswer(.notifications, status: .authorized)
        flow.skipIfDecided(.locationWhenInUse, status: .denied, canRequest: false)
        flow.notNow(.photoLibrary, status: .notDetermined)

        #expect(flow.isFinished)
        #expect(flow.phase == .finished)
        #expect(flow.pendingSteps.isEmpty)
        #expect(
            flow.statuses == [.notifications: .authorized, .locationWhenInUse: .denied, .photoLibrary: .notDetermined]
        )
        #expect(flow.result?.reason == .completed)
        #expect(flow.result?.isCompleted == true)
        #expect(flow.result?.statuses == flow.statuses)
    }

    @Test func resumesFromSavedProgress() {
        var first = PermissionFlowState(steps: steps)
        first.recordAnswer(.notifications, status: .authorized)
        first.notNow(.locationWhenInUse, status: .notDetermined)

        // Next launch: the pause isn't saved, so the flow continues where it stopped.
        let next = PermissionFlowState(steps: steps, progress: first.progress)

        #expect(!next.isPaused)
        #expect(next.currentStep?.permission == .locationWhenInUse)
    }

    @Test func forgettingAStepShowsItAgain() {
        var progress = PermissionFlowProgress(outcomes: [.notifications: .deferred(.notDetermined)])
        progress.forget(.notifications)

        #expect(PermissionFlowState(steps: steps, progress: progress).currentStep?.permission == .notifications)
    }
}

@Suite("PermissionFlowProgress persistence")
struct PermissionFlowProgressTests {
    private let progress = PermissionFlowProgress(outcomes: [
        .notifications: .answered(.provisional),
        .locationWhenInUse: .skipped(.unavailable),
        .photoLibrary: .deferred(.notDetermined),
        .camera: .failed
    ])

    @Test func roundTripsThroughRawValue() {
        #expect(PermissionFlowProgress(rawValue: progress.rawValue) == progress)
    }

    @Test func roundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(progress)

        #expect(try JSONDecoder().decode(PermissionFlowProgress.self, from: data) == progress)
    }

    @Test func emptyProgressRoundTrips() {
        #expect(PermissionFlowProgress(rawValue: PermissionFlowProgress().rawValue) == PermissionFlowProgress())
    }

    @Test(arguments: ["", "not json", "{\"outcomes\":42}"])
    func invalidRawValueIsNil(rawValue: String) {
        #expect(PermissionFlowProgress(rawValue: rawValue) == nil)
    }

    @Test func resetForgetsEverything() {
        var progress = self.progress
        progress.reset()

        #expect(progress.outcomes.isEmpty)
    }
}

@Suite("PermissionFlowState driving a manager")
struct PermissionFlowDriverTests {
    @Test func advanceSkipsDecidedStepsWithoutPrompting() async {
        let notifications = StubPermissionProvider(.notifications, status: .authorized)
        let location = StubPermissionProvider(.locationWhenInUse, status: .notDetermined)
        let photos = StubPermissionProvider(.photoLibrary, status: .unavailable)
        let manager = PermissionManager.stubbed(notifications, location, photos)
        var flow = PermissionFlowState(steps: steps)

        let next = await flow.advance(using: manager)

        #expect(next?.permission == .locationWhenInUse)
        #expect(flow.progress[.notifications] == .skipped(.authorized))
        #expect(await notifications.requestCount == 0)
    }

    @Test func runsTheWholeFlow() async {
        let notifications = StubPermissionProvider(.notifications, onRequest: .status(.provisional))
        let location = StubPermissionProvider(.locationWhenInUse, onRequest: .deny)
        let photos = StubPermissionProvider(.photoLibrary, status: .unavailable)
        let manager = PermissionManager.stubbed(notifications, location, photos)
        var flow = PermissionFlowState(steps: steps)

        while await flow.advance(using: manager) != nil {
            await flow.requestCurrent(using: manager)
        }

        #expect(flow.isFinished)
        #expect(flow.progress[.notifications] == .answered(.provisional))
        #expect(flow.progress[.locationWhenInUse] == .answered(.denied))
        #expect(flow.progress[.photoLibrary] == .skipped(.unavailable))
        #expect(await location.requestCount == 1)
        #expect(await photos.requestCount == 0)
    }

    @Test func failedRequestIsRecordedAndTheFlowMovesOn() async {
        // No provider for location: the manager throws providerNotRegistered.
        let manager = PermissionManager.stubbed([.notifications: .authorized])
        var flow = PermissionFlowState(steps: [steps[1], steps[0]])

        let status = await flow.requestCurrent(using: manager)
        #expect(status == nil)

        #expect(flow.progress[.locationWhenInUse] == .failed)
        #expect(flow.currentStep?.permission == .notifications)
    }

    @Test func cancelledRequestLeavesTheStepForNextTime() async {
        let notifications = StubPermissionProvider(.notifications, requestDelay: 0.5)
        let manager = PermissionManager.stubbed(notifications)
        let task = Task {
            var flow = PermissionFlowState(steps: [steps[0]])
            await flow.requestCurrent(using: manager)
            return flow
        }
        // Let the request reach the stub before cancelling it.
        while await notifications.requestCount == 0 {
            await Task.yield()
        }

        task.cancel()
        let flow = await task.value

        #expect(flow.progress[.notifications] == nil)
        #expect(flow.currentStep?.permission == .notifications)
    }

    @Test func cancelledAdvanceStops() async {
        let manager = PermissionManager.stubbed([.notifications: .authorized, .locationWhenInUse: .authorized])
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            var flow = PermissionFlowState(steps: steps)
            return await flow.advance(using: manager)
        }

        #expect(await task.value == nil)
    }

    @Test func requestWithoutACurrentStepDoesNothing() async {
        let notifications = StubPermissionProvider(.notifications)
        let manager = PermissionManager.stubbed(notifications)
        var flow = PermissionFlowState(steps: [steps[0]])
        flow.pause()

        let status = await flow.requestCurrent(using: manager)
        #expect(status == nil)
        #expect(await notifications.requestCount == 0)
    }
}
