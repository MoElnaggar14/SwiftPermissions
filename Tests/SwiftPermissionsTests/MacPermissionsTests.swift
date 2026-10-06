import Foundation
@testable import SwiftPermissionsCore
import Testing
#if os(macOS)
@testable import SwiftPermissionsAccessibility
@testable import SwiftPermissionsInputMonitoring
@testable import SwiftPermissionsScreenRecording
#endif

@Suite("macOS permissions")
struct MacPermissionsTests {
    @Test func providerNotRegisteredNamesTheProduct() {
        let hints: [(Permission, String, String)] = [
            (.screenRecording, "SwiftPermissionsScreenRecording", ".screenRecording"),
            (.accessibility, "SwiftPermissionsAccessibility", ".accessibility"),
            (.inputMonitoring, "SwiftPermissionsInputMonitoring", ".inputMonitoring")
        ]
        for (permission, product, registration) in hints {
            #expect(permission.registrationHint?.product == product)
            #expect(permission.registrationHint?.registration == registration)
            #expect(Permission.builtIn.contains(permission))
        }
    }

    #if os(macOS)
    @Test func noUsageDescriptionsAreNeeded() {
        #expect(ScreenRecordingPermissionProvider(access: StubScreenCapture()).requiredUsageDescriptionKeys.isEmpty)
        #expect(AccessibilityPermissionProvider(trust: StubAccessibilityTrust()).requiredUsageDescriptionKeys.isEmpty)
        #expect(InputMonitoringPermissionProvider(access: StubInputMonitoring()).requiredUsageDescriptionKeys.isEmpty)
    }

    @Test @MainActor
    func settingsOpenTheMatchingPrivacyPane() {
        let anchors: [Permission: String] = [
            .screenRecording: "Privacy_ScreenCapture",
            .accessibility: "Privacy_Accessibility",
            .inputMonitoring: "Privacy_ListenEvent"
        ]
        for (permission, anchor) in anchors {
            #expect(AppSettings.url(for: permission)?.absoluteString.hasSuffix("?\(anchor)") == true)
        }
    }

    // MARK: Screen Recording

    @Test func screenRecordingIsNotDeterminedUntilAsked() async throws {
        let provider = ScreenRecordingPermissionProvider(access: StubScreenCapture())
        #expect(await provider.status() == .notDetermined)
        #expect(try await provider.request() == .denied)
        // macOS can't tell "declined" from "never asked"; the provider remembers it asked.
        #expect(await provider.status() == .denied)
    }

    @Test func screenRecordingGranted() async throws {
        let granted = ScreenRecordingPermissionProvider(access: StubScreenCapture(granted: true))
        #expect(await granted.status() == .authorized)
        let grantedOnRequest = ScreenRecordingPermissionProvider(access: StubScreenCapture(grantsOnRequest: true))
        #expect(try await grantedOnRequest.request() == .authorized)
    }

    @Test func screenRecordingThroughTheManagerPromptsOnce() async throws {
        let access = StubScreenCapture()
        let manager = PermissionManager(
            permissions: [PermissionRegistration(ScreenRecordingPermissionProvider(access: access))],
            usageDescriptions: InfoPlist([:])
        )
        #expect(try await manager.request(.screenRecording) == .denied)
        #expect(try await manager.request(.screenRecording) == .denied)
        #expect(access.requests.value == 1)
    }

    // MARK: Accessibility

    @Test func accessibilityIsNotDeterminedUntilAsked() async throws {
        let provider = AccessibilityPermissionProvider(trust: StubAccessibilityTrust(trusted: false))
        #expect(await provider.status() == .notDetermined)
        #expect(try await provider.request() == .denied)
        #expect(await provider.status() == .denied)
    }

    @Test func accessibilityTrusted() async {
        let provider = AccessibilityPermissionProvider(trust: StubAccessibilityTrust(trusted: true))
        #expect(await provider.status() == .authorized)
    }

    @Test func accessibilityGrantedAfterAskingReadsAuthorized() {
        #expect(AccessibilityPermissionProvider.map(trusted: true, requested: true) == .authorized)
        #expect(AccessibilityPermissionProvider.map(trusted: true, requested: false) == .authorized)
    }

    // MARK: Input Monitoring

    @Test func inputMonitoringAccessMapsOntoPermissionStatus() {
        #expect(InputMonitoringPermissionProvider.map(.granted) == .authorized)
        #expect(InputMonitoringPermissionProvider.map(.denied) == .denied)
        #expect(InputMonitoringPermissionProvider.map(.unknown) == .notDetermined)
    }

    @Test func inputMonitoringRequest() async throws {
        let granted = InputMonitoringPermissionProvider(access: StubInputMonitoring(grantsOnRequest: true))
        #expect(try await granted.request() == .authorized)

        // Still "unknown" right after asking means the user hasn't allowed it.
        let stillUnknown = InputMonitoringPermissionProvider(access: StubInputMonitoring(state: .unknown))
        #expect(try await stillUnknown.request() == .denied)

        let denied = InputMonitoringPermissionProvider(access: StubInputMonitoring(state: .denied))
        #expect(await denied.status() == .denied)
        #expect(try await denied.request() == .denied)
    }
    #endif
}

#if os(macOS)
/// A counter tests can read after handing a stub to a provider.
private final class Counter: @unchecked Sendable {
    // @unchecked: only touched while holding `lock`.
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}

private struct StubScreenCapture: ScreenCaptureAccess {
    var granted = false
    var grantsOnRequest = false
    let requests = Counter()

    func preflight() -> Bool { granted }

    func request() -> Bool {
        requests.increment()
        return granted || grantsOnRequest
    }
}

private struct StubAccessibilityTrust: AccessibilityTrust {
    var trusted = false

    func isTrusted() -> Bool { trusted }
    func promptForTrust() -> Bool { trusted }
}

private struct StubInputMonitoring: InputMonitoringAccess {
    var state = InputMonitoringAccessState.unknown
    var grantsOnRequest = false

    func check() -> InputMonitoringAccessState { state }
    func request() -> Bool { state == .granted || grantsOnRequest }
}
#endif
