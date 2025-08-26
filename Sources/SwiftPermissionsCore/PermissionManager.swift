import Foundation
import Combine

#if canImport(UIKit)
import UIKit
#endif

#if canImport(CoreLocation)
import CoreLocation
#endif

#if canImport(UserNotifications)
import UserNotifications
#endif

#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(Photos)
import Photos
#endif

#if canImport(Contacts)
import Contacts
#endif

#if canImport(EventKit)
import EventKit
#endif

#if canImport(HealthKit)
import HealthKit
#endif

#if canImport(CoreMotion)
import CoreMotion
#endif

#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

/// Main implementation of PermissionManagerProtocol
public final class PermissionManager: NSObject, PermissionManagerProtocol, @unchecked Sendable {
    
    private let permissionStatusSubject = PassthroughSubject<(PermissionType, PermissionStatus), Never>()
    public var permissionStatusChanged: AnyPublisher<(PermissionType, PermissionStatus), Never> {
        permissionStatusSubject.eraseToAnyPublisher()
    }
    
    // Location manager for location permissions
    #if canImport(CoreLocation)
    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        return manager
    }()
    #endif
    
    public override init() {
        super.init()
    }
    
    // MARK: - PermissionManagerProtocol Implementation
    
    public func status(for type: PermissionType) async -> PermissionStatus {
        switch type {
        case .location, .locationWhenInUse, .locationAlways:
            return locationPermissionStatus(for: type)
        case .notification:
            return await notificationPermissionStatus()
        case .camera:
            return cameraPermissionStatus()
        case .microphone:
            return microphonePermissionStatus()
        case .photoLibrary:
            return photoLibraryPermissionStatus()
        case .contacts:
            return contactsPermissionStatus()
        case .calendar:
            return calendarPermissionStatus()
        case .reminders:
            return remindersPermissionStatus()
        case .health:
            return healthPermissionStatus()
        case .motion:
            return motionPermissionStatus()
        case .faceID, .touchID:
            return biometricPermissionStatus()
        case .tracking:
            return trackingPermissionStatus()
        }
    }
    
    public func request(_ type: PermissionType, config: PermissionConfig? = nil) async -> PermissionResult {
        let currentStatus = await status(for: type)
        
        // If already authorized or can't be requested, return current status
        if currentStatus.isAuthorized || !currentStatus.canBeRequested {
            return PermissionResult(type: type, status: currentStatus)
        }
        
        do {
            let newStatus = try await requestPermission(type: type, config: config)
            let result = PermissionResult(type: type, status: newStatus)
            
            // Notify status change
            if newStatus != currentStatus {
                permissionStatusSubject.send((type, newStatus))
            }
            
            return result
        } catch {
            return PermissionResult(type: type, status: currentStatus, error: error)
        }
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
        #if canImport(UIKit)
        Task { @MainActor in
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
                  UIApplication.shared.canOpenURL(settingsUrl) else {
                return
            }
            UIApplication.shared.open(settingsUrl)
        }
        #endif
    }
}

// MARK: - Private Permission Request Methods
private extension PermissionManager {
    
    func requestPermission(type: PermissionType, config: PermissionConfig?) async throws -> PermissionStatus {
        switch type {
        case .locationWhenInUse:
            return try await requestLocationWhenInUse()
        case .locationAlways:
            return try await requestLocationAlways()
        case .location:
            return try await requestLocationWhenInUse() // Default to when in use
        case .notification:
            return try await requestNotificationPermission()
        case .camera:
            return try await requestCameraPermission()
        case .microphone:
            return try await requestMicrophonePermission()
        case .photoLibrary:
            return try await requestPhotoLibraryPermission()
        case .contacts:
            return try await requestContactsPermission()
        case .calendar:
            return try await requestCalendarPermission()
        case .reminders:
            return try await requestRemindersPermission()
        case .health:
            throw PermissionError.notSupported("Health permissions require specific health data types")
        case .motion:
            return try await requestMotionPermission()
        case .faceID, .touchID:
            return try await requestBiometricPermission()
        case .tracking:
            return try await requestTrackingPermission()
        }
    }
}

// MARK: - Permission Status Methods
private extension PermissionManager {
    
    func locationPermissionStatus(for type: PermissionType) -> PermissionStatus {
        guard CLLocationManager.locationServicesEnabled() else {
            return .restricted
        }
        
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        case .authorizedWhenInUse:
            return type == .locationAlways ? .denied : .authorized
        case .authorizedAlways:
            return .authorized
        @unknown default:
            return .denied
        }
    }
    
    func notificationPermissionStatus() async -> PermissionStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .authorized
        @unknown default:
            return .denied
        }
    }
    
    func cameraPermissionStatus() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .denied
        }
    }
    
    func microphonePermissionStatus() -> PermissionStatus {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .denied
        }
    }
    
    func photoLibraryPermissionStatus() -> PermissionStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        case .authorized:
            return .authorized
        case .limited:
            return .authorized
        @unknown default:
            return .denied
        }
    }
    
    func contactsPermissionStatus() -> PermissionStatus {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .denied
        }
    }
    
    func calendarPermissionStatus() -> PermissionStatus {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        case .authorized:
            return .authorized
        case .fullAccess:
            return .authorized
        case .writeOnly:
            return .authorized
        @unknown default:
            return .denied
        }
    }
    
    func remindersPermissionStatus() -> PermissionStatus {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        case .authorized:
            return .authorized
        case .fullAccess:
            return .authorized
        case .writeOnly:
            return .authorized
        @unknown default:
            return .denied
        }
    }
    
    func healthPermissionStatus() -> PermissionStatus {
        // Health permissions are complex and require specific data types
        // Return not determined as default since it depends on specific health data
        return .notDetermined
    }
    
    func motionPermissionStatus() -> PermissionStatus {
        #if canImport(CoreMotion) && !os(macOS)
        let status = CMMotionActivityManager.authorizationStatus()
        
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .denied
        }
        #else
        return .notDetermined
        #endif
    }
    
    func biometricPermissionStatus() -> PermissionStatus {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return .authorized
        } else {
            return .restricted
        }
    }
    
    func trackingPermissionStatus() -> PermissionStatus {
        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            
            switch status {
            case .notDetermined:
                return .notDetermined
            case .denied, .restricted:
                return .denied
            case .authorized:
                return .authorized
            @unknown default:
                return .denied
            }
        } else {
            return .authorized // Tracking was allowed by default before iOS 14
        }
    }
}

