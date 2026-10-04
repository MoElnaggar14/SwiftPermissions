#if os(iOS)
@preconcurrency import MediaPlayer

/// Apple Music and media library access.
public struct MediaLibraryPermissionProvider: PermissionProvider {
    public let permission = Permission.mediaLibrary
    public let requiredUsageDescriptionKeys = ["NSAppleMusicUsageDescription"]

    public init() {}

    public func status() async -> PermissionStatus {
        Self.map(MPMediaLibrary.authorizationStatus())
    }

    public func request() async throws -> PermissionStatus {
        let status: MPMediaLibraryAuthorizationStatus = await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0) }
        }
        return Self.map(status)
    }

    static func map(_ status: MPMediaLibraryAuthorizationStatus) -> PermissionStatus {
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
