import Foundation

/// How far a permission flow got: the outcome of each finished step.
///
/// The package stores nothing. Persist this value yourself so the flow continues from
/// where it stopped on the next launch. It's `Codable`, and `RawRepresentable` as a JSON
/// string, so it works with `@AppStorage` directly:
///
/// ```swift
/// @AppStorage("onboardingPermissions") private var progress = PermissionFlowProgress()
/// ```
///
/// Progress saved by 4.0, where a limited status is stored with its reason
/// (`"limited.selectedItems"`), reads back with that status as ``PermissionStatus/limited``.
public struct PermissionFlowProgress: Sendable, Equatable, Codable, RawRepresentable {
    /// The outcome of each finished step.
    public private(set) var outcomes: [Permission: PermissionFlowStepOutcome]

    public init(outcomes: [Permission: PermissionFlowStepOutcome] = [:]) {
        self.outcomes = outcomes
    }

    public subscript(permission: Permission) -> PermissionFlowStepOutcome? {
        outcomes[permission]
    }

    /// Records how the step for `permission` ended.
    public mutating func record(_ outcome: PermissionFlowStepOutcome, for permission: Permission) {
        outcomes[permission] = outcome
    }

    /// Forgets the outcome for `permission`, so the flow shows that step again. Use it to
    /// ask again later for a step the user deferred.
    public mutating func forget(_ permission: Permission) {
        outcomes[permission] = nil
    }

    /// Forgets every outcome, so the flow starts over.
    public mutating func reset() {
        outcomes = [:]
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case outcomes
    }

    // Written out rather than synthesised: the standard library's `Codable` defaults for
    // `RawRepresentable` would encode `rawValue`, which encodes `self` again.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let stored = try container.decode([String: PermissionFlowStepOutcome].self, forKey: .outcomes)
        var outcomes: [Permission: PermissionFlowStepOutcome] = [:]
        for (rawValue, outcome) in stored {
            outcomes[Permission(rawValue: rawValue)] = outcome
        }
        self.outcomes = outcomes
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var stored: [String: PermissionFlowStepOutcome] = [:]
        for (permission, outcome) in outcomes {
            stored[permission.rawValue] = outcome
        }
        try container.encode(stored, forKey: .outcomes)
    }

    // MARK: RawRepresentable

    /// Decodes progress saved with ``rawValue``. Returns `nil` for anything else.
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let progress = try? JSONDecoder().decode(PermissionFlowProgress.self, from: data) else {
            return nil
        }
        self = progress
    }

    /// The progress as a JSON string.
    public var rawValue: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self), let json = String(data: data, encoding: .utf8) else {
            return "{\"outcomes\":{}}"
        }
        return json
    }

    // Written out so `==` compares outcomes rather than the JSON from `rawValue`.
    public static func == (lhs: PermissionFlowProgress, rhs: PermissionFlowProgress) -> Bool {
        lhs.outcomes == rhs.outcomes
    }
}
