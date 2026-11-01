import Foundation
@testable import SwiftPermissionsCore
import Testing

@Suite("Limitation")
struct LimitationTests {
    @Test(arguments: Limitation.allCases)
    func limitedKeepsItsReason(limitation: Limitation) {
        let status: PermissionStatus = .limited(limitation)

        #expect(status.limitation == limitation)
        #expect(status.isLimited)
        #expect(status.isGranted)
        #expect(!status.canRequest)
        #expect(!status.requiresSettings)
    }

    @Test func onlyLimitedHasALimitation() {
        let limited = PermissionStatus.everyStatus.filter(\.isLimited)

        #expect(limited == Limitation.allCases.map(PermissionStatus.limited))
        #expect(PermissionStatus.everyStatus.compactMap(\.limitation) == Limitation.allCases)
    }

    @Test func reasonsAreDistinct() {
        #expect(PermissionStatus.limited(.selectedItems) != .limited(.whenInUse))
        #expect(Set(PermissionStatus.everyStatus).count == PermissionStatus.everyStatus.count)
    }

    @Test func descriptionIsTheStoredForm() {
        #expect(PermissionStatus.authorized.description == "authorized")
        #expect(PermissionStatus.notDetermined.description == "notDetermined")
        #expect(PermissionStatus.limited(.selectedItems).description == "limited.selectedItems")
        #expect(PermissionStatus.limited(.whenInUse).description == "limited.whenInUse")
    }

    @Test func codableFormIsOneStringPerStatus() throws {
        let data = try JSONEncoder().encode(PermissionStatus.everyStatus)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json == """
        ["notDetermined","denied","restricted","authorized","limited.selectedItems","limited.whenInUse",\
        "limited.writeOnly","limited.partial","provisional","unavailable"]
        """)
        #expect(try JSONDecoder().decode([PermissionStatus].self, from: data) == PermissionStatus.everyStatus)
    }

    @Test func bare3xLimitedDecodesAsPartial() throws {
        let data = try JSONEncoder().encode(["limited"])

        #expect(try JSONDecoder().decode([PermissionStatus].self, from: data) == [.limited(.partial)])
        #expect(PermissionStatus(storageValue: "limited") == .limited(.partial))
    }

    @Test func bare3xLimitedTakesThePermissionsReason() {
        #expect(PermissionStatus(storageValue: "limited", permission: .photoLibrary) == .limited(.selectedItems))
        #expect(PermissionStatus(storageValue: "limited", permission: .contacts) == .limited(.selectedItems))
        #expect(PermissionStatus(storageValue: "limited", permission: .locationAlways) == .limited(.whenInUse))
        #expect(PermissionStatus(storageValue: "limited", permission: .calendar) == .limited(.writeOnly))
        #expect(PermissionStatus(storageValue: "limited", permission: .health) == .limited(.partial))
        #expect(PermissionStatus(storageValue: "limited", permission: Permission("custom")) == .limited(.partial))
    }

    @Test func storedReasonWinsOverThePermission() {
        #expect(PermissionStatus(storageValue: "limited.partial", permission: .photoLibrary) == .limited(.partial))
    }

    @Test(arguments: ["", "Limited", "limited.", "limited.everything", "authorized.selectedItems"])
    func rejectsUnknownValues(value: String) throws {
        let data = try JSONEncoder().encode([value])

        #expect(PermissionStatus(storageValue: value) == nil)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode([PermissionStatus].self, from: data) }
    }

    @Test func flowProgressRoundTripsTheReason() throws {
        var progress = PermissionFlowProgress()
        progress.record(.skipped(.limited(.selectedItems)), for: .photoLibrary)
        progress.record(.answered(.limited(.whenInUse)), for: .locationAlways)

        #expect(progress.rawValue.contains(#""limited.selectedItems""#))
        #expect(PermissionFlowProgress(rawValue: progress.rawValue) == progress)
    }

    @Test func flowProgressSavedBy3xReadsEachStepsReason() throws {
        let json = """
        {"outcomes":{"photoLibrary":{"skipped":{"_0":"limited"}},"locationAlways":{"answered":{"_0":"limited"}},\
        "calendar":{"deferred":{"_0":"limited"}},"camera":{"failed":{}}}}
        """
        let progress = try #require(PermissionFlowProgress(rawValue: json))

        #expect(progress[.photoLibrary] == .skipped(.limited(.selectedItems)))
        #expect(progress[.locationAlways] == .answered(.limited(.whenInUse)))
        #expect(progress[.calendar] == .deferred(.limited(.writeOnly)))
        #expect(progress[.camera] == .failed)
    }

    @Test func flowProgressWithAnUnknownStatusIsNil() {
        #expect(PermissionFlowProgress(rawValue: #"{"outcomes":{"camera":{"skipped":{"_0":"maybe"}}}}"#) == nil)
    }

    @Test func requestHistoryStoresTheReason() throws {
        let scratch = try ScratchDefaults()
        defer { scratch.remove() }

        UserDefaultsRequestHistory(defaults: scratch.defaults).recordResult(.limited(.partial), for: .localNetwork)

        #expect(scratch.defaults.string(forKey: "SwiftPermissions.localNetwork.lastResult") == "limited.partial")
        #expect(UserDefaultsRequestHistory(defaults: scratch.defaults).lastResult(.localNetwork) == .limited(.partial))
    }

    @Test func requestHistorySavedBy3xReadsThePermissionsReason() throws {
        let scratch = try ScratchDefaults()
        defer { scratch.remove() }

        scratch.defaults.set("limited", forKey: "SwiftPermissions.calendar.lastResult")
        #expect(UserDefaultsRequestHistory(defaults: scratch.defaults).lastResult(.calendar) == .limited(.writeOnly))
    }
}
