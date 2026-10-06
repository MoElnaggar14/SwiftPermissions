@testable import SwiftPermissionsCore
import Testing
#if os(iOS)
@testable import SwiftPermissionsAlarms
#if canImport(AlarmKit) && !targetEnvironment(macCatalyst)
import AlarmKit
#endif
#endif

@Suite("Alarms permission")
struct AlarmsPermissionTests {
    @Test func providerNotRegisteredNamesTheProduct() {
        let hint = Permission.alarms.registrationHint
        #expect(hint?.product == "SwiftPermissionsAlarms")
        #expect(hint?.registration == ".alarms")
        #expect(Permission.builtIn.contains(.alarms))
    }

    #if os(iOS)
    @Test func requiresTheAlarmKitUsageDescription() {
        #expect(AlarmsPermissionProvider().requiredUsageDescriptionKeys == ["NSAlarmKitUsageDescription"])
    }

    @Test func statusIsUnavailableBeforeIOS26() async {
        if #available(iOS 26.0, *) { return }   // covered by the mapping test
        #expect(await AlarmsPermissionProvider().status() == .unavailable)
    }
    #endif

    #if os(iOS) && canImport(AlarmKit) && !targetEnvironment(macCatalyst)
    @Test func authorizationStatesMapOntoPermissionStatus() {
        guard #available(iOS 26.0, *) else { return }
        #expect(AlarmsPermissionProvider.map(.notDetermined) == .notDetermined)
        #expect(AlarmsPermissionProvider.map(.denied) == .denied)
        #expect(AlarmsPermissionProvider.map(.authorized) == .authorized)
    }
    #endif
}
