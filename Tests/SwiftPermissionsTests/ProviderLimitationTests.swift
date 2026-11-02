import CoreLocation
@testable import SwiftPermissionsCalendar
@testable import SwiftPermissionsContacts
import SwiftPermissionsCore
@testable import SwiftPermissionsHealth
@testable import SwiftPermissionsLocation
@testable import SwiftPermissionsPhotos
import Testing
#if os(iOS) || os(macOS) || os(watchOS) || os(visionOS)
import Contacts
import EventKit
#endif
#if os(iOS) || os(macOS) || os(visionOS)
import Photos
#endif
#if os(iOS) || os(watchOS) || os(visionOS)
import HealthKit
#endif

/// The reason each built-in provider reports with `.limited`.
@Suite("Provider limitations")
struct ProviderLimitationTests {
    // `authorizedWhenInUse` is unavailable on macOS, which only has Always.
    #if !os(macOS)
    @Test func locationAlwaysGrantedWhenInUseIsWhenInUse() {
        #expect(LocationPermissionProvider.map(.authorizedWhenInUse, wantsAlways: true) == .limited(.whenInUse))
        #expect(LocationPermissionProvider.map(.authorizedWhenInUse, wantsAlways: false) == .authorized)
    }
    #endif

    @Test func otherLocationStatusesAreNotLimited() {
        #expect(LocationPermissionProvider.map(.authorizedAlways, wantsAlways: true) == .authorized)
        #expect(LocationPermissionProvider.map(.denied, wantsAlways: true) == .denied)
    }

    #if !os(tvOS) && !os(visionOS)
    @Test func locationAlwaysUpgradesOnlyFromWhenInUse() {
        let always = LocationPermissionProvider.always

        // The Always upgrade prompt only exists on iOS.
        #if os(iOS)
        #expect(always.canRequest(from: .limited(.whenInUse)))
        #else
        #expect(!always.canRequest(from: .limited(.whenInUse)))
        #endif
        #expect(!always.canRequest(from: .limited(.partial)))
        #expect(!LocationPermissionProvider.whenInUse.canRequest(from: .limited(.whenInUse)))
    }
    #endif

    @Test func locationSessionKeepingWhenInUseIsWhenInUse() {
        var diagnostic = LocationSessionDiagnostic()
        diagnostic.alwaysAuthorizationDenied = true

        let status = LocationPermissionProvider.map(diagnostic, authorization: .authorizedAlways, wantsAlways: true)
        #expect(status == .limited(.whenInUse))
        #expect(
            LocationPermissionProvider.map(
                LocationSessionDiagnostic(),
                authorization: .authorizedAlways,
                wantsAlways: true
            ) == .authorized
        )
    }

    #if os(iOS) || os(macOS) || os(visionOS)
    @Test func limitedPhotosAreSelectedItems() {
        #expect(PhotoLibraryPermissionProvider.map(.limited) == .limited(.selectedItems))
        #expect(PhotoLibraryPermissionProvider.map(.authorized) == .authorized)
        #expect(PhotoLibraryPermissionProvider.map(.denied) == .denied)
    }
    #endif

    #if os(iOS) || os(macOS) || os(watchOS) || os(visionOS)
    @Test func limitedContactsAreSelectedItems() throws {
        // `.limited` (iOS 18) by raw value, as the provider reads it.
        let limited = try #require(CNAuthorizationStatus(rawValue: 4))

        #expect(ContactsPermissionProvider.map(limited) == .limited(.selectedItems))
        #expect(ContactsPermissionProvider.map(.authorized) == .authorized)
    }

    @Test func writeOnlyCalendarIsWriteOnly() throws {
        // `.writeOnly` (iOS 17) by raw value, as the provider reads it.
        let writeOnly = try #require(EKAuthorizationStatus(rawValue: 4))

        #expect(EventKitPermissionProvider.map(writeOnly, wantsFullAccess: true) == .limited(.writeOnly))
        #expect(EventKitPermissionProvider.map(writeOnly, wantsFullAccess: false) == .authorized)
        #expect(EventKitPermissionProvider.map(.denied, wantsFullAccess: true) == .denied)
    }

    @Test func fullCalendarUpgradesOnlyFromWriteOnly() {
        #expect(EventKitPermissionProvider.calendar.canRequest(from: .limited(.writeOnly)))
        #expect(!EventKitPermissionProvider.calendar.canRequest(from: .limited(.partial)))
        #expect(!EventKitPermissionProvider.calendarWriteOnly.canRequest(from: .limited(.writeOnly)))
    }
    #endif

    #if os(iOS) || os(watchOS) || os(visionOS)
    @Test func someHealthShareTypesArePartial() {
        #expect(HealthPermissionProvider.aggregate([.sharingAuthorized, .sharingDenied]) == .limited(.partial))
        #expect(HealthPermissionProvider.aggregate([.sharingAuthorized]) == .authorized)
        #expect(HealthPermissionProvider.aggregate([.sharingDenied]) == .denied)
    }
    #endif
}
