import SwiftPermissions
import SwiftPermissionsBiometrics
import SwiftPermissionsLocation
import SwiftUI

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

                Section("Custom flows") {
                    RecordButton(store: permissions)
                    BiometricsButton()
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
