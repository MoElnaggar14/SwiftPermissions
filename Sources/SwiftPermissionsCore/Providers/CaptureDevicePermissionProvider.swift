#if os(iOS) || os(macOS) || os(visionOS)
@preconcurrency import AVFoundation

/// Camera or microphone access through `AVCaptureDevice`.
public struct CaptureDevicePermissionProvider: PermissionProvider {
    public let permission: Permission
    private let mediaType: AVMediaType

    public static let camera = CaptureDevicePermissionProvider(permission: .camera, mediaType: .video)
    public static let microphone = CaptureDevicePermissionProvider(permission: .microphone, mediaType: .audio)

    private init(permission: Permission, mediaType: AVMediaType) {
        self.permission = permission
        self.mediaType = mediaType
    }

    public var requiredUsageDescriptionKeys: [String] {
        mediaType == .video ? ["NSCameraUsageDescription"] : ["NSMicrophoneUsageDescription"]
    }

    public func status() async -> PermissionStatus {
        Self.map(AVCaptureDevice.authorizationStatus(for: mediaType))
    }

    public func request() async throws -> PermissionStatus {
        _ = await AVCaptureDevice.requestAccess(for: mediaType)
        return await status()
    }

    static func map(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .restricted: .restricted
        case .authorized: .authorized
        @unknown default: .denied
        }
    }
}
#endif
