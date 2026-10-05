import SwiftPermissionsCore
#if os(iOS) || os(macOS) || os(visionOS)
@preconcurrency import Speech

/// Speech recognition access.
public struct SpeechRecognitionPermissionProvider: PermissionProvider {
    public let permission = Permission.speechRecognition
    public let requiredUsageDescriptionKeys = ["NSSpeechRecognitionUsageDescription"]

    public init() {}

    public func status() async -> PermissionStatus {
        Self.map(SFSpeechRecognizer.authorizationStatus())
    }

    public func request() async throws -> PermissionStatus {
        let status: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        return Self.map(status)
    }

    static func map(_ status: SFSpeechRecognizerAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .restricted: .restricted
        case .authorized: .authorized
        @unknown default: .denied
        }
    }
}

public extension PermissionRegistration {
    /// Speech recognition. Needs `NSSpeechRecognitionUsageDescription`.
    static var speechRecognition: PermissionRegistration {
        PermissionRegistration(SpeechRecognitionPermissionProvider())
    }
}
#endif
