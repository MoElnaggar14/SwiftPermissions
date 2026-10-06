import Foundation
@testable import SwiftPermissionsCore
@testable import SwiftPermissionsLocalNetwork
import Testing

/// Returns the queued outcomes in order, then `.timedOut`. Never touches the network.
private actor FakeProbe: LocalNetworkProbing {
    private var outcomes: [LocalNetworkProbeOutcome]
    private(set) var probedServiceTypes: [String] = []

    init(_ outcomes: LocalNetworkProbeOutcome...) {
        self.outcomes = outcomes
    }

    func probe(serviceType: String, timeout: TimeInterval) async throws -> LocalNetworkProbeOutcome {
        probedServiceTypes.append(serviceType)
        return outcomes.isEmpty ? .timedOut : outcomes.removeFirst()
    }
}

/// Waits until the calling task is cancelled.
private struct HangingProbe: LocalNetworkProbing {
    func probe(serviceType: String, timeout: TimeInterval) async throws -> LocalNetworkProbeOutcome {
        try await Task.sleep(nanoseconds: 60_000_000_000)
        return .authorized
    }
}

private let fullInfoPlist = InfoPlist([
    "NSLocalNetworkUsageDescription": "Find speakers on your network.",
    "NSBonjourServices": "_other._tcp\n_swiftperms._tcp"
])

private func makeProvider(
    probe: any LocalNetworkProbing,
    platform: LocalNetworkPlatform = .prompts,
    serviceType: String = LocalNetworkPermissionProvider.defaultServiceType,
    infoPlist: InfoPlist = fullInfoPlist,
    history: any PermissionRequestHistory = InMemoryRequestHistory()
) -> LocalNetworkPermissionProvider {
    LocalNetworkPermissionProvider(
        serviceType: serviceType,
        timeout: 1,
        usageDescriptions: infoPlist,
        probe: probe,
        platform: platform,
        history: history
    )
}

@Suite("Local network permission")
struct LocalNetworkPermissionTests {
    @Test func providerNotRegisteredNamesTheProduct() {
        let hint = Permission.localNetwork.registrationHint
        #expect(hint?.product == "SwiftPermissionsLocalNetwork")
        #expect(hint?.registration == ".localNetwork")
        #expect(Permission.builtIn.contains(.localNetwork))
    }

    @Test func requiresTheUsageDescriptionAndBonjourServices() {
        let provider = makeProvider(probe: FakeProbe())
        #expect(provider.requiredUsageDescriptionKeys == ["NSLocalNetworkUsageDescription", "NSBonjourServices"])
        #expect(makeProvider(probe: FakeProbe(), platform: .unrestricted).requiredUsageDescriptionKeys.isEmpty)
    }

    @Test func statusIsNotDeterminedUntilARequestRan() async throws {
        let probe = FakeProbe(.authorized)
        let provider = makeProvider(probe: probe)
        #expect(await provider.status() == .notDetermined)
        #expect(await probe.probedServiceTypes.isEmpty)   // reading the status never probes

        #expect(try await provider.request() == .authorized)
        #expect(await provider.status() == .authorized)
        #expect(await probe.probedServiceTypes == ["_swiftperms._tcp"])
    }

    @Test func policyDeniedIsDenied() async throws {
        let provider = makeProvider(probe: FakeProbe(.denied))
        #expect(try await provider.request() == .denied)
        #expect(await provider.status() == .denied)
    }

    @Test func timeoutKeepsTheStatusUndetermined() async throws {
        let provider = makeProvider(probe: FakeProbe(.timedOut, .authorized))
        #expect(try await provider.request() == .notDetermined)
        #expect(await provider.status() == .notDetermined)
        // Still requestable, and the next probe can succeed.
        #expect(provider.canRequest(from: .notDetermined))
        #expect(try await provider.request() == .authorized)
    }

