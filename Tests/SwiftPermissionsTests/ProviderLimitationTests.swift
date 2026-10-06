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

/// The reason each provider works out for `.limited`. 4.0 puts it in the status.
@Suite("Provider limitations")
struct ProviderLimitationTests {
    // `authorizedWhenInUse` is unavailable on macOS, which only has Always.
    #if !os(macOS)
    @Test func locationAlwaysGrantedWhenInUseIsWhenInUse() {
        #expect(LocationPermissionProvider.mapLimitation(.authorizedWhenInUse, wantsAlways: true) == .whenInUse)
        #expect(LocationPermissionProvider.mapLimitation(.authorizedWhenInUse, wantsAlways: false) == nil)
    }
    #endif

    @Test func otherLocationStatusesHaveNoLimitation() {
        #expect(LocationPermissionProvider.mapLimitation(.authorizedAlways, wantsAlways: true) == nil)
        #expect(LocationPermissionProvider.mapLimitation(.denied, wantsAlways: true) == nil)
    }

    @Test func locationSessionKeepingWhenInUseIsWhenInUse() {
        var diagnostic = LocationSessionDiagnostic()
        diagnostic.alwaysAuthorizationDenied = true

        let limitation = LocationPermissionProvider.mapLimitation(
            diagnostic,
            authorization: .authorizedAlways,
            wantsAlways: true
        )
        #expect(limitation == .whenInUse)
        #expect(
            LocationPermissionProvider.mapLimitation(
                LocationSessionDiagnostic(),
                authorization: .authorizedAlways,
                wantsAlways: true
            ) == nil
        )
    }

    #if os(iOS) || os(macOS) || os(visionOS)
    @Test func limitedPhotosAreSelectedItems() {
        #expect(PhotoLibraryPermissionProvider.mapLimitation(.limited) == .selectedItems)
        #expect(PhotoLibraryPermissionProvider.mapLimitation(.authorized) == nil)
        #expect(PhotoLibraryPermissionProvider.mapLimitation(.denied) == nil)
    }
    #endif

    #if os(iOS) || os(macOS) || os(watchOS) || os(visionOS)
    @Test func limitedContactsAreSelectedItems() throws {
        // `.limited` (iOS 18) by raw value, as the provider reads it.
        let limited = try #require(CNAuthorizationStatus(rawValue: 4))

        #expect(ContactsPermissionProvider.mapLimitation(limited) == .selectedItems)
        #expect(ContactsPermissionProvider.mapLimitation(.authorized) == nil)
    }

    @Test func writeOnlyCalendarIsWriteOnly() throws {
        // `.writeOnly` (iOS 17) by raw value, as the provider reads it.
        let writeOnly = try #require(EKAuthorizationStatus(rawValue: 4))

        #expect(EventKitPermissionProvider.mapLimitation(writeOnly, wantsFullAccess: true) == .writeOnly)
        #expect(EventKitPermissionProvider.mapLimitation(writeOnly, wantsFullAccess: false) == nil)
        #expect(EventKitPermissionProvider.mapLimitation(.denied, wantsFullAccess: true) == nil)
    }
    #endif

    #if os(iOS) || os(watchOS) || os(visionOS)
    @Test func someHealthShareTypesArePartial() {
        #expect(HealthPermissionProvider.aggregateLimitation([.sharingAuthorized, .sharingDenied]) == .partial)
        #expect(HealthPermissionProvider.aggregateLimitation([.sharingAuthorized]) == nil)
        #expect(HealthPermissionProvider.aggregateLimitation([.sharingDenied]) == nil)
    }
    #endif
}
