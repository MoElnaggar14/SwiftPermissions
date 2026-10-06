import Foundation
#if os(iOS) || os(macOS) || os(visionOS)
import Network
#endif
import SwiftPermissionsCore
#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

/// What one probe found out.
enum LocalNetworkProbeOutcome: Sendable, Equatable {
    /// The probe found its own Bonjour advertisement.
    case authorized
    /// The system blocks local network access for the app.
    case denied
    /// No answer before the timeout, e.g. the prompt is still up.
    case timedOut
    /// Network.framework reported an error that says nothing about the permission.
    case failed(String)
}

/// Triggers the local network prompt and reports what happened. Tests use a fake, so they
/// never touch the network or show a prompt.
protocol LocalNetworkProbing: Sendable {
    /// - Throws: `CancellationError` when the calling task is cancelled.
    func probe(serviceType: String, timeout: TimeInterval) async throws -> LocalNetworkProbeOutcome
}

/// How the probe reads a DNS-SD error code (`dns_sd.h`).
enum DNSServiceErrorKind: Equatable {
    /// `kDNSServiceErr_PolicyDenied`: local network access is denied, or not answered yet.
    case policyDenied
    /// `kDNSServiceErr_NoAuth`: the service type is missing from `NSBonjourServices`.
    case serviceTypeNotDeclared
    case other

    init(code: Int32) {
        switch code {
        case -65570: self = .policyDenied
        case -65555: self = .serviceTypeNotDeclared
        default: self = .other
        }
    }
}

/// Advertises a Bonjour service with `NWListener` and browses for it with `NWBrowser`.
/// Either one shows the prompt the first time.
struct BonjourLocalNetworkProbe: LocalNetworkProbing {
    func probe(serviceType: String, timeout: TimeInterval) async throws -> LocalNetworkProbeOutcome {
        #if os(iOS) || os(macOS) || os(visionOS)
        #if canImport(UIKit) && !os(watchOS)
        // iOS shows no prompt while the app is inactive, so the answer would never come.
        await AppActivation.waitUntilActive()
        #endif
        try Task.checkCancellation()
        let session = BonjourProbeSession(serviceType: serviceType, timeout: timeout)
        let outcome = await withTaskCancellationHandler {
            await session.run()
        } onCancel: {
            session.cancel()
        }
        try Task.checkCancellation()
        return outcome
        #else
        return .failed("This platform has no local network prompt.")
        #endif
    }
}

#if os(iOS) || os(macOS) || os(visionOS)
/// One probe run. Everything is stopped and released when it finishes.
// @unchecked Sendable: every mutable property is only read and written on `queue`, the
// serial queue Network.framework also calls the handlers on.
private final class BonjourProbeSession: @unchecked Sendable {
    private let queue = DispatchQueue(label: "SwiftPermissions.LocalNetworkProbe")
    private let serviceType: String
    private let timeout: TimeInterval
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var timeoutItem: DispatchWorkItem?
    private var continuation: CheckedContinuation<LocalNetworkProbeOutcome, Never>?
    private var finished = false
    private var sawPolicyDenied = false

    init(serviceType: String, timeout: TimeInterval) {
        self.serviceType = serviceType
        self.timeout = timeout
    }

    func run() async -> LocalNetworkProbeOutcome {
        await withCheckedContinuation { continuation in
            queue.async { self.start(continuation) }
        }
    }

    /// Stops the probe early; ``run()`` then returns `.timedOut`.
    func cancel() {
        queue.async { self.finish(.timedOut) }
    }

    private func start(_ continuation: CheckedContinuation<LocalNetworkProbeOutcome, Never>) {
        // Cancelled before it started.
        guard !finished else {
            continuation.resume(returning: .timedOut)
            return
        }
        self.continuation = continuation

        let listener: NWListener
        do {
            listener = try NWListener(using: .tcp)
        } catch {
            finish(.failed("Couldn't create the Bonjour listener: \(error)"))
            return
        }
        listener.service = NWListener.Service(name: UUID().uuidString, type: serviceType)
        listener.newConnectionHandler = { connection in connection.cancel() }
        listener.stateUpdateHandler = { state in
            switch state {
            case let .waiting(error): self.handle(error, fatal: false)
            case let .failed(error): self.handle(error, fatal: true)
            default: break
            }
        }
        self.listener = listener

        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: NWParameters())
        browser.browseResultsChangedHandler = { results, _ in
            // Seeing our own advertisement proves the local network is reachable.
            if !results.isEmpty { self.finish(.authorized) }
        }
        browser.stateUpdateHandler = { state in
            switch state {
            case let .waiting(error): self.handle(error, fatal: false)
            case let .failed(error): self.handle(error, fatal: true)
            default: break
            }
        }
        self.browser = browser

        let timeoutItem = DispatchWorkItem {
            self.finish(self.sawPolicyDenied ? .denied : .timedOut)
        }
        self.timeoutItem = timeoutItem
        listener.start(queue: queue)
        browser.start(queue: queue)
        queue.asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
    }

    private func handle(_ error: NWError, fatal: Bool) {
        guard !finished else { return }
        var kind = DNSServiceErrorKind.other
        if case let .dns(code) = error { kind = DNSServiceErrorKind(code: Int32(code)) }
        switch kind {
        case .policyDenied:
            policyDenied()
        case .serviceTypeNotDeclared:
            finish(.failed("Add \(serviceType) to NSBonjourServices in Info.plist."))
        case .other:
            // `.waiting` is transient (no network yet); only a failure ends the probe.
            if fatal { finish(.failed(String(describing: error))) }
        }
    }

    /// The error is also reported while the prompt is still up, so on iOS it's only trusted
    /// once the prompt has closed and the app has been active for a moment. Elsewhere it
    /// decides the outcome when the timeout fires.
    private func policyDenied() {
        guard !sawPolicyDenied else { return }
        sawPolicyDenied = true
        #if canImport(UIKit) && !os(watchOS)
        Task { @MainActor in
            await Self.waitUntilPromptClosed()
            self.queue.async { self.finish(.denied) }
        }
        #endif
    }

    private func finish(_ outcome: LocalNetworkProbeOutcome) {
        guard !finished else { return }
        finished = true
        timeoutItem?.cancel()
        timeoutItem = nil
        // Clearing the handlers breaks the retain cycles between the session and its objects.
        listener?.stateUpdateHandler = nil
        listener?.cancel()
        listener = nil
        browser?.stateUpdateHandler = nil
        browser?.browseResultsChangedHandler = nil
        browser?.cancel()
        browser = nil
        continuation?.resume(returning: outcome)
        continuation = nil
    }

    #if canImport(UIKit) && !os(watchOS)
    /// Returns once the app is active and has stayed active for the grace period, which
    /// leaves time for the browse results to arrive after the user tapped Allow.
    @MainActor
    private static func waitUntilPromptClosed() async {
        repeat {
            await AppActivation.waitUntilActive()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        } while !isActive
    }

    @MainActor
    private static var isActive: Bool {
        // No shared application in an app extension: treat it as active.
        guard let application = AppActivation.sharedApplication else { return true }
        return application.applicationState == .active
    }
    #endif
}
#endif
