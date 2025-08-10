import Foundation
import Combine

// MARK: - Public API Exports

// Core Types
public typealias Permission = PermissionType
public typealias Status = PermissionStatus

// Main Manager
public typealias Permissions = PermissionManager

// MARK: - Convenience Extensions

public extension PermissionManager {
    /// Convenience method to check location permission status
    static func locationStatus() async -> PermissionStatus {
        return await shared.status(for: .location)
    }
    
    /// Convenience method to request location permission
    static func requestLocation() async -> PermissionResult {
        return await shared.request(.location)
    }
    
    /// Convenience method to check notification permission status
    static func notificationStatus() async -> PermissionStatus {
        return await shared.status(for: .notification)
    }
    
    /// Convenience method to request notification permission
    static func requestNotifications() async -> PermissionResult {
        return await shared.request(.notification)
    }
    
    /// Convenience method to check camera permission status
    static func cameraStatus() async -> PermissionStatus {
        return await shared.status(for: .camera)
    }
    
    /// Convenience method to request camera permission
    static func requestCamera() async -> PermissionResult {
        return await shared.request(.camera)
    }
    
    /// Convenience method to check photo library permission status
    static func photoLibraryStatus() async -> PermissionStatus {
        return await shared.status(for: .photoLibrary)
    }
    
    /// Convenience method to request photo library permission
    static func requestPhotoLibrary() async -> PermissionResult {
        return await shared.request(.photoLibrary)
    }
}

// MARK: - Common Permission Groups

public extension Array where Element == PermissionType {
    /// Common permissions for media apps
    static var media: [PermissionType] {
        return [.camera, .microphone, .photoLibrary]
    }
    
    /// Common permissions for location-based apps
    static var location: [PermissionType] {
        return [.locationWhenInUse, .notification]
    }
    
    /// Common permissions for social apps
    static var social: [PermissionType] {
        return [.contacts, .photoLibrary, .camera, .notification]
    }
    
    /// Common permissions for fitness apps
    static var fitness: [PermissionType] {
        return [.motion, .health, .locationWhenInUse, .notification]
    }
    
    /// Productivity permissions (calendar, reminders, contacts)
    static var productivity: [PermissionType] {
        return [.calendar, .reminders, .contacts]
    }
    
    /// Health and fitness permissions
    static var healthAndFitness: [PermissionType] {
        return [.health, .motion]
    }
    
    /// Biometric permissions
    static var biometric: [PermissionType] {
        return [.faceID, .touchID]
    }
    
    /// Essential permissions for most apps
    static var essential: [PermissionType] {
        return [.notification, .camera, .photoLibrary, .locationWhenInUse]
    }
    
    /// All available permissions
    static var all: [PermissionType] {
        return PermissionType.allCases
    }
}

// MARK: - Permission Manager Factory

/// Factory for creating permission managers with specific configurations
public struct PermissionManagerFactory {
    /// Creates a permission manager with default configuration
    public static func `default`() -> PermissionManagerProtocol {
        return PermissionManager.shared
    }
    
    /// Creates a permission manager for testing with mock implementation
    public static func mock() -> PermissionManagerProtocol {
        return MockPermissionManager()
    }
}

// MARK: - Mock Implementation for Testing

public final class MockPermissionManager: PermissionManagerProtocol, @unchecked Sendable {
    public var permissionStatusChanged: AnyPublisher<(PermissionType, PermissionStatus), Never> {
        statusChangeSubject.eraseToAnyPublisher()
    }
    
    private let statusChangeSubject = PassthroughSubject<(PermissionType, PermissionStatus), Never>()
    private let mockStatusesLock = NSLock()
    private var _mockStatuses: [PermissionType: PermissionStatus] = [:]
    private let shouldGrantPermissionsLock = NSLock()
    private var _shouldGrantPermissions = true
    
    public init() {}
    
    private var mockStatuses: [PermissionType: PermissionStatus] {
        get {
            mockStatusesLock.lock()
            defer { mockStatusesLock.unlock() }
            return _mockStatuses
        }
        set {
            mockStatusesLock.lock()
            defer { mockStatusesLock.unlock() }
            _mockStatuses = newValue
        }
    }
    
    private var shouldGrantPermissions: Bool {
        get {
            shouldGrantPermissionsLock.lock()
            defer { shouldGrantPermissionsLock.unlock() }
            return _shouldGrantPermissions
        }
        set {
            shouldGrantPermissionsLock.lock()
            defer { shouldGrantPermissionsLock.unlock() }
            _shouldGrantPermissions = newValue
        }
    }
    
    public func status(for type: PermissionType) async -> PermissionStatus {
        return mockStatuses[type] ?? .notDetermined
    }
    
    public func request(_ type: PermissionType, config: PermissionConfig?) async -> PermissionResult {
        let newStatus: PermissionStatus = shouldGrantPermissions ? .authorized : .denied
        mockStatuses[type] = newStatus
        statusChangeSubject.send((type, newStatus))
        return PermissionResult(type: type, status: newStatus)
    }
    
    public func requestMultiple(_ types: [PermissionType]) async -> [PermissionResult] {
        var results: [PermissionResult] = []
        
        for type in types {
            let result = await request(type)
            results.append(result)
        }
        
        return results
    }
    
    public func canRequest(_ type: PermissionType) async -> Bool {
        let status = await status(for: type)
        return status.canBeRequested
    }
    
    public func openSettings() {
        // Mock implementation - does nothing
    }
    
    // MARK: - Test Helpers
    
    /// Set whether permissions should be granted in mock
    public func setShouldGrantPermissions(_ shouldGrant: Bool) {
        shouldGrantPermissions = shouldGrant
    }
    
    /// Set mock status for a specific permission
    public func setMockStatus(_ status: PermissionStatus, for type: PermissionType) {
        mockStatuses[type] = status
        statusChangeSubject.send((type, status))
    }
    
    /// Reset all mock statuses
    public func resetMockStatuses() {
        mockStatuses.removeAll()
    }
}
