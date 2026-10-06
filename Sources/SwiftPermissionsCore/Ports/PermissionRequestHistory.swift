import Foundation

/// Remembers which permissions a provider has asked for, and the last answer it saw.
///
/// For some permissions the system can't say whether the app already asked:
///
/// - Screen Recording and Accessibility only report granted or not granted, so "never
///   asked" and "declined" look the same.
/// - Local network has no status API at all.
///
/// Their providers read this history to tell those apart. The default,
/// ``InMemoryRequestHistory``, forgets everything when the app quits, so after a relaunch
/// these permissions read ``PermissionStatus/notDetermined`` again. Pass a
/// ``UserDefaultsRequestHistory`` to remember across launches.
///
/// Providers always trust a granted state reported by the system over the history. The
/// history only turns "not granted" into ``PermissionStatus/denied``, or supplies the local
/// network's last result.
///
/// Methods are synchronous and must be safe to call from any thread.
public protocol PermissionRequestHistory: Sendable {
    /// Whether a request for `permission` has been recorded.
    func hasRequested(_ permission: Permission) -> Bool

    /// Records that `permission` was requested.
    func recordRequest(_ permission: Permission)

    /// The last status recorded for `permission`, or `nil`.
    func lastResult(_ permission: Permission) -> PermissionStatus?

    /// Records the status a request for `permission` ended with.
    func recordResult(_ status: PermissionStatus, for permission: Permission)

    /// Forgets everything recorded for `permission`, for example after the user reset it
    /// with `tccutil reset`.
    func forget(_ permission: Permission)
}

/// A ``PermissionRequestHistory`` that lives as long as the instance, and is lost when the
/// app quits. This is what providers use unless you pass another history.
public final class InMemoryRequestHistory: PermissionRequestHistory, @unchecked Sendable {
    // @unchecked Sendable: `requested` and `results` are only read and written while
    // holding `lock`.
    private let lock = NSLock()
    private var requested: Set<Permission> = []
    private var results: [Permission: PermissionStatus] = [:]

    public init() {}

    public func hasRequested(_ permission: Permission) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return requested.contains(permission)
    }

    public func recordRequest(_ permission: Permission) {
        lock.lock()
        requested.insert(permission)
        lock.unlock()
    }

    public func lastResult(_ permission: Permission) -> PermissionStatus? {
        lock.lock()
        defer { lock.unlock() }
        return results[permission]
    }

    public func recordResult(_ status: PermissionStatus, for permission: Permission) {
        lock.lock()
        results[permission] = status
        lock.unlock()
    }

    public func forget(_ permission: Permission) {
        lock.lock()
        requested.remove(permission)
        results[permission] = nil
        lock.unlock()
    }
}

/// A ``PermissionRequestHistory`` stored in `UserDefaults`, so it survives relaunches.
///
/// ```swift
/// let history = UserDefaultsRequestHistory()
/// let permissions = PermissionManager(permissions: [
///     .screenRecording(history: history),
///     .localNetwork(history: history)
/// ])
/// ```
///
/// Entries are keyed `<keyPrefix><permission>.requested` and
/// `<keyPrefix><permission>.lastResult`, where `<permission>` is the permission's
/// ``Permission/rawValue``.
///
/// The history only knows what this app recorded. Resetting a permission with
/// `tccutil reset` or deleting the app's TCC entry clears the system's state but not this
/// history, so the permission keeps reading ``PermissionStatus/denied``; call
/// ``forget(_:)`` to start over. A grant reported by the system always wins.
///
/// `UserDefaults` is a required-reason API. SwiftPermissions' privacy manifest declares
/// reason `CA92.1` (data only the app itself reads). If you pass the defaults of an app
/// group, your app's manifest must also declare `1C8F.1`.
public final class UserDefaultsRequestHistory: PermissionRequestHistory, @unchecked Sendable {
    // @unchecked Sendable: the only stored properties are immutable, and `UserDefaults`
    // is documented to be thread-safe ("The UserDefaults class is thread-safe"), even in
    // SDKs that don't mark it `Sendable`.
    private let defaults: UserDefaults
    private let keyPrefix: String

    /// - Parameters:
    ///   - defaults: Where the history is stored. Defaults to `.standard`.
    ///   - keyPrefix: Prepended to every key, so entries don't collide with the app's own.
    public init(defaults: UserDefaults = .standard, keyPrefix: String = "SwiftPermissions.") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    public func hasRequested(_ permission: Permission) -> Bool {
        defaults.bool(forKey: requestedKey(permission))
    }

    public func recordRequest(_ permission: Permission) {
        defaults.set(true, forKey: requestedKey(permission))
    }

    public func lastResult(_ permission: Permission) -> PermissionStatus? {
        defaults.string(forKey: resultKey(permission)).flatMap(PermissionStatus.init(storageValue:))
    }

    public func recordResult(_ status: PermissionStatus, for permission: Permission) {
        defaults.set(status.storageValue, forKey: resultKey(permission))
    }

    public func forget(_ permission: Permission) {
        defaults.removeObject(forKey: requestedKey(permission))
        defaults.removeObject(forKey: resultKey(permission))
    }

    func requestedKey(_ permission: Permission) -> String {
        "\(keyPrefix)\(permission.rawValue).requested"
    }

    func resultKey(_ permission: Permission) -> String {
        "\(keyPrefix)\(permission.rawValue).lastResult"
    }
}
