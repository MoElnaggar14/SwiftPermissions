import CoreLocation
import SwiftPermissionsCore
@testable import SwiftPermissionsLocation
import Testing

// `authorizedWhenInUse` is unavailable on macOS, which only has Always.
#if os(macOS)
private let authorizedStatuses: [CLAuthorizationStatus] = [.authorizedAlways]
#else
private let authorizedStatuses: [CLAuthorizationStatus] = [.authorizedAlways, .authorizedWhenInUse]
#endif

@Suite("Location accuracy")
struct LocationAccuracyTests {
    @Test(arguments: authorizedStatuses)
    func authorizedStatusesReportTheGrantedAccuracy(status: CLAuthorizationStatus) {
        #expect(LocationPermissionProvider.map(status, .fullAccuracy) == .full)
        #expect(LocationPermissionProvider.map(status, .reducedAccuracy) == .reduced)
    }

    @Test(arguments: [CLAuthorizationStatus.notDetermined, .denied, .restricted])
    func unauthorizedStatusesHaveNoAccuracy(status: CLAuthorizationStatus) {
        // Core Location reports an accuracy even when denied; it means nothing then.
        #expect(LocationPermissionProvider.map(status, .fullAccuracy) == nil)
        #expect(LocationPermissionProvider.map(status, .reducedAccuracy) == nil)
    }

    @Test func purposeKeyMustHaveANonEmptyString() {
        let purposes: [String: Any] = ["Navigation": "Turn-by-turn directions need your exact position.", "Blank": "  "]
        #expect(LocationPermissionProvider.hasPurpose("Navigation", in: purposes))
        #expect(!LocationPermissionProvider.hasPurpose("Blank", in: purposes))
        #expect(!LocationPermissionProvider.hasPurpose("Delivery", in: purposes))
        #expect(!LocationPermissionProvider.hasPurpose("Navigation", in: nil))
        #expect(!LocationPermissionProvider.hasPurpose("Navigation", in: "not a dictionary"))
    }

    #if !os(tvOS)
    @Test func missingPurposeStringThrowsBeforeAnyPrompt() async {
        // The test bundle has no NSLocationTemporaryUsageDescriptionDictionary.
        await #expect(throws: PermissionError.missingUsageDescription(
            .locationWhenInUse,
            keys: ["NSLocationTemporaryUsageDescriptionDictionary.Navigation"]
        )) {
            try await LocationPermissionProvider.whenInUse.requestTemporaryFullAccuracy(purposeKey: "Navigation")
        }
    }
    #endif
}
