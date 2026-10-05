import Foundation

/// Fans `PermissionChange`s out to subscribers.
///
/// Subscribing is synchronous (lock-protected rather than actor-isolated) so a stream
/// returned from ``PermissionManager/changes()`` can't miss a change published right
/// after it was created.
final class ChangeBroadcaster: @unchecked Sendable {
    private struct Subscriber {
        let permission: Permission?
        let send: @Sendable (PermissionChange) -> Void
        let finish: @Sendable () -> Void
        var hasReceivedValue = false
    }

    private let lock = NSLock()
    private var subscribers: [UUID: Subscriber] = [:]

    /// Permissions with at least one dedicated subscriber.
    var observedPermissions: Set<Permission> {
        locked { Set(subscribers.values.compactMap(\.permission)) }
    }

    func subscribe(
        to permission: Permission? = nil,
        send: @escaping @Sendable (PermissionChange) -> Void,
        finish: @escaping @Sendable () -> Void
    ) -> UUID {
        let id = UUID()
        locked { subscribers[id] = Subscriber(permission: permission, send: send, finish: finish) }
        return id
    }

    func unsubscribe(_ id: UUID) {
        locked { subscribers[id] = nil }
    }

    func send(_ change: PermissionChange) {
        let recipients = locked { () -> [Subscriber] in
            var matching: [Subscriber] = []
            for (id, subscriber) in subscribers
            where subscriber.permission == nil || subscriber.permission == change.permission {
                subscribers[id]?.hasReceivedValue = true
                matching.append(subscriber)
            }
            return matching
        }
        recipients.forEach { $0.send(change) }
    }

    /// Sends `change` to one subscriber unless it has already received a value.
    func sendIfUndelivered(_ change: PermissionChange, to id: UUID) {
        let recipient = locked { () -> Subscriber? in
            guard let subscriber = subscribers[id], !subscriber.hasReceivedValue else { return nil }
            subscribers[id]?.hasReceivedValue = true
            return subscriber
        }
        recipient?.send(change)
    }

    func finishAll() {
        let recipients = locked {
            defer { subscribers.removeAll() }
            return Array(subscribers.values)
        }
        recipients.forEach { $0.finish() }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
