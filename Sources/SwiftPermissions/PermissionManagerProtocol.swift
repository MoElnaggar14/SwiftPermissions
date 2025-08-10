import Foundation
import Combine

/// Protocol defining the interface for permission management
public protocol PermissionManagerProtocol: Sendable {
    /// Check the current status of a specific permission
    /// - Parameter type: The type of permission to check
    /// - Returns: The current permission status
    func status(for type: PermissionType) async -> PermissionStatus
    
    /// Request a specific permission
    /// - Parameters:
    ///   - type: The type of permission to request
    ///   - config: Optional configuration for the permission request
    /// - Returns: The result of the permission request
    func request(_ type: PermissionType, config: PermissionConfig?) async -> PermissionResult
    
    /// Request multiple permissions
    /// - Parameter types: Array of permission types to request
    /// - Returns: Array of permission results
    func requestMultiple(_ types: [PermissionType]) async -> [PermissionResult]
    
    /// Check if a permission can be requested (not permanently denied)
    /// - Parameter type: The type of permission to check
    /// - Returns: Whether the permission can be requested
    func canRequest(_ type: PermissionType) async -> Bool
    
    /// Open the app's settings page
    func openSettings()
    
    /// Publisher that emits permission status changes
    var permissionStatusChanged: AnyPublisher<(PermissionType, PermissionStatus), Never> { get }
}

/// Extension providing default implementations
public extension PermissionManagerProtocol {
    /// Request a permission with default configuration
    func request(_ type: PermissionType) async -> PermissionResult {
        return await request(type, config: nil)
    }
    
    /// Check if all specified permissions are authorized
    func areAllAuthorized(_ types: [PermissionType]) async -> Bool {
        for type in types {
            let status = await status(for: type)
            if !status.isAuthorized {
                return false
            }
        }
        return true
    }
    
    /// Get status for multiple permissions
    func statusFor(_ types: [PermissionType]) async -> [PermissionType: PermissionStatus] {
        var results: [PermissionType: PermissionStatus] = [:]
        
        for type in types {
            results[type] = await status(for: type)
        }
        
        return results
    }
}
