import SwiftUI
import Combine

// MARK: - Observable Permission Manager
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
@MainActor
public final class ObservablePermissionManager: ObservableObject {
    public static let shared = ObservablePermissionManager()
    
    private let permissionManager: PermissionManagerProtocol
    private var cancellables = Set<AnyCancellable>()
    
    @Published public private(set) var permissionStatuses: [PermissionType: PermissionStatus] = [:]
    @Published public private(set) var isRequestingPermission = false
    
    public init(permissionManager: PermissionManagerProtocol = PermissionManager.shared) {
        self.permissionManager = permissionManager
        setupObservations()
    }
    
    private func setupObservations() {
        permissionManager.permissionStatusChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (type, status) in
                self?.permissionStatuses[type] = status
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    public func checkStatus(for type: PermissionType) async {
        let status = await permissionManager.status(for: type)
        permissionStatuses[type] = status
    }
    
    public func requestPermission(_ type: PermissionType, config: PermissionConfig? = nil) async -> PermissionResult {
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        
        let result = await permissionManager.request(type, config: config)
        permissionStatuses[type] = result.status
        
        return result
    }
    
    public func requestMultiple(_ types: [PermissionType]) async -> [PermissionResult] {
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        
        let results = await permissionManager.requestMultiple(types)
        
        for result in results {
            permissionStatuses[result.type] = result.status
        }
        
        return results
    }
    
    public func openSettings() {
        permissionManager.openSettings()
    }
    
    // MARK: - Computed Properties
    
    public func isAuthorized(_ type: PermissionType) -> Bool {
        return permissionStatuses[type]?.isAuthorized ?? false
    }
    
    public func canRequest(_ type: PermissionType) -> Bool {
        return permissionStatuses[type]?.canBeRequested ?? true
    }
    
    public func status(for type: PermissionType) -> PermissionStatus {
        return permissionStatuses[type] ?? .notDetermined
    }
}

// MARK: - Simple Permission Status View
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct PermissionStatusView: View {
    let permission: PermissionType
    
    @StateObject private var permissionManager = ObservablePermissionManager.shared
    
    public init(_ permission: PermissionType) {
        self.permission = permission
    }
    
    public var body: some View {
        HStack {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.description)
                    .font(.headline)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !permissionManager.isAuthorized(permission) {
                Button("Enable") {
                    Task {
                        await permissionManager.requestPermission(permission)
                    }
                }
                .buttonStyle(DefaultButtonStyle())
            }
        }
        .onAppear {
            Task {
                await permissionManager.checkStatus(for: permission)
            }
        }
    }
    
    private var statusIcon: String {
        switch permissionManager.status(for: permission) {
        case .authorized:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .restricted:
            return "exclamationmark.triangle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        case .provisional:
            return "checkmark.circle"
        }
    }
    
    private var statusColor: Color {
        switch permissionManager.status(for: permission) {
        case .authorized:
            return .green
        case .denied:
            return .red
        case .restricted:
            return .orange
        case .notDetermined:
            return .gray
        case .provisional:
            return .blue
        }
    }
    
    private var statusText: String {
        switch permissionManager.status(for: permission) {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        case .provisional:
            return "Provisional"
        }
    }
}

// MARK: - Basic Permissions Dashboard
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct PermissionsDashboardView: View {
    let permissions: [PermissionType]
    
    @StateObject private var permissionManager = ObservablePermissionManager.shared
    
    public init(permissions: [PermissionType]) {
        self.permissions = permissions
    }
    
    public var body: some View {
        NavigationView {
            List {
                ForEach(permissions, id: \.self) { permission in
                    PermissionStatusView(permission)
                }
                
                Section(footer: Text("Grant permissions to unlock all features of the app.")) {
                    Button("Request All Permissions") {
                        Task {
                            await permissionManager.requestMultiple(permissions)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(DefaultButtonStyle())
                }
            }
            .navigationTitle("Permissions")
        }
    }
}

