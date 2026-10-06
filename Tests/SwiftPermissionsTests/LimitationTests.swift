import Foundation
@testable import SwiftPermissionsCore
import Testing

@Suite("Limitation and the 4.0 preparation")
struct LimitationTests {
    @Test(arguments: Limitation.allCases)
    func limitedBuiltWithAReasonIsLimited(limitation: Limitation) {
        let status: PermissionStatus = .limited(limitation)

        #expect(status.isLimited)
        #expect(status.isGranted)
        #expect(!status.canRequest)
        #expect(!status.requiresSettings)
    }

    @Test func onlyLimitedIsLimited() {
        #expect(PermissionStatus.allCases.filter(\.isLimited) == [.limited(.partial)])
    }

    @Test func builtInProvidersReportTheirReason() {
        #expect(Limitation.reported(for: .photoLibrary) == .selectedItems)
        #expect(Limitation.reported(for: .contacts) == .selectedItems)
        #expect(Limitation.reported(for: .locationAlways) == .whenInUse)
        #expect(Limitation.reported(for: .calendar) == .writeOnly)
        #expect(Limitation.reported(for: .health) == .partial)
        #expect(Limitation.reported(for: Permission("custom")) == .partial)
    }

    @Test func descriptionIsTheCaseName() {
        #expect(PermissionStatus.authorized.description == "authorized")
        #expect(PermissionStatus.notDetermined.description == "notDetermined")
        #expect(PermissionStatus.limited(.selectedItems).description == "limited")
    }

    @Test func codableFormIsUnchanged() throws {
        let data = try JSONEncoder().encode(PermissionStatus.allCases)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json == #"["notDetermined","denied","restricted","authorized","limited","provisional","unavailable"]"#)
        #expect(try JSONDecoder().decode([PermissionStatus].self, from: data) == PermissionStatus.allCases)
    }

    @Test(arguments: Limitation.allCases)
    func readsThe40FormAsLimited(limitation: Limitation) throws {
        let stored = "limited.\(limitation.rawValue)"
        let data = try JSONEncoder().encode([stored])

        #expect(PermissionStatus(storageValue: stored) == .limited(limitation))
        #expect(try JSONDecoder().decode([PermissionStatus].self, from: data) == [.limited(limitation)])
    }

    @Test(arguments: ["", "Limited", "limited.", "limited.everything", "authorized.selectedItems"])
    func rejectsUnknownValues(value: String) throws {
        let data = try JSONEncoder().encode([value])

        #expect(PermissionStatus(storageValue: value) == nil)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode([PermissionStatus].self, from: data) }
    }

    @Test func flowProgressSavedBy40Reads() throws {
        let json = #"{"outcomes":{"photoLibrary":{"skipped":{"_0":"limited.selectedItems"}}}}"#
        let progress = try #require(PermissionFlowProgress(rawValue: json))

        #expect(progress[.photoLibrary] == .skipped(.limited(.selectedItems)))
    }

    @Test func requestHistorySavedBy40Reads() throws {
        let scratch = try ScratchDefaults()
        defer { scratch.remove() }

        scratch.defaults.set("limited.partial", forKey: "SwiftPermissions.localNetwork.lastResult")
        #expect(UserDefaultsRequestHistory(defaults: scratch.defaults).lastResult(.localNetwork) == .limited(.partial))
    }

    @Test func requestHistoryStoresTheCaseName() throws {
        let scratch = try ScratchDefaults()
        defer { scratch.remove() }

        UserDefaultsRequestHistory(defaults: scratch.defaults).recordResult(.limited(.partial), for: .localNetwork)
        #expect(scratch.defaults.string(forKey: "SwiftPermissions.localNetwork.lastResult") == "limited")
    }
}
