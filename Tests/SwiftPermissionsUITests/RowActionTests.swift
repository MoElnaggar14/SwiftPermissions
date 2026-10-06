import SwiftPermissionsCore
import SwiftPermissionsTesting
@testable import SwiftPermissionsUI
import XCTest

@MainActor
final class RowActionTests: XCTestCase {
    private func action(
        _ status: PermissionStatus?,
        isPending: Bool = false,
        canRequest: Bool = false,
        canSelectMore: Bool = false
    ) -> RowAction {
        RowAction(
            status: status,
            isPending: isPending,
            canRequest: canRequest,
            hasSettingsURL: true,
            canSelectMore: canSelectMore
        )
    }

    func testPendingShowsProgress() {
        XCTAssertEqual(action(.notDetermined, isPending: true, canRequest: true), .progress)
    }

    func testNotLoadedShowsNothing() {
        XCTAssertEqual(action(nil, canRequest: true), .nothing)
    }

    func testRequestAndUpgrade() {
        XCTAssertEqual(action(.notDetermined, canRequest: true), .request(upgrade: false))
        XCTAssertEqual(action(.limited, canRequest: true, canSelectMore: true), .request(upgrade: true))
    }

    func testLimitedOffersSelectMoreOnlyWithAPicker() {
        XCTAssertEqual(action(.limited, canSelectMore: true), .selectMore)
        XCTAssertEqual(action(.limited), .nothing, "unchanged when the app passes no picker")
    }

    func testDeniedStillOffersSettings() {
        XCTAssertEqual(action(.denied, canSelectMore: true), .openSettings)
    }

    func testLimitedPhotosAndContactsFromTheStoreOfferSelectMore() async {
        let photos = StubPermissionProvider(.photoLibrary, status: .limited)
        let contacts = StubPermissionProvider(.contacts, status: .limited)
        let store = PermissionStore(manager: PermissionManager.stubbed(photos, contacts))

        await store.load([.photoLibrary, .contacts])

        for permission in [Permission.photoLibrary, .contacts] {
            let decision = RowAction(
                status: store[permission],
                isPending: store.isPending(permission),
                canRequest: store.canRequest(permission),
                hasSettingsURL: true,
                canSelectMore: true
            )
            XCTAssertEqual(decision, .selectMore, "\(permission)")
        }
        let requestCount = await photos.requestCount
        XCTAssertEqual(requestCount, 0, "never shows a system prompt")
    }
}
