# The control tower: an actor that never hangs

> The bug report said "the app freezes on the map screen." It didn't freeze. A `CheckedContinuation` was waiting for an answer to a prompt iOS had decided not to show.

Part 1 gave us a vocabulary. This part is about the thing that speaks it: `PermissionManager`, the actor between your features and the providers.

Picture an airport control tower. Providers are the airlines; each boards its passengers its own way. The tower doesn't care how. Its job is sequencing: one plane per runway at a time (one prompt per permission), no plane left circling forever (no hung requests), and every change announced on the radio (status streams). This article walks through each of those jobs and the failure that motivated it.

## Why an actor

Permission state is shared, mutable and touched from everywhere: a view model asks for the camera while an onboarding flow asks for notifications, and a background refresh reads both. In Swift 6 that's exactly what actors are for.

```swift
public actor PermissionManager: PermissionManaging {
    private var lastKnown: [Permission: PermissionStatus] = [:]
    private var inFlight: [Permission: (id: UUID, task: Task<PermissionStatus, any Error>)] = [:]
    // …
}
```

Two dictionaries are the tower's whole state: the last status it announced for each permission, and the request currently on the runway. Everything below is about keeping those two honest.

## Job 1: one prompt, however many callers

Two screens appear at once and both call `request(.camera)`. Without coordination you get two calls into the framework, and what happens next depends on which framework it is: one prompt or two, one answer or a stale one, callbacks in whatever order the delegates fire. Behaviour that differs per framework is exactly what a unifying layer must not leak.

The manager stores the in-flight request as a `Task` and lets later callers await the same one:

```swift
public func request(_ permission: Permission) async throws(PermissionError) -> PermissionStatus {
    let pending: (id: UUID, task: Task<PermissionStatus, any Error>)
    if let current = inFlight[permission] {
        pending = current                               // join the request on the runway
    } else {
        pending = try makeRequestTask(for: permission)  // or start a new one
    }
    // … await pending.task, then publish the result
}
```

The test is short:

```swift
func testConcurrentRequestsShowOnePrompt() async throws {
    let camera = StubPermissionProvider(.camera, onRequest: .grant, requestDelay: 0.2)
    let manager = PermissionManager.stubbed(camera)

    async let first = manager.request(.camera)
    async let second = manager.request(.camera)
    _ = try await (first, second)

    let prompts = await camera.requestCount
    XCTAssertEqual(prompts, 1)
}
```

There's a subtlety in clearing the slot. A caller can resume *after* a newer request has started. If it blindly set `inFlight[permission] = nil` it would orphan the newer one, and the next caller would stack a second prompt. So each request carries an id, and only the request that's still current may clear its own slot.

## Job 2: cancelling yourself, not everyone

A user opens a screen, it requests the microphone, and they swipe back before answering. SwiftUI cancels the screen's task. What should happen?

- The screen should stop waiting. It's gone.
- The prompt must stay up. Another caller may be waiting on it, and you can't dismiss a system alert anyway.
- A new request a moment later should join that prompt, not stack a second one.

Plain `await task.value` gets this wrong: cancelling the waiter doesn't stop the wait. The manager uses a small helper that races the shared task against the caller's own cancellation:

```swift
// Awaits a shared task's value, but lets this caller stop waiting when its own task
// is cancelled. The shared task keeps running for everyone else waiting on it.
func awaitValue<Value: Sendable>(of task: Task<Value, any Error>) async throws -> Value
```

Inside, a `withTaskCancellationHandler` resumes a continuation exactly once, with whichever arrives first: the result or the cancellation. The cancelled caller gets `PermissionError.cancelled(.microphone)`. The request stays in `inFlight`, so the next caller joins it.

It's the difference between hanging up your phone and cutting the line for the whole building.

## Job 3: never let the system terminate the app

Ask for the camera without `NSCameraUsageDescription` in Info.plist and iOS doesn't throw. It kills the process. Teams find out in TestFlight, or from App Review.

Each provider declares the keys its prompt needs, and the manager checks them before the prompt:

```swift
let task = Task<PermissionStatus, any Error> {
    let current = await provider.status()
    guard provider.canRequest(from: current) else { return current }
    // Only a prompt needs the usage description; reading a status never does.
    guard missing.isEmpty else { throw PermissionError.missingUsageDescription(permission, keys: missing) }
    return try await provider.request()
}
```

