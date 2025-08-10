import Foundation

/// Represents the different types of permissions that can be requested
public enum PermissionType: String, CaseIterable, Sendable {
    case location
    case locationWhenInUse
    case locationAlways
    case notification
    case camera
    case microphone
    case photoLibrary
    case contacts
    case calendar
    case reminders
    case health
    case motion
    case faceID
    case touchID
    case tracking
    
    /// Human-readable description for each permission type
    public var description: String {
        switch self {
        case .location:
            return "Location Services"
        case .locationWhenInUse:
            return "Location When In Use"
        case .locationAlways:
            return "Location Always"
        case .notification:
            return "Push Notifications"
        case .camera:
            return "Camera Access"
        case .microphone:
            return "Microphone Access"
        case .photoLibrary:
            return "Photo Library Access"
        case .contacts:
            return "Contacts Access"
        case .calendar:
            return "Calendar Access"
        case .reminders:
            return "Reminders Access"
        case .health:
            return "Health Data Access"
        case .motion:
            return "Motion & Fitness"
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .tracking:
            return "App Tracking Transparency"
        }
    }
}

/// Represents the status of a permission
public enum PermissionStatus: String, CaseIterable, Sendable {
    case notDetermined
    case denied
    case authorized
    case restricted
    case provisional
    
    /// Whether the permission allows the feature to be used
    public var isAuthorized: Bool {
        switch self {
        case .authorized, .provisional:
            return true
        case .notDetermined, .denied, .restricted:
            return false
        }
    }
    
    /// Whether the permission can be requested (not permanently denied)
    public var canBeRequested: Bool {
        switch self {
        case .notDetermined:
            return true
        case .denied, .authorized, .restricted, .provisional:
            return false
        }
    }
}

/// Result of a permission request
public struct PermissionResult: Sendable {
    public let type: PermissionType
    public let status: PermissionStatus
    public let error: Error?
    
    public init(type: PermissionType, status: PermissionStatus, error: Error? = nil) {
        self.type = type
        self.status = status
        self.error = error
    }
    
    public var isSuccess: Bool {
        return status.isAuthorized && error == nil
    }
}

/// Configuration for permission requests
public struct PermissionConfig: Sendable {
    public let title: String?
    public let message: String?
    public let settingsTitle: String?
    public let settingsMessage: String?
    
    public init(
        title: String? = nil,
        message: String? = nil,
        settingsTitle: String? = nil,
        settingsMessage: String? = nil
    ) {
        self.title = title
        self.message = message
        self.settingsTitle = settingsTitle
        self.settingsMessage = settingsMessage
    }
}
