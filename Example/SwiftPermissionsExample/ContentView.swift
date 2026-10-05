import SwiftPermissions
import SwiftPermissionsCamera
import SwiftPermissionsContacts
import SwiftPermissionsLocation
import SwiftPermissionsPhotos
import SwiftUI

/// Demonstrates the three common ways to use SwiftPermissions in SwiftUI.
///
/// Link the products for the permissions you use (SwiftPermissionsCamera, …) and add
/// their usage descriptions (NSCameraUsageDescription, …) to the app's Info.plist.
/// Missing keys surface as an alert instead of a crash.
struct ContentView: View {
    @StateObject private var permissions = PermissionStore(permissions: [
        .camera, .microphone, .photoLibrary, .contacts, .locationWhenInUse, .notifications
    ])

    var body: some View {
        NavigationView {
            List {
                Section("Gate a feature") {
                    NavigationLink("Camera") {
                        PermissionGate(.camera, message: "Scan documents with your camera.", store: permissions) {
                            Label("Camera is ready", systemImage: "camera.viewfinder")
                                .font(.title2)
                        }
                        .navigationTitle("Camera")
                    }
                }

                Section("Onboarding / privacy settings") {
                    NavigationLink("All permissions") {
                        PermissionsList(
                            [.camera, .microphone, .photoLibrary, .contacts, .locationWhenInUse, .notifications],
                            footer: "You can change these at any time in Settings.",
                            store: permissions
                        )
                        .navigationTitle("Permissions")
                    }
                }

                Section("Custom flow") {
                    RecordButton(store: permissions)
                }
            }
            .navigationTitle("SwiftPermissions")
        }
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
            Button("Record a video") {
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

#Preview {
    ContentView()
}
