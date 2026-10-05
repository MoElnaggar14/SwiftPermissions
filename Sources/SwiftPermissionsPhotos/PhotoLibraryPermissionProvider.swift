import SwiftPermissionsCore
#if os(iOS) || os(macOS) || os(visionOS)
@preconcurrency import Photos

/// Photo library access, either read-write or add-only.
public struct PhotoLibraryPermissionProvider: PermissionProvider {
    public let permission: Permission
    private let accessLevel: PHAccessLevel

    public static let readWrite = PhotoLibraryPermissionProvider(permission: .photoLibrary, accessLevel: .readWrite)
    public static let addOnly = PhotoLibraryPermissionProvider(permission: .photoLibraryAddOnly, accessLevel: .addOnly)

    private init(permission: Permission, accessLevel: PHAccessLevel) {
        self.permission = permission
        self.accessLevel = accessLevel
    }

    public var requiredUsageDescriptionKeys: [String] {
        accessLevel == .addOnly ? ["NSPhotoLibraryAddUsageDescription"] : ["NSPhotoLibraryUsageDescription"]
    }

    public func status() async -> PermissionStatus {
        Self.map(PHPhotoLibrary.authorizationStatus(for: accessLevel))
    }

    public func request() async throws -> PermissionStatus {
        Self.map(await PHPhotoLibrary.requestAuthorization(for: accessLevel))
    }

    static func map(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .restricted: .restricted
        case .authorized: .authorized
        case .limited: .limited
        @unknown default: .denied
        }
    }
}

public extension PermissionRegistration {
    /// Read and write access to the photo library. Needs `NSPhotoLibraryUsageDescription`.
    static var photoLibrary: PermissionRegistration { PermissionRegistration(PhotoLibraryPermissionProvider.readWrite) }
    /// Add-only access. Needs `NSPhotoLibraryAddUsageDescription`.
    static var photoLibraryAddOnly: PermissionRegistration {
        PermissionRegistration(PhotoLibraryPermissionProvider.addOnly)
    }
}
#endif
