import SwiftPermissionsCore
import SwiftPermissionsTesting
import XCTest

final class PermissionManagerTests: XCTestCase {
    private struct FrameworkError: Error, Sendable {}

    // MARK: - Status

    func testUnregisteredPermissionIsUnavailable() async {
        let manager = PermissionManager.stubbed()
        let status = await manager.status(of: .camera)
        XCTAssertEqual(status, .unavailable)
    }

    func testStatusReadsProviderWithoutPrompting() async {
        let camera = StubPermissionProvider(.camera, status: .notDetermined)
        let manager = PermissionManager.stubbed(camera)

        let status = await manager.status(of: .camera)

        XCTAssertEqual(status, .notDetermined)
        let requestCount = await camera.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    // MARK: - Request

    func testRequestPromptsWhenNotDetermined() async throws {
        let camera = StubPermissionProvider(.camera, onRequest: .grant)
        let manager = PermissionManager.stubbed(camera)

        let status = try await manager.request(.camera)

        XCTAssertEqual(status, .authorized)
        let requestCount = await camera.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testRequestDoesNotPromptWhenAlreadyDecided() async throws {
        let camera = StubPermissionProvider(.camera, status: .denied, onRequest: .grant)
        let manager = PermissionManager.stubbed(camera)

        let status = try await manager.request(.camera)

        XCTAssertEqual(status, .denied)
        let requestCount = await camera.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testRequestKeepsLimitedAccess() async throws {
        let photos = StubPermissionProvider(.photoLibrary, onRequest: .status(.limited))
        let manager = PermissionManager.stubbed(photos)

        let status = try await manager.request(.photoLibrary)

        XCTAssertEqual(status, .limited)
        XCTAssertTrue(status.isGranted)
    }

    func testRequestUnregisteredPermissionThrows() async {
        let manager = PermissionManager.stubbed()
        do throws(PermissionError) {
            _ = try await manager.request(.camera)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error, .providerNotRegistered(.camera))
        }
    }

    func testFrameworkErrorsAreWrapped() async {
        let contacts = StubPermissionProvider(.contacts, onRequest: .fail(FrameworkError()))
        let manager = PermissionManager.stubbed(contacts)
        do throws(PermissionError) {
            _ = try await manager.request(.contacts)
            XCTFail("Expected an error")
        } catch {
            guard case .requestFailed(.contacts, _) = error else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testConcurrentRequestsShowOnePrompt() async throws {
        let camera = StubPermissionProvider(.camera, onRequest: .grant, requestDelay: 0.2)
        let manager = PermissionManager.stubbed(camera)

        async let first = manager.request(.camera)
        async let second = manager.request(.camera)
        async let third = manager.request(.camera)
        let statuses = try await [first, second, third]

        XCTAssertEqual(statuses, [.authorized, .authorized, .authorized])
        let requestCount = await camera.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testFailedRequestCanBeRetried() async throws {
        let camera = StubPermissionProvider(.camera, onRequest: .fail(FrameworkError()))
        let manager = PermissionManager.stubbed(camera)
        _ = try? await manager.request(.camera)

        await camera.setOutcome(.grant)
        let status = try await manager.request(.camera)

        XCTAssertEqual(status, .authorized)
    }

    // MARK: - Usage descriptions

    func testMissingUsageDescriptionStopsRequestBeforePrompt() async {
        let camera = StubPermissionProvider(.camera, requiredUsageDescriptionKeys: ["NSCameraUsageDescription"])
        let manager = PermissionManager(
            registry: PermissionProviderRegistry([camera]),
            usageDescriptions: InfoPlist([:])
        )

        do throws(PermissionError) {
            _ = try await manager.request(.camera)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error, .missingUsageDescription(.camera, keys: ["NSCameraUsageDescription"]))
        }
        let requestCount = await camera.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testPresentUsageDescriptionAllowsRequest() async throws {
        let camera = StubPermissionProvider(.camera, requiredUsageDescriptionKeys: ["NSCameraUsageDescription"])
        let manager = PermissionManager(
            registry: PermissionProviderRegistry([camera]),
            usageDescriptions: InfoPlist(["NSCameraUsageDescription": "Scan documents"])
        )

        let status = try await manager.request(.camera)

        XCTAssertEqual(status, .authorized)
    }

    func testMissingUsageDescriptionsDiagnostics() {
        let camera = StubPermissionProvider(.camera, requiredUsageDescriptionKeys: ["NSCameraUsageDescription"])
        let mic = StubPermissionProvider(.microphone, requiredUsageDescriptionKeys: ["NSMicrophoneUsageDescription"])
        let manager = PermissionManager(
            registry: PermissionProviderRegistry([camera, mic]),
            usageDescriptions: InfoPlist(["NSCameraUsageDescription": "Scan documents"])
        )

        let missing = manager.missingUsageDescriptions(for: [.camera, .microphone, .contacts])

        XCTAssertEqual(missing, [.microphone: ["NSMicrophoneUsageDescription"]])
    }

    // MARK: - Observation

    func testUpdatesStartWithCurrentStatusThenChanges() async throws {
        let camera = StubPermissionProvider(.camera, onRequest: .grant)
        let manager = PermissionManager.stubbed(camera)
        var iterator = manager.updates(for: .camera).makeAsyncIterator()

        let initial = await iterator.next()
        XCTAssertEqual(initial, .notDetermined)

        _ = try await manager.request(.camera)
        let next = await iterator.next()
        XCTAssertEqual(next, .authorized)
    }

    func testRefreshPublishesChangesMadeInSettings() async throws {
        let camera = StubPermissionProvider(.camera, status: .denied)
        let manager = PermissionManager.stubbed(camera)
        var changes = manager.changes().makeAsyncIterator()
        _ = await manager.status(of: .camera)
        let first = await changes.next()
        XCTAssertEqual(first, PermissionChange(permission: .camera, status: .denied))

        await camera.setStatus(.authorized)
        await manager.refresh()

        let second = await changes.next()
        XCTAssertEqual(second, PermissionChange(permission: .camera, status: .authorized))
    }

    func testUnchangedStatusIsNotRepublished() async {
        let camera = StubPermissionProvider(.camera, status: .denied)
        let mic = StubPermissionProvider(.microphone, status: .denied)
        let manager = PermissionManager.stubbed(camera, mic)
        var changes = manager.changes().makeAsyncIterator()
        // Give the observer registration a chance to run.
        _ = await manager.status(of: .camera)
        _ = await changes.next()

        _ = await manager.status(of: .camera)
        _ = await manager.status(of: .microphone)

        // The next change is the microphone, not a repeat of the camera.
        let next = await changes.next()
        XCTAssertEqual(next?.permission, .microphone)
    }

    // MARK: - Batch

    func testBatchRequestCollectsStatusesAndFailures() async {
        let camera = StubPermissionProvider(.camera, onRequest: .grant)
        let mic = StubPermissionProvider(.microphone, onRequest: .deny)
        let manager = PermissionManager.stubbed(camera, mic)

        let result = await manager.request([.camera, .microphone, .contacts])

        XCTAssertEqual(result.statuses, [.camera: .authorized, .microphone: .denied])
        XCTAssertEqual(result.failures, [.contacts: .providerNotRegistered(.contacts)])
        XCTAssertFalse(result.allGranted)
    }

    func testAreAllGranted() async {
        let manager = PermissionManager.stubbed([.camera: .authorized, .photoLibrary: .limited, .microphone: .denied])
        let mediaGranted = await manager.areAllGranted([.camera, .photoLibrary])
        let allGranted = await manager.areAllGranted([.camera, .microphone])
        XCTAssertTrue(mediaGranted)
        XCTAssertFalse(allGranted)
    }

    // MARK: - Upgrades

    func testUpgradablePartialStatusIsRequested() async throws {
        let location = StubPermissionProvider(
            .locationAlways,
            status: .limited,
            onRequest: .grant,
            upgradableFrom: [.limited]
        )
        let manager = PermissionManager.stubbed(location)

        let status = try await manager.request(.locationAlways)

        XCTAssertEqual(status, .authorized)
        let requestCount = await location.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testNonUpgradablePartialStatusIsNotRequested() async throws {
        let photos = StubPermissionProvider(.photoLibrary, status: .limited, onRequest: .grant)
        let manager = PermissionManager.stubbed(photos)

        let status = try await manager.request(.photoLibrary)

        XCTAssertEqual(status, .limited)
        let requestCount = await photos.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    // MARK: - Initial values

    func testUpdatesForUnregisteredPermissionEmitsUnavailable() async {
        let manager = PermissionManager.stubbed()
        var iterator = manager.updates(for: .health).makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertEqual(first, .unavailable)
    }

    func testEachSubscriberGetsTheInitialValueExactlyOnce() async throws {
        let camera = StubPermissionProvider(.camera, status: .denied)
        let manager = PermissionManager.stubbed(camera)
        var first = manager.updates(for: .camera).makeAsyncIterator()
        var second = manager.updates(for: .camera).makeAsyncIterator()

        let firstInitial = await first.next()
        let secondInitial = await second.next()
        XCTAssertEqual(firstInitial, .denied)
        XCTAssertEqual(secondInitial, .denied)

        await camera.setStatus(.authorized)
        await manager.refresh()

        // The next value is the change, not a repeated initial value.
        let secondNext = await second.next()
        XCTAssertEqual(secondNext, .authorized)
    }

    // MARK: - Extensibility

    func testCustomPermissionsPlugIn() async throws {
        let pushToTalk = Permission("pushToTalk", displayName: "Push to Talk")
        let manager = PermissionManager.stubbed(StubPermissionProvider(pushToTalk, onRequest: .grant))

        let status = try await manager.request(pushToTalk)

        XCTAssertEqual(status, .authorized)
    }
}
