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
        hasSettingsURL: Bool = true,
        canSelectMore: Bool = false,
        limitation: Limitation? = nil
    ) -> RowAction {
        RowAction(
            status: status,
            isPending: isPending,
            canRequest: canRequest,
            hasSettingsURL: hasSettingsURL,
            canSelectMore: canSelectMore,
            limitation: limitation
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
        XCTAssertEqual(
            action(.limited(.whenInUse), canRequest: true, canSelectMore: true, limitation: .whenInUse),
            .request(upgrade: true)
        )
    }

    func testSelectedItemsOfferSelectMoreWithAPicker() {
        XCTAssertEqual(action(.limited(.selectedItems), canSelectMore: true, limitation: .selectedItems), .selectMore)
    }

    func testSelectedItemsWithoutAPickerOfferSettings() {
        XCTAssertEqual(action(.limited(.selectedItems), limitation: .selectedItems), .openSettings)
        XCTAssertEqual(
            action(.limited(.selectedItems), hasSettingsURL: false, limitation: .selectedItems),
            .nothing,
            "no Settings URL on watchOS"
        )
    }

    func testOnlySelectedItemsOfferSelectMore() {
        // When-in-use location after the Always prompt was spent used to offer Select More….
        for limitation in [Limitation.whenInUse, .writeOnly] {
            XCTAssertEqual(
                action(.limited(limitation), canSelectMore: true, limitation: limitation),
                .openSettings,
                "\(limitation)"
            )
        }
    }

    func testPartialOffersNothing() {
        XCTAssertEqual(action(.limited(.partial), canSelectMore: true, limitation: .partial), .nothing)
        XCTAssertEqual(action(.limited(.partial), canSelectMore: true), .nothing, "no reason reads as partial")
    }

    func testDeniedStillOffersSettings() {
        XCTAssertEqual(action(.denied, canSelectMore: true), .openSettings)
    }

    func testLimitedPhotosAndContactsFromTheStoreOfferSelectMore() async {
        let photos = StubPermissionProvider(.photoLibrary, status: .limited(.selectedItems))
        let contacts = StubPermissionProvider(.contacts, status: .limited(.selectedItems))
        let store = PermissionStore(manager: PermissionManager.stubbed(photos, contacts))

        await store.load([.photoLibrary, .contacts])

        for permission in [Permission.photoLibrary, .contacts] {
            XCTAssertEqual(decision(for: permission, in: store), .selectMore, "\(permission)")
        }
        let requestCount = await photos.requestCount
        XCTAssertEqual(requestCount, 0, "never shows a system prompt")
    }

    func testWhenInUseLocationFromTheStoreOffersSettingsNotSelectMore() async {
        // The Always upgrade prompt was already spent, so it can't be requested again.
        let location = StubPermissionProvider(.locationAlways, status: .limited(.whenInUse))
        let calendar = StubPermissionProvider(.calendar, status: .limited(.writeOnly))
        let store = PermissionStore(manager: PermissionManager.stubbed(location, calendar))

        await store.load([.locationAlways, .calendar])

        for permission in [Permission.locationAlways, .calendar] {
            XCTAssertEqual(decision(for: permission, in: store), .openSettings, "\(permission)")
        }
    }

    private func decision(for permission: Permission, in store: PermissionStore) -> RowAction {
        RowAction(
            status: store[permission],
            isPending: store.isPending(permission),
            canRequest: store.canRequest(permission),
            hasSettingsURL: true,
            canSelectMore: true,
            limitation: store[permission]?.limitation(for: permission)
        )
    }
}
