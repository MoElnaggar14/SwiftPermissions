@testable import SwiftPermissionsCore
import UserNotifications
import XCTest

final class NotificationSettingsTests: XCTestCase {
    func testFeatureSettingMapping() {
        XCTAssertEqual(NotificationSettingsSnapshot.map(UNNotificationSetting.enabled), .enabled)
        XCTAssertEqual(NotificationSettingsSnapshot.map(UNNotificationSetting.disabled), .disabled)
        XCTAssertEqual(NotificationSettingsSnapshot.map(UNNotificationSetting.notSupported), .notSupported)
    }

    #if !os(tvOS) && !os(watchOS)
    func testAlertStyleAndPreviewsMapping() {
        XCTAssertEqual(NotificationSettingsSnapshot.map(UNAlertStyle.none), .off)
        XCTAssertEqual(NotificationSettingsSnapshot.map(UNAlertStyle.banner), .banner)
        XCTAssertEqual(NotificationSettingsSnapshot.map(UNAlertStyle.alert), .alert)
        XCTAssertEqual(NotificationSettingsSnapshot.map(UNShowPreviewsSetting.always), .always)
        XCTAssertEqual(NotificationSettingsSnapshot.map(UNShowPreviewsSetting.whenAuthenticated), .whenUnlocked)
        XCTAssertEqual(NotificationSettingsSnapshot.map(UNShowPreviewsSetting.never), .never)
    }
    #endif

    func testNotAllowedIsSilent() {
        for status in [PermissionStatus.notDetermined, .denied, .restricted, .unavailable] {
            let settings = NotificationSettingsSnapshot(authorization: status, alert: .enabled, sound: .enabled)
            XCTAssertTrue(settings.isEffectivelySilent, "\(status)")
        }
    }

    func testAuthorizedButEverythingOffIsSilent() {
        let settings = NotificationSettingsSnapshot(
            authorization: .authorized,
            alert: .disabled,
            sound: .disabled,
            badge: .enabled,
            lockScreen: .disabled,
            notificationCenter: .disabled,
            alertStyle: .off
        )
        XCTAssertTrue(settings.isEffectivelySilent, "a badge alone isn't noticed")
    }

    func testAnyVisibleOrAudiblePresentationIsNotSilent() {
        let visibleInNotificationCenter = NotificationSettingsSnapshot(
            authorization: .authorized,
            alert: .disabled,
            sound: .disabled,
            lockScreen: .disabled,
            notificationCenter: .enabled
        )
        let soundOnly = NotificationSettingsSnapshot(
            authorization: .provisional,
            alert: .disabled,
            sound: .enabled,
            lockScreen: .disabled,
            notificationCenter: .disabled
        )
        XCTAssertFalse(visibleInNotificationCenter.isEffectivelySilent)
        XCTAssertFalse(soundOnly.isEffectivelySilent)
    }

    func testBadgeCountsWhereItIsTheOnlyPresentation() {
        // tvOS: only badges exist.
        let badgeOn = NotificationSettingsSnapshot(authorization: .authorized, badge: .enabled)
        let badgeOff = NotificationSettingsSnapshot(authorization: .authorized, badge: .disabled)
        XCTAssertFalse(badgeOn.isEffectivelySilent)
        XCTAssertTrue(badgeOff.isEffectivelySilent)
    }

    func testSnapshotRoundTripsThroughCodable() throws {
        let settings = NotificationSettingsSnapshot(
            authorization: .authorized,
            alert: .enabled,
            timeSensitive: .disabled,
            alertStyle: .banner,
            previews: .whenUnlocked
        )
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(NotificationSettingsSnapshot.self, from: data), settings)
    }
}
