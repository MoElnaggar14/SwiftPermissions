import Foundation
import SwiftPermissionsCore
import XCTest

final class DomainTests: XCTestCase {
    func testGrantedStatuses() {
        let granted = PermissionStatus.allCases.filter(\.isGranted)
        XCTAssertEqual(Set(granted), [.authorized, .limited, .provisional])
    }

    func testOnlyNotDeterminedCanBeRequested() {
        XCTAssertEqual(PermissionStatus.allCases.filter(\.canRequest), [.notDetermined])
    }

    func testOnlyDeniedRequiresSettings() {
        XCTAssertEqual(PermissionStatus.allCases.filter(\.requiresSettings), [.denied])
    }

    func testPermissionIdentityIgnoresDisplayName() {
        XCTAssertEqual(Permission("camera", displayName: "Kamera"), .camera)
        XCTAssertEqual(Set([Permission.camera, Permission("camera")]).count, 1)
    }

    func testRawValueInitResolvesBuiltInDisplayName() {
        XCTAssertEqual(Permission(rawValue: "camera").displayName, "Camera")
        XCTAssertEqual(Permission(rawValue: "custom").displayName, "custom")
    }

    func testCodableRoundTrip() throws {
        let original: [Permission: PermissionStatus] = [.camera: .limited, Permission("custom"): .denied]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([Permission: PermissionStatus].self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.keys.first { $0 == .camera }?.displayName, "Camera")
    }

    func testBuiltInPermissionsAreUnique() {
        XCTAssertEqual(Set(Permission.builtIn).count, Permission.builtIn.count)
    }

    func testBatchResultAllGranted() {
        XCTAssertTrue(PermissionBatchResult(statuses: [.camera: .authorized, .photoLibrary: .limited]).allGranted)
        XCTAssertFalse(PermissionBatchResult(statuses: [.camera: .authorized, .microphone: .denied]).allGranted)
        XCTAssertFalse(
            PermissionBatchResult(
                statuses: [.camera: .authorized],
                failures: [.microphone: .providerNotRegistered(.microphone)]
            ).allGranted
        )
    }

    func testBatchResultNotGranted() {
        let result = PermissionBatchResult(
            statuses: [.camera: .authorized, .microphone: .denied],
            failures: [.contacts: .providerNotRegistered(.contacts)]
        )
        XCTAssertEqual(result.notGranted, [.microphone, .contacts])
    }

    func testInfoPlistIgnoresBlankValues() {
        let plist = InfoPlist(["NSCameraUsageDescription": "Scan receipts", "NSMicrophoneUsageDescription": "  "])
        XCTAssertEqual(plist.usageDescription(forKey: "NSCameraUsageDescription"), "Scan receipts")
        XCTAssertNil(plist.usageDescription(forKey: "NSMicrophoneUsageDescription"))
        XCTAssertNil(plist.usageDescription(forKey: "NSContactsUsageDescription"))
    }

    func testErrorExposesPermission() {
        XCTAssertEqual(PermissionError.missingUsageDescription(.camera, keys: ["K"]).permission, .camera)
        XCTAssertEqual(PermissionError.requestFailed(.contacts, reason: "x").permission, .contacts)
    }

    func testRegistryReplacesProviderForSamePermission() async {
        let first = StubLike(permission: .camera, value: .denied)
        let second = StubLike(permission: .camera, value: .authorized)
        let registry = PermissionProviderRegistry([first]).registering(second)
        XCTAssertEqual(registry.permissions, [.camera])
        let status = await registry.provider(for: .camera)?.status()
        XCTAssertEqual(status, .authorized)
    }

    func testStandardRegistryNeverIncludesHealth() {
        XCTAssertFalse(PermissionProviderRegistry.standard.permissions.contains(.health))
        XCTAssertTrue(PermissionProviderRegistry.standard.permissions.contains(.notifications))
    }
}

private struct StubLike: PermissionProvider {
    let permission: Permission
    let value: PermissionStatus
    func status() async -> PermissionStatus { value }
    func request() async throws -> PermissionStatus { value }
}
