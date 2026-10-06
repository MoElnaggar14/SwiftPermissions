import Foundation

/// Where usage descriptions (`NS…UsageDescription`) are looked up.
public protocol UsageDescriptionSource: Sendable {
    /// The non-empty usage description for `key`, or `nil`.
    func usageDescription(forKey key: String) -> String?
}

/// A snapshot of the string values in an Info.plist.
public struct InfoPlist: UsageDescriptionSource, Equatable {
    private let values: [String: String]

    public init(_ values: [String: String]) {
        self.values = values
    }

    /// Reads the bundle's string values. An array of strings, such as `NSBonjourServices`,
    /// is kept as its elements joined by newlines.
    public init(bundle: Bundle) {
        self.init((bundle.infoDictionary ?? [:]).compactMapValues(Self.stringValue))
    }

    static func stringValue(_ value: Any) -> String? {
        if let string = value as? String { return string }
        if let strings = value as? [String] { return strings.joined(separator: "\n") }
        return nil
    }

    /// The main bundle's Info.plist.
    public static var main: InfoPlist { InfoPlist(bundle: .main) }

    public func usageDescription(forKey key: String) -> String? {
        guard let value = values[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }
}
