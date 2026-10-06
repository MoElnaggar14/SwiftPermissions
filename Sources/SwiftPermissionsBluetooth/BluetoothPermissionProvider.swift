@preconcurrency import CoreBluetooth
import Foundation
import SwiftPermissionsCore

/// Bluetooth access. The prompt is shown the first time a `CBCentralManager` is created.
///
/// ## AccessorySetupKit
///
/// On iOS 18 and later, an app whose Info.plist lists `Bluetooth` under
/// `NSAccessorySetupKitSupports` never gets the Bluetooth prompt: the user grants
/// access per accessory in the AccessorySetupKit picker instead, and
/// `CBManager.authorization` stays `.notDetermined`, before and after pairing. In such
/// an app this provider reports ``PermissionStatus/unavailable`` instead of a
/// `.notDetermined` that no prompt can ever resolve, and ``request()`` never creates a
/// `CBCentralManager`. Use `ASAccessorySession.accessories` to know what the app can reach.
public struct BluetoothPermissionProvider: PermissionProvider {
    public let permission = Permission.bluetooth

    /// Required on every platform, macOS 11+ included: TCC terminates the app if
    /// a `CBCentralManager` is created without it.
    public let requiredUsageDescriptionKeys = ["NSBluetoothAlwaysUsageDescription"]

    /// The values of the `NSAccessorySetupKitSupports` Info.plist array. Injected in tests.
    private let accessorySetupKitSupports: @Sendable () -> [String]

    public init() {
        self.init(accessorySetupKitSupports: { Self.declaredAccessorySetupKitSupports(in: .main) })
    }

    internal init(accessorySetupKitSupports: @escaping @Sendable () -> [String]) {
        self.accessorySetupKitSupports = accessorySetupKitSupports
    }

    public func status() async -> PermissionStatus {
        Self.map(CBManager.authorization, usesAccessorySetupKit: usesAccessorySetupKit)
    }

    public func request() async throws -> PermissionStatus {
        // No prompt can appear, and the delegate would wait for an answer forever.
        if usesAccessorySetupKit { return await status() }
        let request = await BluetoothAuthorizationRequest()
        await request.run()
        return await status()
    }

    // MARK: - AccessorySetupKit

    /// The Info.plist key that opts an app into AccessorySetupKit.
    internal static let accessorySetupKitSupportsKey = "NSAccessorySetupKitSupports"

    /// Whether the system grants Bluetooth per accessory through AccessorySetupKit
    /// instead of showing the Bluetooth prompt. iOS 18+ only; Mac Catalyst has no
    /// AccessorySetupKit, and a watchOS companion app still gets the prompt.
    internal var usesAccessorySetupKit: Bool {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 18.0, *) {
            return Self.declaresBluetooth(accessorySetupKitSupports())
        }
        #endif
        return false
    }

    internal static func declaredAccessorySetupKitSupports(in bundle: Bundle) -> [String] {
        bundle.object(forInfoDictionaryKey: accessorySetupKitSupportsKey) as? [String] ?? []
    }

    /// Whether the `NSAccessorySetupKitSupports` values include Bluetooth.
    internal static func declaresBluetooth(_ supports: [String]) -> Bool {
        supports.contains("Bluetooth")
    }

    // MARK: - Mapping

    /// Under AccessorySetupKit `.notDetermined` can't be resolved by a prompt, so it's
    /// reported as `.unavailable`. Any other value (a `.restricted` device, say) is kept.
    internal static func map(
        _ authorization: CBManagerAuthorization,
        usesAccessorySetupKit: Bool
    ) -> PermissionStatus {
        if usesAccessorySetupKit, authorization == .notDetermined { return .unavailable }
        return map(authorization)
    }

    static func map(_ authorization: CBManagerAuthorization) -> PermissionStatus {
        switch authorization {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .restricted: .restricted
        case .allowedAlways: .authorized
        @unknown default: .denied
        }
    }
}

/// Creates a central manager to trigger the prompt and waits until the user has answered.
@MainActor
private final class BluetoothAuthorizationRequest: NSObject, @preconcurrency CBCentralManagerDelegate {
    private var manager: CBCentralManager?
    private var continuation: CheckedContinuation<Void, Never>?

    func run() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager = CBCentralManager(
                delegate: self,
                queue: .main,
                options: [CBCentralManagerOptionShowPowerAlertKey: false]
            )
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard CBManager.authorization != .notDetermined, let continuation else { return }
        self.continuation = nil
        manager?.delegate = nil
        manager = nil
        continuation.resume()
    }
}

public extension PermissionRegistration {
    /// Bluetooth. Needs `NSBluetoothAlwaysUsageDescription`. In an AccessorySetupKit app
    /// (iOS 18+) the status is `.unavailable` until the system reports a real decision.
    static var bluetooth: PermissionRegistration { PermissionRegistration(BluetoothPermissionProvider()) }
}
