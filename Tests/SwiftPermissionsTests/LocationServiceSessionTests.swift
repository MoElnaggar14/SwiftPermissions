import CoreLocation
import SwiftPermissionsCore
@testable import SwiftPermissionsLocation
import Testing

@Suite("Location service session diagnostics")
struct LocationServiceSessionTests {
    private func map(
        _ configure: (inout LocationSessionDiagnostic) -> Void = { _ in },
        authorization: CLAuthorizationStatus,
        wantsAlways: Bool = false
    ) -> PermissionStatus {
        var diagnostic = LocationSessionDiagnostic()
        configure(&diagnostic)
        return LocationPermissionProvider.map(diagnostic, authorization: authorization, wantsAlways: wantsAlways)
    }

    @Test(arguments: [CLAuthorizationStatus.notDetermined, .denied, .restricted, .authorizedAlways])
    func noFlagsReportsTheAuthorizationStatus(authorization: CLAuthorizationStatus) {
        for wantsAlways in [false, true] {
            #expect(
                map(authorization: authorization, wantsAlways: wantsAlways)
                    == LocationPermissionProvider.map(authorization, wantsAlways: wantsAlways)
            )
        }
    }

    @Test func restrictedWinsOverEveryOtherFlag() {
        var diagnostic = LocationSessionDiagnostic()
        diagnostic.authorizationRestricted = true
        diagnostic.authorizationDenied = true
        diagnostic.authorizationDeniedGlobally = true
        let status = LocationPermissionProvider.map(diagnostic, authorization: .authorizedAlways, wantsAlways: false)
        #expect(status == .restricted)
    }

    @Test func deniedForTheAppIsDenied() {
        #expect(map({ $0.authorizationDenied = true }, authorization: .denied) == .denied)
        // The diagnostic can arrive before the manager's status catches up.
        #expect(map({ $0.authorizationDenied = true }, authorization: .notDetermined) == .denied)
    }

    @Test func locationServicesOffMatchesStatus() {
        // Like `status()`: undecided with Location Services off can never prompt.
        #expect(map({ $0.authorizationDeniedGlobally = true }, authorization: .notDetermined) == .unavailable)
        #expect(map({ $0.authorizationDeniedGlobally = true }, authorization: .authorizedAlways) == .denied)
        #expect(map({ $0.authorizationDeniedGlobally = true }, authorization: .denied) == .denied)
    }

    @Test func pendingDiagnosticsKeepTheUndecidedStatus() {
        #expect(map({ $0.authorizationRequestInProgress = true }, authorization: .notDetermined) == .notDetermined)
        #expect(map({ $0.insufficientlyInUse = true }, authorization: .notDetermined) == .notDetermined)
        #expect(map({ $0.serviceSessionRequired = true }, authorization: .notDetermined) == .notDetermined)
    }

    @Test func reducedAccuracyIsNotAStatus() {
        #expect(map({ $0.fullAccuracyDenied = true }, authorization: .authorizedAlways) == .authorized)
    }

    #if !os(macOS)
    @Test func alwaysDeniedIsLimitedForTheAlwaysProvider() {
        let status = map(
            { $0.alwaysAuthorizationDenied = true },
            authorization: .authorizedWhenInUse,
            wantsAlways: true
        )
        #expect(status == .limited(.whenInUse))
        // When In Use is all the when-in-use provider asks for.
        #expect(map({ $0.alwaysAuthorizationDenied = true }, authorization: .authorizedWhenInUse) == .authorized)
    }
    #endif

    @Test func alwaysDeniedOverridesAStaleAlwaysStatus() {
        let status = map({ $0.alwaysAuthorizationDenied = true }, authorization: .authorizedAlways, wantsAlways: true)
        #expect(status == .limited(.whenInUse))
    }
}
