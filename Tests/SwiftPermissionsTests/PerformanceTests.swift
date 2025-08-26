@testable import SwiftPermissions
import XCTest

final class PerformanceTests: XCTestCase {
    
    func testPermissionStatusCheckPerformance() {
        let manager = PermissionManagerFactory.mock()
        
        measure {
            let expectation = expectation(description: "Status check")
            
            Task {
                for _ in 0..<100 {
                    _ = await manager.status(for: .camera)
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testBatchPermissionRequestPerformance() {
        let manager = PermissionManagerFactory.mock()
        let permissions: [PermissionType] = [.camera, .microphone, .photoLibrary, .locationWhenInUse, .notification]
        
        measure {
            let expectation = expectation(description: "Batch request")
            
            Task {
                _ = await manager.requestMultiple(permissions)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testPermissionGroupsPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = [PermissionType].media
                _ = [PermissionType].location
                _ = [PermissionType].social
                _ = [PermissionType].fitness
                _ = [PermissionType].all
            }
        }
    }
    
    func testPermissionManagerFactoryPerformance() {
        measure {
            for _ in 0..<100 {
                _ = PermissionManagerFactory.default()
                _ = PermissionManagerFactory.mock()
            }
        }
    }
}
