import SwiftPermissionsCore
@testable import SwiftPermissionsUI
import XCTest

final class LimitedActionTests: XCTestCase {
    func testSelectedItemsPreferThePicker() {
        XCTAssertEqual(LimitedAction(.selectedItems, canSelectMore: true, hasSettingsURL: true), .selectMore)
        XCTAssertEqual(LimitedAction(.selectedItems, canSelectMore: false, hasSettingsURL: true), .openSettings)
        XCTAssertEqual(LimitedAction(.selectedItems, canSelectMore: false, hasSettingsURL: false), .nothing)
    }

    func testOnlySelectedItemsOfferThePicker() {
        for limitation in [Limitation.whenInUse, .writeOnly] {
            XCTAssertEqual(
                LimitedAction(limitation, canSelectMore: true, hasSettingsURL: true),
                .openSettings,
                "\(limitation)"
            )
            XCTAssertEqual(
                LimitedAction(limitation, canSelectMore: true, hasSettingsURL: false),
                .nothing,
                "\(limitation)"
            )
        }
    }

    func testPartialOffersNothing() {
        XCTAssertEqual(LimitedAction(.partial, canSelectMore: true, hasSettingsURL: true), .nothing)
    }

    func testEveryLimitationHasATitle() {
        XCTAssertEqual(Limitation.allCases.map(\.title), ["Selected Items", "While Using", "Write Only", "Partial"])
        XCTAssertEqual(PermissionStatus.limited(.selectedItems).title, "Limited")
    }

    func testDetailedTitleNamesTheReason() {
        XCTAssertEqual(PermissionStatus.limited(.selectedItems).detailedTitle, "Limited · Selected Items")
        XCTAssertEqual(PermissionStatus.limited(.whenInUse).detailedTitle, "Limited · While Using")
        XCTAssertEqual(PermissionStatus.authorized.detailedTitle, "Allowed")
    }
}
