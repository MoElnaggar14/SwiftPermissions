#if canImport(UIKit) && !os(watchOS)
import UIKit

/// Waits for the app to become active. System prompts (ATT in particular) are
/// ignored while the app is inactive, e.g. right after another alert closed.
@MainActor
enum AppActivation {
    static func waitUntilActive() async {
        guard UIApplication.shared.applicationState != .active else { return }
        let observation = OneShotObservation()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            observation.token = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                observation.finish { continuation.resume() }
            }
        }
    }
}

/// Removes its observer and runs `body` the first time it finishes.
final class OneShotObservation: @unchecked Sendable {
    // Only touched on the main queue.
    var token: (any NSObjectProtocol)?
    private var finished = false

    func finish(_ body: () -> Void) {
        guard !finished else { return }
        finished = true
        if let token { NotificationCenter.default.removeObserver(token) }
        token = nil
        body()
    }
}
#endif