// MARK: - Permission Request Implementations
private extension PermissionManager {
    
    func requestLocationWhenInUse() async throws -> PermissionStatus {
        return try await withCheckedThrowingContinuation { continuation in
            locationRequestContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func requestLocationAlways() async throws -> PermissionStatus {
        return try await withCheckedThrowingContinuation { continuation in
            locationRequestContinuation = continuation
            locationManager.requestAlwaysAuthorization()
        }
    }
    
    func requestNotificationPermission() async throws -> PermissionStatus {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted ? .authorized : .denied
        } catch {
            throw error
        }
    }
    
    func requestCameraPermission() async throws -> PermissionStatus {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .authorized : .denied
    }
    
    func requestMicrophonePermission() async throws -> PermissionStatus {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        return granted ? .authorized : .denied
    }
    
    func requestPhotoLibraryPermission() async throws -> PermissionStatus {
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                let permissionStatus: PermissionStatus
                
                switch status {
                case .authorized, .limited:
                    permissionStatus = .authorized
                case .denied, .restricted:
                    permissionStatus = .denied
                case .notDetermined:
                    permissionStatus = .notDetermined
                @unknown default:
                    permissionStatus = .denied
                }
                
                continuation.resume(returning: permissionStatus)
            }
        }
    }
    
    func requestContactsPermission() async throws -> PermissionStatus {
        return try await withCheckedThrowingContinuation { continuation in
            let store = CNContactStore()
            store.requestAccess(for: .contacts) { granted, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted ? .authorized : .denied)
                }
            }
        }
    }
    
    func requestCalendarPermission() async throws -> PermissionStatus {
        return try await withCheckedThrowingContinuation { continuation in
            let store = EKEventStore()
            if #available(iOS 17.0, macOS 14.0, *) {
                store.requestFullAccessToEvents { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted ? .authorized : .denied)
                    }
                }
            } else {
                store.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted ? .authorized : .denied)
                    }
                }
            }
        }
    }
    
    func requestRemindersPermission() async throws -> PermissionStatus {
        return try await withCheckedThrowingContinuation { continuation in
            let store = EKEventStore()
            if #available(iOS 17.0, macOS 14.0, *) {
                store.requestFullAccessToReminders { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted ? .authorized : .denied)
                    }
                }
            } else {
                store.requestAccess(to: .reminder) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted ? .authorized : .denied)
                    }
                }
            }
        }
    }
    
    func requestMotionPermission() async throws -> PermissionStatus {
        #if canImport(CoreMotion) && !os(macOS)
        // Motion permission is requested automatically when accessing motion data
        // We'll simulate a request by checking if we can create a motion manager
        let manager = CMMotionActivityManager()
        let status = CMMotionActivityManager.authorizationStatus()
        
        switch status {
        case .notDetermined:
            // Start and immediately stop activity updates to trigger permission request
            manager.startActivityUpdates(to: OperationQueue()) { _ in }
            manager.stopActivityUpdates()
            
            // Wait a bit for the system to process the request
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            return motionPermissionStatus()
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
        #else
        return .restricted
        #endif
    }
    
    func requestBiometricPermission() async throws -> PermissionStatus {
        let context = LAContext()
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate with biometrics"
            )
            
            return result ? .authorized : .denied
        } catch {
            // Handle specific errors
            if let laError = error as? LAError {
                switch laError.code {
                case .biometryNotAvailable, .biometryNotEnrolled:
                    return .restricted
                case .userCancel, .userFallback:
                    return .denied
                default:
                    return .denied
                }
            }
            
            throw error
        }
    }
    
    func requestTrackingPermission() async throws -> PermissionStatus {
        let status = await ATTrackingManager.requestTrackingAuthorization()
        
        switch status {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }
}

// MARK: - Location Manager Delegate
extension PermissionManager: CLLocationManagerDelegate {
    private var locationRequestContinuation: CheckedContinuation<PermissionStatus, Error>? {
        get { objc_getAssociatedObject(self, &locationRequestKey) as? CheckedContinuation<PermissionStatus, Error> }
        set { objc_setAssociatedObject(self, &locationRequestKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = locationPermissionStatus(for: .locationWhenInUse)
        
        // Complete pending request if exists
        if let continuation = locationRequestContinuation {
            locationRequestContinuation = nil
            continuation.resume(returning: status)
        }
        
        // Notify status change
        permissionStatusSubject.send((.location, status))
    }
}

// MARK: - Associated Object Key
private var locationRequestKey: UInt8 = 0

// MARK: - Permission Errors
public enum PermissionError: LocalizedError {
    case notSupported(String)
    case restricted
    case denied
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .notSupported(let message):
            return message
        case .restricted:
            return "Permission is restricted"
        case .denied:
            return "Permission was denied"
        case .unknown:
            return "Unknown permission error"
        }
    }
}
