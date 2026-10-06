import SwiftPermissions
import SwiftPermissionsBiometrics
import SwiftPermissionsContacts
import SwiftPermissionsLocation
import SwiftPermissionsPhotos
import SwiftUI
import UIKit

/// Tours the ways to use SwiftPermissions in SwiftUI: gating a feature, upgrades,
/// a custom multi-permission flow, an onboarding list and a live change log.
///
/// Every usage description is in `Example/Info.plist`. Remove one to see the
/// `missingUsageDescription` alert instead of a crash.
struct ContentView: View {
    let changes: any PermissionObserving
    @EnvironmentObject private var permissions: PermissionStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("Camera") {
                        CameraScreen(store: permissions)
                    }
                } header: {
                    Text("Gate a feature")
                } footer: {
                    Text("PermissionGate shows its content once granted, and the right prompt until then. Not Now goes back without spending the system prompt.")
                }

                Section {
                    PermissionRow(.locationWhenInUse, store: permissions)
                    PermissionRow(.locationAlways, store: permissions)
                    PreciseLocationRow(store: permissions)
                    PermissionRow(.calendar, store: permissions)
                } header: {
                    Text("Upgrades")
                } footer: {
                    Text("Allow location while using first, then Always: the row offers Allow More while an upgrade prompt can still appear. Turn off Precise when allowing location to see Ask Once.")
                }

                Section {
                    LimitedPhotosRow(store: permissions)
                    LimitedContactsRow(store: permissions)
                } header: {
                    Text("Limited access")
                } footer: {
                    Text("Choose Limit Access when allowing Photos or Contacts: the row then offers Select More… to share more items without leaving the app.")
                }

                Section("Custom flows") {
                    RecordButton(store: permissions)
                    BiometricsButton()
                    if #available(iOS 18.0, *) {
                        LocationSessionRow()
                    }
                }

                Section {
                    NavigationLink("All permissions") {
                        PermissionsList(
                            ExamplePermissions.all,
                            footer: "You can change these at any time in Settings.",
                            store: permissions
                        )
                        .navigationTitle("Permissions")
                    }
                    NavigationLink("Live changes") {
                        ChangeLog(changes: changes)
                            .navigationTitle("Live changes")
                    }
                } header: {
                    Text("Onboarding and diagnostics")
                } footer: {
                    Text("Change a permission in Settings and come back: the list refreshes and the change log records it.")
                }
            }
            .navigationTitle("SwiftPermissions")
        }
        .refreshesPermissions(permissions)
        .alert(
            "Can't request permission",
            isPresented: Binding(
                get: { permissions.lastError != nil },
                set: { if !$0 { permissions.lastError = nil } }
            ),
            presenting: permissions.lastError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.description)
        }
    }
}

/// Requests two permissions in sequence and reacts to the combined result.
private struct RecordButton: View {
    @ObservedObject var store: PermissionStore
    @State private var outcome = ""

    var body: some View {
        VStack(alignment: .leading) {
            Button("Record a video (camera + microphone)") {
                Task {
                    let result = await store.request([.camera, .microphone])
                    outcome = result.allGranted
                        ? "Recording…"
                        : "Missing: \(result.notGranted.map(\.displayName).sorted().joined(separator: ", "))"
                }
            }
            if !outcome.isEmpty {
                Text(outcome).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

/// Location can be authorized with Precise turned off. The status stays `.authorized`;
/// the accuracy says how exact the coordinates are, and Ask Once requests precise
/// location for this session.
private struct PreciseLocationRow: View {
    @ObservedObject var store: PermissionStore
    @State private var accuracy: LocationAccuracy?
    @State private var outcome = ""

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Precise location")
                Spacer()
                switch accuracy {
                case .full?: Text("Precise").foregroundStyle(.secondary)
                case .reduced?:
                    Button("Ask Once") {
                        Task {
                            do {
                                accuracy = try await LocationPermissionProvider.whenInUse
                                    .requestTemporaryFullAccuracy(purposeKey: "NearbyPlaces")
                            } catch {
                                outcome = "\(error)"
                            }
                        }
                    }
                case nil: Text("Allow location first").foregroundStyle(.secondary)
                }
            }
            if !outcome.isEmpty {
                Text(outcome).font(.footnote).foregroundStyle(.secondary)
            }
        }
        // Re-read whenever a location status changes, e.g. after Settings.
        .task(id: [store[.locationWhenInUse], store[.locationAlways]]) {
            accuracy = await LocationPermissionProvider.whenInUse.accuracy()
        }
    }
}

/// With limited photo access, Select More… shows the system picker so people can
/// share more photos without a trip to Settings.
private struct LimitedPhotosRow: View {
    @ObservedObject var store: PermissionStore
    @State private var outcome = ""

