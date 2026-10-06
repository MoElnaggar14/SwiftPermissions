import SwiftPermissionsCore
@testable import SwiftPermissionsUI
import XCTest

final class PromptActionsTests: XCTestCase {
    func testRequestableOffersContinueAndNotNowWhenDeferrable() {
        let actions = PromptActions(status: .notDetermined, canRequest: true, hasSettingsURL: true, canDefer: true)

        XCTAssertEqual(actions.primary, .request)
        XCTAssertTrue(actions.offersDefer)
    }

    func testNoNotNowWithoutADeferHandler() {
        let actions = PromptActions(status: .notDetermined, canRequest: true, hasSettingsURL: true, canDefer: false)

        XCTAssertEqual(actions.primary, .request)
        XCTAssertFalse(actions.offersDefer)
    }

    func testUpgradeCanBeDeferredToo() {
        // When-in-use location asking for Always: still requestable, so "Not Now" makes sense.
        let actions = PromptActions(
            status: .limited(.whenInUse), canRequest: true, hasSettingsURL: true, canDefer: true, limitation: .whenInUse
        )

        XCTAssertEqual(actions.primary, .request)
        XCTAssertTrue(actions.offersDefer)
    }

    func testDeniedOffersSettingsAndNeverNotNow() {
        let actions = PromptActions(status: .denied, canRequest: false, hasSettingsURL: true, canDefer: true)

        XCTAssertEqual(actions.primary, .openSettings)
        XCTAssertFalse(actions.offersDefer, "the prompt is already spent")
    }

    func testLimitedWithoutUpgradeOffersSettings() {
        // Limited photos can't be upgraded with a prompt.
        let actions = PromptActions(
            status: .limited(.selectedItems),
            canRequest: false,
            hasSettingsURL: true,
            canDefer: true,
            limitation: .selectedItems
        )

        XCTAssertEqual(actions.primary, .openSettings)
        XCTAssertFalse(actions.offersDefer)
    }

    func testLimitedWithPickerOffersSelectMoreInsteadOfSettings() {
        let actions = PromptActions(
            status: .limited(.selectedItems),
            canRequest: false,
            hasSettingsURL: true,
            canDefer: true,
            canSelectMore: true,
            limitation: .selectedItems
        )

        XCTAssertEqual(actions.primary, .selectMore)
        XCTAssertFalse(actions.offersDefer)
    }

    func testUpgradeWinsOverSelectMore() {
        let actions = PromptActions(
            status: .limited(.selectedItems),
            canRequest: true,
            hasSettingsURL: true,
            canDefer: false,
            canSelectMore: true,
            limitation: .selectedItems
        )

        XCTAssertEqual(actions.primary, .request)
    }

    func testOnlySelectedItemsOfferSelectMore() {
        // When-in-use location after the Always prompt was spent used to offer Select More….
        for limitation in [Limitation.whenInUse, .writeOnly] {
            let actions = PromptActions(
                status: .limited(limitation),
                canRequest: false,
                hasSettingsURL: true,
                canDefer: true,
                canSelectMore: true,
                limitation: limitation
            )

            XCTAssertEqual(actions.primary, .openSettings, "\(limitation)")
        }
    }

    func testPartialOffersNothing() {
        // Health: no Settings pane for the app, and no upgrade prompt.
        let actions = PromptActions(
            status: .limited(.partial),
            canRequest: false,
            hasSettingsURL: true,
            canDefer: true,
            canSelectMore: true,
            limitation: .partial
        )

        XCTAssertEqual(actions.primary, .nothing)
    }

    func testSelectMoreOnlyWhenLimited() {
        for status in [PermissionStatus.denied, .authorized, .restricted] {
            let actions = PromptActions(
                status: status, canRequest: false, hasSettingsURL: true, canDefer: false, canSelectMore: true
            )

            XCTAssertNotEqual(actions.primary, .selectMore, "\(status)")
        }
    }

    func testNoSettingsURLMeansNoSettingsButton() {
        // watchOS has no Settings URL.
        let actions = PromptActions(status: .denied, canRequest: false, hasSettingsURL: false, canDefer: true)

        XCTAssertEqual(actions.primary, .nothing)
        XCTAssertFalse(actions.offersDefer)
    }

    func testRestrictedAndUnavailableOfferNothing() {
        for status in [PermissionStatus.restricted, .unavailable] {
            let actions = PromptActions(status: status, canRequest: false, hasSettingsURL: true, canDefer: true)

            XCTAssertEqual(actions.primary, .nothing, "\(status)")
            XCTAssertFalse(actions.offersDefer, "\(status)")
        }
    }
}
