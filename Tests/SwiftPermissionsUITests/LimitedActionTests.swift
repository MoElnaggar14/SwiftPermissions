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

    func testReasonComesFromThePermission() {
        let limited: PermissionStatus = .limited
        XCTAssertEqual(limited.limitation(for: .photoLibrary), .selectedItems)
        XCTAssertEqual(limited.limitation(for: .contacts), .selectedItems)
        XCTAssertEqual(limited.limitation(for: .locationAlways), .whenInUse)
        XCTAssertEqual(limited.limitation(for: .calendar), .writeOnly)
        XCTAssertEqual(limited.limitation(for: .health), .partial)
        XCTAssertEqual(limited.limitation(for: Permission("custom")), .partial)
        XCTAssertNil(PermissionStatus.authorized.limitation(for: .photoLibrary))
    }

    func testEveryLimitationHasATitle() {
        XCTAssertEqual(Limitation.allCases.map(\.title), ["Selected Items", "While Using", "Write Only", "Partial"])
        XCTAssertEqual(PermissionStatus.limited(.selectedItems).title, "Limited")
    }
}
