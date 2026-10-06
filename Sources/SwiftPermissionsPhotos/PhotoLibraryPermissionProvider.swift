import SwiftPermissionsCore
#if os(iOS) || os(macOS) || os(visionOS)
@preconcurrency import Photos
#if os(iOS)
@preconcurrency import PhotosUI
import UIKit
#endif

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
        case .limited: .limited(.selectedItems)
        @unknown default: .denied
        }
    }

    /// Why ``map(_:)`` reports `.limited`, or `nil` when it doesn't. 4.0 puts it in the status.
    static func mapLimitation(_ status: PHAuthorizationStatus) -> Limitation? {
        map(status).isLimited ? .selectedItems : nil
    }
}

#if os(iOS)
public extension PhotoLibraryPermissionProvider {
    /// Shows the system picker where people with ``PermissionStatus/limited`` access can
    /// add photos to (or remove them from) the ones your app can see.
    ///
    /// Use it as the "Select More…" action of a `PermissionRow` or `PermissionPrompt`.
    /// The status stays `.limited`; only the selection changes. Showing the picker when
    /// access isn't limited does nothing useful, so check the status first.
    ///
    /// - Parameter controller: The view controller to present the picker from.
    /// - Returns: The local identifiers of the assets the user newly selected.
    @MainActor
    @discardableResult
    func presentLimitedLibraryPicker(from controller: UIViewController) async -> [String] {
        await withCheckedContinuation { continuation in
            // @Sendable so the handler isn't inferred as main-actor isolated: PhotoKit
            // doesn't promise to call it on the main thread.
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller) { @Sendable identifiers in
                continuation.resume(returning: identifiers)
            }
        }
    }
}
#endif

public extension PermissionRegistration {
    /// Read and write access to the photo library. Needs `NSPhotoLibraryUsageDescription`.
    static var photoLibrary: PermissionRegistration { PermissionRegistration(PhotoLibraryPermissionProvider.readWrite) }
    /// Add-only access. Needs `NSPhotoLibraryAddUsageDescription`.
    static var photoLibraryAddOnly: PermissionRegistration {
        PermissionRegistration(PhotoLibraryPermissionProvider.addOnly)
    }
}
#endif