Note the order. If the permission was already decided, `request` returns the status and never checks the keys: there's no prompt to crash. The check only runs when a prompt would appear, which is the only time the system enforces it.

`UsageDescriptionSource` is a port too, so tests can pass a dictionary instead of the main bundle. Part 4 turns this into a unit test that fails CI before App Review does.

## Job 4: nothing circles forever

Every hung permission request I've debugged came down to one of three cases where the system *doesn't answer*. The manager or the provider handles each one.

**The app isn't active.** iOS ignores permission prompts while the app is in the background or inactive, for example the instant after another alert closes. App Tracking Transparency is notorious for this: request it in `didFinishLaunching` and the callback never comes. The Location and Tracking providers first wait for `didBecomeActiveNotification`, then ask. In an app extension there's no shared application to wait for, so they ask straight away.

**Location Services are off system-wide.** With the global switch off, `CLLocationManager` can't show a prompt and the status stays `.notDetermined` forever. The provider checks `locationServicesEnabled()` (off the main thread, because it can block) and reports `.unavailable`. That's honest: from the app's point of view, the capability doesn't exist right now.

**The Always upgrade that isn't shown.** This is the one from the epigraph. If the user granted When In Use, asking for Always shows an upgrade prompt, but iOS shows it *at most once*. Ask a second time and nothing appears. Worse, if the user taps "Keep Only While Using", the delegate gets no callback at all, because the status didn't change.

There's no API that tells you whether the prompt appeared. But there is a signal: a system alert makes the app resign active. So the provider watches the app's lifecycle during an upgrade:

```swift
// The app resigning active means a prompt is on screen; becoming active again means
// it was answered. No resign within a short window means no prompt is coming.
observe(willResignActive)  { upgradePromptShown = true }
observe(didBecomeActive)   { if upgradePromptShown { finish(with: manager.authorizationStatus) } }
after(1.5 seconds)         { if !upgradePromptShown { finish(with: manager.authorizationStatus) } }
```

If no prompt appears within 1.5 seconds, the request returns `.limited`. If the user keeps While Using, it returns `.limited` as soon as they're back. Either way the continuation resumes exactly once.

## Job 5: announce every change

Statuses change behind the app's back: the user flips a switch in Settings, or a parent changes Screen Time rules. The manager publishes through two streams:

```swift
for await status in permissions.updates(for: .camera) { … }   // current status first, then changes
for await change in permissions.changes() { … }              // every permission
```

`updates(for:)` uses `.bufferingNewest(1)`, so a slow consumer sees the latest status, not a backlog. Each subscriber gets the current status exactly once, even when a change races with subscribing. The subscriber registry is lock-protected rather than actor-isolated, so a stream created by `changes()` can't miss a change published the moment after it returns.

The manager only republishes a status when it differs from `lastKnown`, so `refresh()` (call it when the app becomes active) is cheap: it re-reads everything that's been read, requested or observed, and announces only real changes. The SwiftUI layer calls it for you.

## Upgrades are just requests

One more consequence of letting providers answer `canRequest(from:)`: upgrades need no special API.

```swift
let permissions = PermissionManager(permissions: [.locationWhenInUse, .locationAlways])

_ = try await permissions.request(.locationWhenInUse)       // first prompt
// later, when the feature needs background location:
if await permissions.canRequest(.locationAlways) {
    _ = try await permissions.request(.locationAlways)      // upgrade prompt, from .limited
}
```

The same works for write-only to full calendar access, and provisional to full notifications. `canRequest(_:)` returns `true` only when a prompt can actually appear, so your "Allow More" button doesn't lie.

## Recap

| Failure | What the tower does |
| --- | --- |
| Two callers, two prompts | Joins the in-flight `Task` |
| Cancelled screen dismisses everyone | Cancels the waiter, not the request |
| Missing Info.plist key kills the app | Throws `missingUsageDescription` before prompting |
| Prompt ignored while inactive | Waits for the app to become active |
| Location Services off | Reports `.unavailable` |
| Always upgrade never shown | Watches the app lifecycle and returns `.limited` |
| Changes made in Settings | `refresh()` and `AsyncStream`s |

Next: [link only what you use](03-link-only-what-you-use.md), where the module boundaries matter as much to App Review as to the architecture.
