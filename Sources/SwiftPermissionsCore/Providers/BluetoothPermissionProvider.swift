@preconcurrency import CoreBluetooth

/// Bluetooth access. The prompt is shown the first time a `CBCentralManager` is created.
public struct BluetoothPermissionProvider: PermissionProvider {
    public let permission = Permission.bluetooth

    public init() {}

    /// Required on every platform, macOS 11+ included: TCC terminates the app if
    /// a `CBCentralManager` is created without it.
    public let requiredUsageDescriptionKeys = ["NSBluetoothAlwaysUsageDescription"]

    public func status() async -> PermissionStatus {
        Self.map(CBManager.authorization)
    }

    public func request() async throws -> PermissionStatus {
        let request = await BluetoothAuthorizationRequest()
        await request.run()
        return await status()
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
