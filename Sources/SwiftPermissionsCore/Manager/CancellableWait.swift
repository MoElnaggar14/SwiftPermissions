import Foundation

/// Awaits a shared task's value, but lets this caller stop waiting when its own task
/// is cancelled. The shared task keeps running for everyone else waiting on it.
func awaitValue<Value: Sendable>(of task: Task<Value, any Error>) async throws -> Value {
    let gate = ResumeOnce<Value>()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            gate.install(continuation)
            Task {
                do {
                    gate.resume(with: .success(try await task.value))
                } catch {
                    gate.resume(with: .failure(error))
                }
            }
        }
    } onCancel: {
        gate.resume(with: .failure(CancellationError()))
    }
}

/// Resumes a continuation exactly once, whichever of the result and the
/// continuation arrives first.
private final class ResumeOnce<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?
    private var early: Result<Value, any Error>?
    private var resumed = false

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    func install(_ continuation: CheckedContinuation<Value, any Error>) {
        let result: Result<Value, any Error>? = locked {
            if let early {
                resumed = true
                return early
            }
            self.continuation = continuation
            return nil
        }
        if let result { continuation.resume(with: result) }
    }

    func resume(with result: Result<Value, any Error>) {
        let continuation: CheckedContinuation<Value, any Error>? = locked {
            guard !resumed else { return nil }
            guard let continuation = self.continuation else {
                if early == nil { early = result }
                return nil
            }
            resumed = true
            self.continuation = nil
            return continuation
        }
        continuation?.resume(with: result)
    }
}