    var body: some View {
        VStack(alignment: .leading) {
            PermissionRow(.photoLibrary, store: store) {
                guard let controller = UIApplication.shared.topViewController else { return }
                Task {
                    let added = await PhotoLibraryPermissionProvider.readWrite
                        .presentLimitedLibraryPicker(from: controller)
                    outcome = "Added \(added.count) photo(s)"
                }
            }
            if !outcome.isEmpty {
                Text(outcome).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

/// Limited contacts access (iOS 18) has its own picker, presented as a SwiftUI modifier.
private struct LimitedContactsRow: View {
    @ObservedObject var store: PermissionStore
    @State private var picking = false
    @State private var outcome = ""

    var body: some View {
        VStack(alignment: .leading) {
            if #available(iOS 18, *) {
                PermissionRow(.contacts, store: store) { picking = true }
                    .limitedContactsPicker(isPresented: $picking) { added in
                        outcome = "Added \(added.count) contact(s)"
                    }
            } else {
                PermissionRow(.contacts, store: store)
            }
            if !outcome.isEmpty {
                Text(outcome).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

private extension UIApplication {
    /// The view controller to present UIKit pickers from.
    var topViewController: UIViewController? {
        let scene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// A Core Location service session (iOS 18). The row owns the session: it lasts while
/// the row is on screen and Stop hasn't been tapped, and the status follows its diagnostics.
@available(iOS 18.0, *)
private struct LocationSessionRow: View {
    @State private var session: LocationServiceSession?
    @State private var update: LocationServiceSession.Update?
    @State private var outcome = ""

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Location session")
                Spacer()
                if session == nil {
                    Button("Start") { start() }
                } else {
                    Button("Stop") { stop() }
                }
            }
            if let update {
                Text(describe(update)).font(.footnote).foregroundStyle(.secondary)
            }
            if !outcome.isEmpty {
                Text(outcome).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        Task {
            do {
                let session = try await LocationPermissionProvider.whenInUse.startServiceSession()
                self.session = session
                outcome = ""
                for await update in session.updates {
                    self.update = update
                }
            } catch {
                outcome = "\(error)"
            }
        }
    }

    private func stop() {
        session?.invalidate()
        session = nil
        update = nil
    }

    private func describe(_ update: LocationServiceSession.Update) -> String {
        let diagnostic = update.diagnostic
        let notes = [
            diagnostic.authorizationRequestInProgress ? "prompt showing" : nil,
            diagnostic.insufficientlyInUse ? "app not in use" : nil,
            diagnostic.fullAccuracyDenied ? "approximate" : nil
        ].compactMap { $0 }
        return ([update.status.description] + notes).joined(separator: " · ")
    }
}

/// Biometrics never prompts from `request(_:)`: the prompt is the authentication itself.
private struct BiometricsButton: View {
    @State private var outcome = ""

    var body: some View {
        VStack(alignment: .leading) {
            Button("Unlock with Face ID / Touch ID") {
                Task {
                    do {
                        let success = try await BiometricsPermissionProvider().authenticate(reason: "Unlock your notes")
                        outcome = success ? "Unlocked" : "Not recognised"
                    } catch {
                        outcome = "\(error)"
                    }
                }
            }
            if !outcome.isEmpty {
                Text(outcome).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

/// Every status change the manager publishes, newest first.
private struct ChangeLog: View {
    let changes: any PermissionObserving
    @State private var events: [String] = []

    var body: some View {
        List {
            if events.isEmpty {
                Text("No changes yet. Grant or deny something, or change it in Settings.")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(events.enumerated().reversed()), id: \.offset) { _, event in
                Text(event).font(.callout.monospaced())
            }
        }
        .task {
            for await change in changes.changes() {
                let time = Date.now.formatted(date: .omitted, time: .standard)
                events.append("\(time)  \(change.permission.displayName): \(change.status)")
            }
        }
    }
}

/// A gated feature whose prompt offers Not Now. Deferring goes back without
/// spending the one-time system prompt; a real app might remember the date and
/// ask again later.
private struct CameraScreen: View {
    @ObservedObject var store: PermissionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PermissionGate(.camera, message: "Scan documents with your camera.", store: store, onDefer: { dismiss() }) {
            Label("Camera is ready", systemImage: "camera.viewfinder")
                .font(.title2)
        }
        .navigationTitle("Camera")
    }
}

#Preview {
    ContentView(changes: PermissionManager(permissions: [.notifications]))
        .environmentObject(PermissionStore(permissions: [.notifications]))
}
