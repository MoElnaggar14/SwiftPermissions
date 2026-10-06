import Foundation
import SwiftPermissionsCore

/// Local network access: finding and talking to devices on the user's network.
///
/// No system API reads or requests this permission. iOS shows the prompt the first time
/// the app browses for or advertises a Bonjour service, and the answer only shows in how
/// networking behaves afterwards. So this provider works like this:
///
/// - ``request()`` runs a short Bonjour probe: it advertises ``serviceType`` and browses
///   for it at the same time. Finding its own advertisement means
///   ``PermissionStatus/authorized``. A "policy denied" error that is still there after
///   the prompt has closed means ``PermissionStatus/denied``. If neither happens within
///   ``timeout``, the status stays ``PermissionStatus/notDetermined``.
/// - ``status()`` can't be read without probing, so it's ``PermissionStatus/notDetermined``
///   until a request has run on this provider, and then the result of the last request.
///   After a relaunch it's `.notDetermined` again. Requesting then shows no prompt if the
///   user already answered, and returns the answer in a moment.
///
/// Changes made in Settings while the app runs are seen on the next launch.
///
/// The prompt exists on iOS 14+, visionOS and macOS 15+. On tvOS and older macOS versions
/// nothing gates the local network, so the status is ``PermissionStatus/authorized``. On
/// watchOS it's ``PermissionStatus/unavailable``.
///
/// The Info.plist needs `NSLocalNetworkUsageDescription`, and `NSBonjourServices` must list
/// ``serviceType``:
///
/// ```xml
/// <key>NSBonjourServices</key>
/// <array>
///     <string>_swiftperms._tcp</string>
/// </array>
/// ```
public struct LocalNetworkPermissionProvider: PermissionProvider {
    /// The Bonjour service type the probe advertises and browses for by default.
    public static let defaultServiceType = "_swiftperms._tcp"

    public let permission = Permission.localNetwork
    /// The Bonjour service type the probe uses. `NSBonjourServices` must list it.
    public let serviceType: String
    /// How long ``request()`` waits for an answer, in seconds, before giving up.
    public let timeout: TimeInterval

    private let usageDescriptions: any UsageDescriptionSource
    private let probe: any LocalNetworkProbing
    private let platform: LocalNetworkPlatform
    private let lastResult = LastProbeResult()

    /// - Parameters:
    ///   - serviceType: The Bonjour service type to probe, such as `_myapp._tcp`. Use one
    ///     your app already lists in `NSBonjourServices`, or keep the default and add it.
    ///   - timeout: How long a request waits for the user's answer, in seconds.
    ///   - usageDescriptions: Where ``request()`` checks that `NSBonjourServices` lists
    ///     `serviceType`. Defaults to the main bundle.
    public init(
        serviceType: String = LocalNetworkPermissionProvider.defaultServiceType,
        timeout: TimeInterval = 60,
        usageDescriptions: any UsageDescriptionSource = InfoPlist.main
    ) {
        self.init(
            serviceType: serviceType,
            timeout: timeout,
            usageDescriptions: usageDescriptions,
            probe: BonjourLocalNetworkProbe(),
            platform: .current
        )
    }

    init(
        serviceType: String,
        timeout: TimeInterval,
        usageDescriptions: any UsageDescriptionSource,
        probe: any LocalNetworkProbing,
        platform: LocalNetworkPlatform
    ) {
        self.serviceType = serviceType
        self.timeout = timeout
        self.usageDescriptions = usageDescriptions
        self.probe = probe
        self.platform = platform
    }

    /// `NSBonjourServices` is an array; ``InfoPlist`` reads it as its entries joined by newlines.
    public var requiredUsageDescriptionKeys: [String] {
        platform == .prompts ? ["NSLocalNetworkUsageDescription", "NSBonjourServices"] : []
    }

    public func status() async -> PermissionStatus {
        switch platform {
        case .prompts: return await lastResult.value ?? .notDetermined
        case .unrestricted: return .authorized
        case .unsupported: return .unavailable
        }
    }

    /// Runs the Bonjour probe, which shows the prompt if the user hasn't answered yet.
    ///
    /// - Throws: ``PermissionError/requestFailed(_:reason:)`` when `NSBonjourServices`
    ///   doesn't list ``serviceType`` or the probe fails, and `CancellationError` when the
    ///   calling task is cancelled.
    public func request() async throws -> PermissionStatus {
        guard platform == .prompts else { return await status() }
        guard Self.lists(serviceType, in: usageDescriptions) else {
            throw PermissionError.requestFailed(
                permission,
                reason: "Add \(serviceType) to NSBonjourServices in Info.plist."
            )
        }
        switch try await probe.probe(serviceType: serviceType, timeout: timeout) {
        case .authorized:
            await lastResult.set(.authorized)
            return .authorized
        case .denied:
            await lastResult.set(.denied)
            return .denied
        case .timedOut:
            return await status()
        case let .failed(reason):
            throw PermissionError.requestFailed(permission, reason: reason)
        }
    }

    /// Whether the `NSBonjourServices` entries in `source` include `serviceType`.
    static func lists(_ serviceType: String, in source: any UsageDescriptionSource) -> Bool {
        guard let services = source.usageDescription(forKey: "NSBonjourServices") else { return false }
        let wanted = normalized(serviceType)
        return services.split(whereSeparator: \.isNewline).contains { normalized(String($0)) == wanted }
    }

    private static func normalized(_ serviceType: String) -> String {
        var type = serviceType.trimmingCharacters(in: .whitespaces).lowercased()
        if type.hasSuffix(".") { type.removeLast() }
        return type
    }
}

/// Whether the platform asks the user for local network access.
enum LocalNetworkPlatform: Sendable, Equatable {
    /// The system shows a prompt (iOS 14+, visionOS, macOS 15+).
    case prompts
    /// Local network access needs no permission (tvOS, macOS before 15).
    case unrestricted
    /// Apps can't use the local network this way (watchOS).
    case unsupported

    static var current: LocalNetworkPlatform {
        #if os(iOS) || os(visionOS)
        return .prompts
        #elseif os(macOS)
        if #available(macOS 15.0, *) { return .prompts }
        return .unrestricted
        #elseif os(tvOS)
        return .unrestricted
        #else
        return .unsupported
        #endif
    }
}

/// The outcome of the last probe, shared by copies of the provider.
private actor LastProbeResult {
    private(set) var value: PermissionStatus?

    func set(_ status: PermissionStatus) {
        value = status
    }
}

public extension PermissionRegistration {
    /// Local network access, found out with a Bonjour probe. Needs `NSLocalNetworkUsageDescription`
    /// and `_swiftperms._tcp` in `NSBonjourServices`.
    static var localNetwork: PermissionRegistration {
        PermissionRegistration(LocalNetworkPermissionProvider())
    }

    /// Local network access, probing `serviceType`. Needs `NSLocalNetworkUsageDescription`, and
    /// `NSBonjourServices` must list `serviceType`.
    static func localNetwork(serviceType: String) -> PermissionRegistration {
        PermissionRegistration(LocalNetworkPermissionProvider(serviceType: serviceType))
    }
}
