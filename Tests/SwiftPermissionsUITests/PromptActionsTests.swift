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
        let actions = PromptActions(status: .limited, canRequest: true, hasSettingsURL: true, canDefer: true)

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
        let actions = PromptActions(status: .limited, canRequest: false, hasSettingsURL: true, canDefer: true)

        XCTAssertEqual(actions.primary, .openSettings)
        XCTAssertFalse(actions.offersDefer)
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
