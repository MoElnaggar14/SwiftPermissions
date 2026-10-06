import CoreBluetooth
import Foundation
@testable import SwiftPermissionsBluetooth
import SwiftPermissionsCore
import Testing

@Suite("Bluetooth permission")
struct BluetoothPermissionTests {
    @Test func authorizationMapsOntoPermissionStatus() {
        #expect(BluetoothPermissionProvider.map(.notDetermined, usesAccessorySetupKit: false) == .notDetermined)
        #expect(BluetoothPermissionProvider.map(.denied, usesAccessorySetupKit: false) == .denied)
        #expect(BluetoothPermissionProvider.map(.restricted, usesAccessorySetupKit: false) == .restricted)
        #expect(BluetoothPermissionProvider.map(.allowedAlways, usesAccessorySetupKit: false) == .authorized)
    }

    // MARK: - AccessorySetupKit

    @Test func accessorySetupKitReportsNotDeterminedAsUnavailable() {
        let status = BluetoothPermissionProvider.map(.notDetermined, usesAccessorySetupKit: true)
        #expect(status == .unavailable)
        #expect(!status.canRequest)
        #expect(!status.requiresSettings)
    }

    @Test func accessorySetupKitKeepsARealDecision() {
        #expect(BluetoothPermissionProvider.map(.denied, usesAccessorySetupKit: true) == .denied)
        #expect(BluetoothPermissionProvider.map(.restricted, usesAccessorySetupKit: true) == .restricted)
        #expect(BluetoothPermissionProvider.map(.allowedAlways, usesAccessorySetupKit: true) == .authorized)
    }

    @Test func onlyTheBluetoothValueCounts() {
        #expect(BluetoothPermissionProvider.declaresBluetooth(["Bluetooth"]))
        #expect(BluetoothPermissionProvider.declaresBluetooth(["WiFi", "Bluetooth"]))
        #expect(!BluetoothPermissionProvider.declaresBluetooth(["WiFi"]))
        #expect(!BluetoothPermissionProvider.declaresBluetooth([]))
    }

    @Test func readsTheAccessorySetupKitKey() {
        #expect(BluetoothPermissionProvider.accessorySetupKitSupportsKey == "NSAccessorySetupKitSupports")
        // The test runner's Info.plist doesn't opt into AccessorySetupKit.
        #expect(BluetoothPermissionProvider.declaredAccessorySetupKitSupports(in: .main).isEmpty)
        #expect(!BluetoothPermissionProvider().usesAccessorySetupKit)
    }

    @Test func usesTheInjectedInfoPlistValues() {
        let wifiOnly = BluetoothPermissionProvider(accessorySetupKitSupports: { ["WiFi"] })
        #expect(!wifiOnly.usesAccessorySetupKit)

        let bluetooth = BluetoothPermissionProvider(accessorySetupKitSupports: { ["Bluetooth"] })
        #expect(bluetooth.usesAccessorySetupKit == Self.platformHasAccessorySetupKit)
    }

    #if os(iOS) && !targetEnvironment(macCatalyst)
    /// Creating a `CBCentralManager` here would terminate the test runner, which has no
    /// `NSBluetoothAlwaysUsageDescription`, so this also proves that no prompt is attempted.
    @Test func requestShowsNoPromptUnderAccessorySetupKit() async throws {
        guard #available(iOS 18.0, *) else { return }
        let provider = BluetoothPermissionProvider(accessorySetupKitSupports: { ["Bluetooth"] })
        let status = await provider.status()
        #expect(status != .notDetermined)
        let requested = try await provider.request()
        #expect(requested == status)
    }
    #endif

    private static var platformHasAccessorySetupKit: Bool {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 18.0, *) { return true }
        #endif
        return false
    }
}
