import SwiftPermissionsCore
import SwiftPermissionsTesting
import SwiftPermissionsUI
import XCTest

@MainActor
final class PermissionStoreTests: XCTestCase {
    func testLoadReadsStatusesWithoutPrompting() async {
        let camera = StubPermissionProvider(.camera, status: .notDetermined)
        let store = PermissionStore(manager: PermissionManager.stubbed(camera))

        await store.load([.camera])

        XCTAssertEqual(store[.camera], .notDetermined)
        let requestCount = await camera.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testRequestUpdatesStatusAndClearsPending() async {
        let store = PermissionStore(manager: PermissionManager.stubbed([.camera: .notDetermined]))

        let status = await store.request(.camera)

        XCTAssertEqual(status, .authorized)
        XCTAssertEqual(store[.camera], .authorized)
        XCTAssertTrue(store.isGranted(.camera))
        XCTAssertTrue(store.pending.isEmpty)
    }

    func testUpgradableStatusIsRequestable() async {
        let location = StubPermissionProvider(
            .locationAlways,
            status: .limited(.whenInUse),
            upgradableFrom: [.limited(.whenInUse)]
        )
        let photos = StubPermissionProvider(.photoLibrary, status: .limited(.selectedItems))
        let store = PermissionStore(manager: PermissionManager.stubbed(location, photos))

        await store.load([.locationAlways, .photoLibrary])

        XCTAssertTrue(store.canRequest(.locationAlways), "when-in-use can be upgraded to Always")
        XCTAssertFalse(store.canRequest(.photoLibrary), "limited photos can't be upgraded with a prompt")
    }

    func testGrantedPermissionIsNoLongerRequestable() async {
        let store = PermissionStore(manager: PermissionManager.stubbed([.camera: .notDetermined]))
        await store.load([.camera])
        XCTAssertTrue(store.canRequest(.camera))

        await store.request(.camera)

        XCTAssertFalse(store.canRequest(.camera))
    }

    func testFailedRequestSetsLastError() async {
        let store = PermissionStore(manager: PermissionManager.stubbed())

        let status = await store.request(.camera)

        XCTAssertNil(status)
        XCTAssertEqual(store.lastError, .providerNotRegistered(.camera))
    }

    func testRefreshPicksUpSettingsChanges() async {
        let camera = StubPermissionProvider(.camera, status: .denied)
        let store = PermissionStore(manager: PermissionManager.stubbed(camera))
        await store.load([.camera])

        await camera.setStatus(.authorized)
        await store.refresh()

        XCTAssertEqual(store[.camera], .authorized)
    }

    func testBatchRequest() async {
        let store = PermissionStore(
            manager: PermissionManager.stubbed([.camera: .notDetermined, .microphone: .notDetermined], onRequest: .deny)
        )

        let result = await store.request([.camera, .microphone])

        XCTAssertEqual(result.statuses, [.camera: .denied, .microphone: .denied])
        XCTAssertEqual(store[.microphone], .denied)
        XCTAssertTrue(store.pending.isEmpty)
    }

    func testStoreFollowsRequestsMadeElsewhere() async throws {
        let manager = PermissionManager.stubbed([.camera: .notDetermined])
        let store = PermissionStore(manager: manager)
        // Let the store subscribe before the change happens.
        await Task.yield()
        await store.load([.camera])

        _ = try await manager.request(.camera)

        for _ in 0..<100 where store[.camera] != .authorized {
            await Task.yield()
        }
        XCTAssertEqual(store[.camera], .authorized)
    }

    func testPermissionUIMetadataIsDefinedForEveryStatus() {
        for status in PermissionStatus.allCases {
            XCTAssertFalse(status.title.isEmpty)
            XCTAssertFalse(status.systemImage.isEmpty)
        }
        XCTAssertEqual(Permission("custom").systemImage, "lock.shield.fill")
    }
}
