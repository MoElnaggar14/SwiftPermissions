import Combine
@testable import SwiftPermissions
import XCTest

final class PermissionsTests: XCTestCase {
    var mockManager: MockPermissionManager?
    var cancellables: Set<AnyCancellable>?
    
    override func setUp() {
        super.setUp()
        mockManager = MockPermissionManager()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        mockManager = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Permission Types Tests
    
    func testPermissionTypeDescriptions() {
        XCTAssertEqual(PermissionType.location.description, "Location Services")
        XCTAssertEqual(PermissionType.camera.description, "Camera Access")
        XCTAssertEqual(PermissionType.notification.description, "Push Notifications")
        XCTAssertEqual(PermissionType.photoLibrary.description, "Photo Library Access")
    }
    
    func testPermissionTypeAllCases() {
        XCTAssertTrue(PermissionType.allCases.contains(.location))
        XCTAssertTrue(PermissionType.allCases.contains(.camera))
        XCTAssertTrue(PermissionType.allCases.contains(.notification))
        XCTAssertTrue(PermissionType.allCases.contains(.photoLibrary))
    }
    
    // MARK: - Permission Status Tests
    
    func testPermissionStatusIsAuthorized() {
        XCTAssertTrue(PermissionStatus.authorized.isAuthorized)
        XCTAssertTrue(PermissionStatus.provisional.isAuthorized)
        XCTAssertFalse(PermissionStatus.denied.isAuthorized)
        XCTAssertFalse(PermissionStatus.notDetermined.isAuthorized)
        XCTAssertFalse(PermissionStatus.restricted.isAuthorized)
    }
    
    func testPermissionStatusCanBeRequested() {
        XCTAssertTrue(PermissionStatus.notDetermined.canBeRequested)
        XCTAssertFalse(PermissionStatus.authorized.canBeRequested)
        XCTAssertFalse(PermissionStatus.denied.canBeRequested)
        XCTAssertFalse(PermissionStatus.restricted.canBeRequested)
        XCTAssertFalse(PermissionStatus.provisional.canBeRequested)
    }
    
    // MARK: - Permission Result Tests
    
    func testPermissionResultIsSuccess() {
        let successResult = PermissionResult(type: .camera, status: .authorized)
        let failureResult = PermissionResult(type: .camera, status: .denied)
        let errorResult = PermissionResult(type: .camera, status: .authorized, error: TestError.generic)
        
        XCTAssertTrue(successResult.isSuccess)
        XCTAssertFalse(failureResult.isSuccess)
        XCTAssertFalse(errorResult.isSuccess)
    }
    
    // MARK: - Mock Permission Manager Tests
    
    func testMockManagerInitialStatus() async {
        let status = await mockManager!.status(for: .camera)
        XCTAssertEqual(status, .notDetermined)
    }
    
    func testMockManagerRequestPermission() async {
        mockManager!.setShouldGrantPermissions(true)
        let result = await mockManager!.request(.camera)
        
        XCTAssertEqual(result.type, .camera)
        XCTAssertEqual(result.status, .authorized)
        XCTAssertTrue(result.isSuccess)
    }
    
    func testMockManagerDenyPermission() async {
        mockManager!.setShouldGrantPermissions(false)
        let result = await mockManager!.request(.camera)
        
        XCTAssertEqual(result.type, .camera)
        XCTAssertEqual(result.status, .denied)
        XCTAssertFalse(result.isSuccess)
    }
    
    func testMockManagerMultiplePermissions() async {
        mockManager!.setShouldGrantPermissions(true)
        let results = await mockManager!.requestMultiple([.camera, .microphone, .photoLibrary])
        
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.isSuccess })
    }
    
    func testMockManagerCanRequest() async {
        // Initially should be able to request
        let canRequestInitial = await mockManager!.canRequest(.camera)
        XCTAssertTrue(canRequestInitial)
        
        // After granting, should not be able to request
        mockManager!.setShouldGrantPermissions(true)
        _ = await mockManager!.request(.camera)
        
        let canRequestAfterGrant = await mockManager!.canRequest(.camera)
        XCTAssertFalse(canRequestAfterGrant)
    }
    
    func testMockManagerSetMockStatus() async {
        mockManager!.setMockStatus(.restricted, for: .camera)
        let status = await mockManager!.status(for: .camera)
        XCTAssertEqual(status, .restricted)
    }
    
    func testMockManagerResetStatuses() async {
        mockManager!.setMockStatus(.authorized, for: .camera)
        mockManager!.resetMockStatuses()
        
        let status = await mockManager!.status(for: .camera)
        XCTAssertEqual(status, .notDetermined)
    }
    
    // MARK: - Permission Status Change Tests
    
    func testPermissionStatusChangePublisher() async {
        let expectation = XCTestExpectation(description: "Permission status change")
        var receivedUpdate: (PermissionType, PermissionStatus)?
        
        mockManager!.permissionStatusChanged
            .sink { update in
                receivedUpdate = update
                expectation.fulfill()
            }
            .store(in: &cancellables!)
        
        mockManager!.setShouldGrantPermissions(true)
        _ = await mockManager!.request(.camera)
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedUpdate?.0, .camera)
        XCTAssertEqual(receivedUpdate?.1, .authorized)
    }
    
    // MARK: - Permission Config Tests
    
    func testPermissionConfig() {
        let config = PermissionConfig(
            title: "Test Title",
            message: "Test Message",
            settingsTitle: "Settings Title",
            settingsMessage: "Settings Message"
        )
        
        XCTAssertEqual(config.title, "Test Title")
        XCTAssertEqual(config.message, "Test Message")
        XCTAssertEqual(config.settingsTitle, "Settings Title")
        XCTAssertEqual(config.settingsMessage, "Settings Message")
    }
    
    func testPermissionConfigWithNilValues() {
        let config = PermissionConfig()
        
        XCTAssertNil(config.title)
        XCTAssertNil(config.message)
        XCTAssertNil(config.settingsTitle)
        XCTAssertNil(config.settingsMessage)
    }
    
    // MARK: - Common Permission Groups Tests
    
    func testMediaPermissions() {
        let mediaPermissions: [PermissionType] = .media
        XCTAssertTrue(mediaPermissions.contains(.camera))
        XCTAssertTrue(mediaPermissions.contains(.microphone))
        XCTAssertTrue(mediaPermissions.contains(.photoLibrary))
    }
    
    func testLocationPermissions() {
        let locationPermissions: [PermissionType] = .location
        XCTAssertTrue(locationPermissions.contains(.locationWhenInUse))
        XCTAssertTrue(locationPermissions.contains(.notification))
    }
    
    func testSocialPermissions() {
        let socialPermissions: [PermissionType] = .social
        XCTAssertTrue(socialPermissions.contains(.contacts))
        XCTAssertTrue(socialPermissions.contains(.photoLibrary))
        XCTAssertTrue(socialPermissions.contains(.camera))
        XCTAssertTrue(socialPermissions.contains(.notification))
    }
    
    func testFitnessPermissions() {
        let fitnessPermissions: [PermissionType] = .fitness
        XCTAssertTrue(fitnessPermissions.contains(.motion))
        XCTAssertTrue(fitnessPermissions.contains(.health))
        XCTAssertTrue(fitnessPermissions.contains(.locationWhenInUse))
        XCTAssertTrue(fitnessPermissions.contains(.notification))
    }
    
    func testAllPermissions() {
        let allPermissions: [PermissionType] = .all
        XCTAssertEqual(allPermissions.count, PermissionType.allCases.count)
    }
    
    // MARK: - Permission Manager Factory Tests
    
    func testPermissionManagerFactory() {
        let defaultManager = PermissionManagerFactory.default()
        XCTAssertTrue(defaultManager is PermissionManager)
        
        let mockManager = PermissionManagerFactory.mock()
        XCTAssertTrue(mockManager is MockPermissionManager)
    }
    
    // MARK: - Protocol Extension Tests
    
    func testProtocolExtensionRequestWithoutConfig() async {
        let result = await mockManager!.request(.camera)
        XCTAssertEqual(result.type, .camera)
    }
    
    func testProtocolExtensionAreAllAuthorized() async {
        mockManager!.setShouldGrantPermissions(true)
        _ = await mockManager!.requestMultiple([.camera, .microphone])
        
        let allAuthorized = await mockManager!.areAllAuthorized([.camera, .microphone])
        XCTAssertTrue(allAuthorized)
        
        mockManager!.setMockStatus(.denied, for: .camera)
        let notAllAuthorized = await mockManager!.areAllAuthorized([.camera, .microphone])
        XCTAssertFalse(notAllAuthorized)
    }
    
    func testProtocolExtensionStatusFor() async {
        mockManager!.setMockStatus(.authorized, for: .camera)
        mockManager!.setMockStatus(.denied, for: .microphone)
        
        let statuses = await mockManager!.statusFor([.camera, .microphone])
        
        XCTAssertEqual(statuses[.camera], .authorized)
        XCTAssertEqual(statuses[.microphone], .denied)
    }
}

// MARK: - Test Helpers

enum TestError: Error {
    case generic
}
