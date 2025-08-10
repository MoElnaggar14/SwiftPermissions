import SwiftUI
import SwiftPermissions

struct ContentView: View {
    @StateObject private var permissionManager = ObservablePermissionManager.shared
    @State private var showPermissionsDashboard = false
    @State private var showCameraAlert = false
    @State private var requestResults: [PermissionResult] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    
                    quickActionsSection
                    
                    permissionStatusSection
                    
                    batchRequestsSection
                    
                    resultsSection
                }
                .padding()
            }
            .navigationTitle("SwiftPermissions Example")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Dashboard") {
                        showPermissionsDashboard = true
                    }
                }
            }
            .sheet(isPresented: $showPermissionsDashboard) {
                PermissionsDashboardView(
                    permissions: [.camera, .microphone, .photoLibrary, .locationWhenInUse, .notification, .contacts]
                )
            }
        }
        .permissionAlert(
            for: .camera,
            isPresented: $showCameraAlert,
            config: PermissionConfig(
                title: "Camera Access Required",
                message: "This example needs camera access to demonstrate permission requests."
            )
        )
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("SwiftPermissions Example")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Demonstrating comprehensive permission management")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var quickActionsSection: some View {
        VStack(spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                PermissionButton(
                    title: "Camera",
                    systemImage: "camera",
                    permission: .camera
                )
                
                PermissionButton(
                    title: "Location",
                    systemImage: "location",
                    permission: .locationWhenInUse
                )
                
                PermissionButton(
                    title: "Notifications",
                    systemImage: "bell",
                    permission: .notification
                )
                
                PermissionButton(
                    title: "Microphone",
                    systemImage: "mic",
                    permission: .microphone
                )
            }
        }
    }
    
    private var permissionStatusSection: some View {
        VStack(spacing: 16) {
            Text("Permission Status")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                PermissionStatusView(.camera)
                PermissionStatusView(.microphone)
                PermissionStatusView(.photoLibrary)
                PermissionStatusView(.locationWhenInUse)
                PermissionStatusView(.notification)
                PermissionStatusView(.contacts)
            }
        }
    }
    
    private var batchRequestsSection: some View {
        VStack(spacing: 16) {
            Text("Batch Requests")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                BatchRequestButton(
                    title: "Media Permissions",
                    subtitle: "Camera, Microphone, Photo Library",
                    permissions: .media,
                    color: .purple
                ) { results in
                    requestResults = results
                }
                
                BatchRequestButton(
                    title: "Location Permissions",
                    subtitle: "Location, Notifications",
                    permissions: .location,
                    color: .blue
                ) { results in
                    requestResults = results
                }
                
                BatchRequestButton(
                    title: "Social Permissions",
                    subtitle: "Contacts, Camera, Photo Library, Notifications",
                    permissions: .social,
                    color: .green
                ) { results in
                    requestResults = results
                }
            }
        }
    }
    
    private var resultsSection: some View {
        if !requestResults.isEmpty {
            VStack(spacing: 16) {
                Text("Last Request Results")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 8) {
                    ForEach(requestResults.indices, id: \.self) { index in
                        let result = requestResults[index]
                        ResultRow(result: result)
                    }
                }
                
                Button("Clear Results") {
                    requestResults = []
                }
                .foregroundColor(.red)
            }
        }
    }
}

struct PermissionButton: View {
    let title: String
    let systemImage: String
    let permission: PermissionType
    
    @StateObject private var permissionManager = ObservablePermissionManager.shared
    
    var body: some View {
        Button {
            Task {
                await permissionManager.requestPermission(permission)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title2)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(12)
        }
    }
    
    private var backgroundColor: Color {
        if permissionManager.isAuthorized(permission) {
            return .green.opacity(0.2)
        } else {
            return .gray.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        if permissionManager.isAuthorized(permission) {
            return .green
        } else {
            return .primary
        }
    }
}

struct BatchRequestButton: View {
    let title: String
    let subtitle: String
    let permissions: [PermissionType]
    let color: Color
    let onComplete: ([PermissionResult]) -> Void
    
    var body: some View {
        Button {
            Task {
                let results = await PermissionManager.shared.requestMultiple(permissions)
                await MainActor.run {
                    onComplete(results)
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(color)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct ResultRow: View {
    let result: PermissionResult
    
    var body: some View {
        HStack {
            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.isSuccess ? .green : .red)
            
            Text(result.type.description)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(result.status.rawValue.capitalized)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(statusBackgroundColor)
                .foregroundColor(statusForegroundColor)
                .cornerRadius(8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var statusBackgroundColor: Color {
        switch result.status {
        case .authorized, .provisional:
            return .green.opacity(0.2)
        case .denied, .restricted:
            return .red.opacity(0.2)
        case .notDetermined:
            return .orange.opacity(0.2)
        }
    }
    
    private var statusForegroundColor: Color {
        switch result.status {
        case .authorized, .provisional:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        }
    }
}

// Extensions for permission groups
extension Array where Element == PermissionType {
    static let media: [PermissionType] = [.camera, .microphone, .photoLibrary]
    static let location: [PermissionType] = [.locationWhenInUse, .notification]
    static let social: [PermissionType] = [.contacts, .camera, .photoLibrary, .notification]
    static let fitness: [PermissionType] = [.motion, .health, .locationWhenInUse, .notification]
    static let all: [PermissionType] = PermissionType.allCases
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
