import Foundation

/// Remembers, for the life of the process, that a provider has asked the user.
///
/// Screen Recording and Accessibility only report granted or not granted, so "never
/// asked" and "declined" look the same. Providers for them report
/// ``PermissionStatus/notDetermined`` until they have asked, and
/// ``PermissionStatus/denied`` afterwards.
package final class RequestedFlag: @unchecked Sendable {
    // @unchecked: `requested` is only read and written while holding `lock`.
    private let lock = NSLock()
    private var requested = false

    package init() {}

    package var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return requested
    }

    package func set() {
        lock.lock()
        requested = true
        lock.unlock()
    }
}
