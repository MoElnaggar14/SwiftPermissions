import Foundation
@testable import SwiftPermissionsCore
import Testing

/// A `UserDefaults` suite of its own, so tests never touch `.standard` or each other.
/// Call ``remove()`` when done.
struct ScratchDefaults {
    let name: String
    let defaults: UserDefaults

    init() throws {
        let name = "SwiftPermissionsTests.\(UUID().uuidString)"
        self.name = name
        defaults = try #require(UserDefaults(suiteName: name))
    }

    func remove() {
        defaults.removePersistentDomain(forName: name)
    }
}

@Suite("Request history")
struct RequestHistoryTests {
    @Test func inMemoryHistoryRecordsAndForgets() {
        let history = InMemoryRequestHistory()
        #expect(!history.hasRequested(.screenRecording))
        #expect(history.lastResult(.localNetwork) == nil)

        history.recordRequest(.screenRecording)
        history.recordResult(.denied, for: .localNetwork)
        #expect(history.hasRequested(.screenRecording))
        #expect(!history.hasRequested(.accessibility))
        #expect(history.lastResult(.localNetwork) == .denied)

        history.forget(.screenRecording)
        history.forget(.localNetwork)
        #expect(!history.hasRequested(.screenRecording))
        #expect(history.lastResult(.localNetwork) == nil)
    }

    @Test func inMemoryHistoryIsPerInstance() {
        let first = InMemoryRequestHistory()
        first.recordRequest(.accessibility)
        #expect(!InMemoryRequestHistory().hasRequested(.accessibility))
    }

    @Test func userDefaultsHistorySurvivesANewInstance() throws {
        let scratch = try ScratchDefaults()
        defer { scratch.remove() }

        let before = UserDefaultsRequestHistory(defaults: scratch.defaults)
        before.recordRequest(.screenRecording)
        before.recordResult(.authorized, for: .localNetwork)

        // A relaunch: a new history reading the same defaults.
        let after = UserDefaultsRequestHistory(defaults: scratch.defaults)
        #expect(after.hasRequested(.screenRecording))
        #expect(!after.hasRequested(.accessibility))
        #expect(after.lastResult(.localNetwork) == .authorized)
        #expect(after.lastResult(.screenRecording) == nil)
    }

    @Test func userDefaultsHistoryUsesThePrefixedKeys() throws {
        let scratch = try ScratchDefaults()
        defer { scratch.remove() }

        let history = UserDefaultsRequestHistory(defaults: scratch.defaults)
        history.recordRequest(.accessibility)
        history.recordResult(.denied, for: .localNetwork)
        #expect(scratch.defaults.bool(forKey: "SwiftPermissions.accessibility.requested"))
        #expect(scratch.defaults.string(forKey: "SwiftPermissions.localNetwork.lastResult") == "denied")

        // Another prefix is another history.
        let other = UserDefaultsRequestHistory(defaults: scratch.defaults, keyPrefix: "Other.")
        #expect(!other.hasRequested(.accessibility))
        #expect(other.lastResult(.localNetwork) == nil)
    }

    @Test func userDefaultsHistoryForgets() throws {
        let scratch = try ScratchDefaults()
        defer { scratch.remove() }

        let history = UserDefaultsRequestHistory(defaults: scratch.defaults)
        history.recordRequest(.localNetwork)
        history.recordResult(.denied, for: .localNetwork)
        history.forget(.localNetwork)
        #expect(!history.hasRequested(.localNetwork))
        #expect(history.lastResult(.localNetwork) == nil)
        #expect(scratch.defaults.object(forKey: "SwiftPermissions.localNetwork.requested") == nil)
    }

    @Test func userDefaultsHistoryIgnoresUnknownValues() throws {
        let scratch = try ScratchDefaults()
        defer { scratch.remove() }

        scratch.defaults.set("maybe", forKey: "SwiftPermissions.localNetwork.lastResult")
        #expect(UserDefaultsRequestHistory(defaults: scratch.defaults).lastResult(.localNetwork) == nil)
    }
}
