import SwiftPermissionsCore
import SwiftPermissionsTesting
import Testing

/// Proves the testing stubs work with Swift Testing's `#expect`.
@Suite("Stubs with Swift Testing")
struct SwiftTestingSupportTests {
    @Test func deniedRequestShowsOnePrompt() async throws {
        let camera = StubPermissionProvider(.camera, onRequest: .deny)
        let permissions = PermissionManager.stubbed(camera)

        let status = try await permissions.request(.camera)

        #expect(status == .denied)
        #expect(await camera.requestCount == 1)
    }

    @Test(arguments: [PermissionStatus.authorized, .denied, .restricted])
    func decidedStatusesNeverPrompt(status: PermissionStatus) async throws {
        let camera = StubPermissionProvider(.camera, status: status)
        let permissions = PermissionManager.stubbed(camera)

        #expect(try await permissions.request(.camera) == status)
        #expect(await camera.requestCount == 0)
    }

    @Test func missingUsageDescriptionThrowsInsteadOfCrashing() async {
        let camera = StubPermissionProvider(.camera, requiredUsageDescriptionKeys: ["NSCameraUsageDescription"])
        let permissions = PermissionManager(
            registry: PermissionProviderRegistry([camera]),
            usageDescriptions: InfoPlist([:])
        )

        await #expect(throws: PermissionError.missingUsageDescription(.camera, keys: ["NSCameraUsageDescription"])) {
            _ = try await permissions.request(.camera)
        }
    }
}