    @Test func probeFailureThrows() async {
        let provider = makeProvider(probe: FakeProbe(.failed("boom")))
        await #expect(throws: PermissionError.requestFailed(.localNetwork, reason: "boom")) {
            try await provider.request()
        }
        #expect(await provider.status() == .notDetermined)
    }

    @Test func serviceTypeMissingFromBonjourServicesThrowsWithoutProbing() async {
        let probe = FakeProbe(.authorized)
        let provider = makeProvider(probe: probe, serviceType: "_speaker._tcp")
        await #expect(throws: PermissionError.requestFailed(
            .localNetwork,
            reason: "Add _speaker._tcp to NSBonjourServices in Info.plist."
        )) {
            try await provider.request()
        }
        #expect(await probe.probedServiceTypes.isEmpty)
    }

    @Test func bonjourServicesMatchIgnoresCaseAndTrailingDot() {
        let plist = InfoPlist(["NSBonjourServices": " _Speaker._TCP. \n_other._udp"])
        #expect(LocalNetworkPermissionProvider.lists("_speaker._tcp", in: plist))
        #expect(LocalNetworkPermissionProvider.lists("_other._udp.", in: plist))
        #expect(!LocalNetworkPermissionProvider.lists("_swiftperms._tcp", in: plist))
        #expect(!LocalNetworkPermissionProvider.lists("_swiftperms._tcp", in: InfoPlist([:])))
    }

    @Test func cancellingTheRequestStopsTheProbe() async {
        let provider = makeProvider(probe: HangingProbe())
        let task = Task { try await provider.request() }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await provider.status() == .notDetermined)
    }

    @Test func platformsWithoutAPromptNeverProbe() async throws {
        let probe = FakeProbe(.denied)
        let open = makeProvider(probe: probe, platform: .unrestricted)
        #expect(await open.status() == .authorized)
        #expect(try await open.request() == .authorized)

        let unsupported = makeProvider(probe: probe, platform: .unsupported)
        #expect(await unsupported.status() == .unavailable)
        #expect(try await unsupported.request() == .unavailable)
        #expect(await probe.probedServiceTypes.isEmpty)
    }

    @Test func managerRequiresBonjourServicesInInfoPlist() async {
        let provider = makeProvider(probe: FakeProbe(.authorized))
        let manager = PermissionManager(
            permissions: [.provider(provider)],
            usageDescriptions: InfoPlist(["NSLocalNetworkUsageDescription": "Find speakers on your network."])
        )
        await #expect(throws: PermissionError.missingUsageDescription(.localNetwork, keys: ["NSBonjourServices"])) {
            try await manager.request(.localNetwork)
        }
    }

    @Test func managerRequestsThroughTheProbe() async throws {
        let manager = PermissionManager(
            permissions: [.provider(makeProvider(probe: FakeProbe(.authorized)))],
            usageDescriptions: fullInfoPlist
        )
        #expect(await manager.status(of: .localNetwork) == .notDetermined)
        #expect(try await manager.request(.localNetwork) == .authorized)
        #expect(await manager.status(of: .localNetwork) == .authorized)
    }

    // MARK: History

    @Test func theDefaultHistoryForgetsOnRelaunch() async throws {
        #expect(try await makeProvider(probe: FakeProbe(.denied)).request() == .denied)
        // A relaunch builds a new provider with a new in-memory history.
        #expect(await makeProvider(probe: FakeProbe()).status() == .notDetermined)
    }

    @Test func requestsAreRecordedInTheHistory() async throws {
        let history = InMemoryRequestHistory()
        #expect(try await makeProvider(probe: FakeProbe(.authorized), history: history).request() == .authorized)
        #expect(history.hasRequested(.localNetwork))
        #expect(history.lastResult(.localNetwork) == .authorized)
    }

    @Test func timeoutsAndFailuresAreNotRecorded() async throws {
        let history = InMemoryRequestHistory()
        let provider = makeProvider(probe: FakeProbe(.timedOut, .failed("boom")), history: history)
        #expect(try await provider.request() == .notDetermined)
        _ = try? await provider.request()
        #expect(history.lastResult(.localNetwork) == nil)
    }

    @Test func aPersistentHistoryKeepsTheLastResultAcrossRelaunches() async throws {
        let scratch = try ScratchDefaults()
        defer { scratch.remove() }

        let before = makeProvider(
            probe: FakeProbe(.denied),
            history: UserDefaultsRequestHistory(defaults: scratch.defaults)
        )
        #expect(try await before.request() == .denied)

        // A relaunch: a new provider and a new history over the same defaults.
        let probe = FakeProbe()
        let after = makeProvider(probe: probe, history: UserDefaultsRequestHistory(defaults: scratch.defaults))
        let status = await after.status()
        #expect(status == .denied)
        #expect(!after.canRequest(from: status))
        #expect(await probe.probedServiceTypes.isEmpty)
    }

    @Test func aNewRequestReplacesThePersistedResult() async throws {
        let history = InMemoryRequestHistory()
        history.recordResult(.denied, for: .localNetwork)
        let provider = makeProvider(probe: FakeProbe(.authorized), history: history)
        #expect(await provider.status() == .denied)
        #expect(try await provider.request() == .authorized)
        #expect(await provider.status() == .authorized)
    }

    @Test func dnsServiceErrorCodes() {
        #expect(DNSServiceErrorKind(code: -65570) == .policyDenied)
        #expect(DNSServiceErrorKind(code: -65555) == .serviceTypeNotDeclared)
        #expect(DNSServiceErrorKind(code: -65537) == .other)
    }

    @Test func infoPlistReadsStringArraysAsLines() {
        #expect(InfoPlist.stringValue(["_a._tcp", "_b._tcp"]) == "_a._tcp\n_b._tcp")
        #expect(InfoPlist.stringValue("text") == "text")
        #expect(InfoPlist.stringValue(42) == nil)
        #expect(InfoPlist(["NSBonjourServices": ""]).usageDescription(forKey: "NSBonjourServices") == nil)
    }
}
