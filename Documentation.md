# SwiftPermissions - Advanced Usage Guide

## Architecture

SwiftPermissions is built as a modular umbrella framework with three main components:

### 🏗️ **Modular Architecture**

```swift
SwiftPermissions (Umbrella)
├── SwiftPermissionsCore    // Core permission logic, no UI dependencies
└── SwiftPermissionsUI      // SwiftUI components and view modifiers
```

This design allows developers to:
- Import only what they need (`SwiftPermissionsCore` for logic-only usage)
- Use `SwiftPermissions` for everything (recommended for most cases)
- Extend and customize individual modules

## Installation Options

### 1. **Complete Framework (Recommended)**
```swift
import SwiftPermissions

// Access to all functionality
```

### 2. **Core Only (for backend/logic-only usage)**
```swift
import SwiftPermissionsCore

// No SwiftUI dependencies
```

### 3. **UI Components Only**
```swift
import SwiftPermissionsCore
import SwiftPermissionsUI

// Manual control over imports
```

## Advanced Usage Patterns

### 1. **Permission Groups**
Use predefined permission groups for common scenarios:

```swift
import SwiftPermissions

// Request all media permissions at once
let mediaResults = await PermissionManager.shared.requestMediaPermissions()

// Check if essential permissions are granted
let hasEssentials = await PermissionManager.shared.areAllAuthorized(.essential)

// Request permissions by use case
let socialResults = await PermissionManager.shared.requestSocialPermissions()
let productivityResults = await PermissionManager.shared.requestProductivityPermissions()
```

### 2. **Result Analysis**
Analyze permission request results with convenience extensions:

```swift
let results = await PermissionManager.shared.requestMultiple(.media)

print(results.summary) // "2/3 permissions authorized"

if results.allSucceeded {
    // All permissions granted
} else {
    // Handle partial or complete failure
    let failed = results.failed
    let successful = results.successful
    
    // Group by status for detailed handling
    let grouped = results.groupedByStatus
    let denied = grouped[.denied] ?? []
    let authorized = grouped[.authorized] ?? []
}
```

### 3. **Reactive Permission Monitoring**
Use Combine publishers to react to permission changes:

```swift
import SwiftPermissions
import Combine

class PermissionMonitor: ObservableObject {
    @Published var cameraStatus: PermissionStatus = .notDetermined
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        PermissionManager.shared.permissionStatusChanged
            .filter { $0.0 == .camera }
            .map { $0.1 }
            .assign(to: \.cameraStatus, on: self)
            .store(in: &cancellables)
    }
}
```

### 4. **Custom Permission Flows**
Create sophisticated permission request flows:

```swift
class OnboardingFlow {
    private let permissionManager = PermissionManager.shared
    
    func runOnboarding() async {
        // Step 1: Essential permissions
        let essentialResults = await permissionManager.requestEssentialPermissions()
        guard essentialResults.allSucceeded else {
            // Handle essential permissions failure
            return
        }
        
        // Step 2: Optional permissions based on features
        if await shouldRequestLocationFeatures() {
            _ = await permissionManager.requestLocationPermissions()
        }
        
        // Step 3: Advanced features
        if await userWantsHealthFeatures() {
            _ = await permissionManager.requestHealthAndFitnessPermissions()
        }
    }
}
```

### 5. **SwiftUI Integration Patterns**

#### Permission-Gated Views
```swift
struct FeatureView: View {
    var body: some View {
        VStack {
            Text("Camera Feature")
        }
        .conditionalOnPermission(.camera) {
            CameraView()
        } notAuthorized: {
            PermissionRequestView(.camera)
        }
    }
}
```

#### Permission Status Dashboard
```swift
struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section("Media Permissions") {
                    PermissionStatusView(.camera)
                    PermissionStatusView(.microphone)
                    PermissionStatusView(.photoLibrary)
                }
                
                Section("Location") {
                    PermissionStatusView(.locationWhenInUse)
                    PermissionStatusView(.notification)
                }
            }
            .navigationTitle("Privacy Settings")
        }
    }
}
```

#### Batch Permission Requests
```swift
struct OnboardingPermissionsView: View {
    @StateObject private var permissionManager = ObservablePermissionManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Let's set up your permissions")
                .font(.largeTitle)
            
            PermissionsDashboardView(permissions: .essential)
            
            Button("Request All Permissions") {
                Task {
                    await permissionManager.requestMultiple(.essential)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

## Best Practices

### 1. **Permission Request Timing**
- Request permissions when the user needs to use the feature
- Don't request all permissions at app launch
- Provide context about why each permission is needed

### 2. **Graceful Degradation**
```swift
func handleCameraPermission() async {
    let result = await PermissionManager.shared.request(.camera)
    
    switch result.status {
    case .authorized:
        // Full camera functionality
        break
    case .denied:
        // Offer alternative or redirect to settings
        break
    case .restricted:
        // Inform user about parental controls
        break
    case .notDetermined:
        // This shouldn't happen after a request, but handle gracefully
        break
    case .provisional:
        // Limited functionality if applicable
        break
    }
}
```

### 3. **Testing with Mocks**
```swift
class MyFeatureTests: XCTestCase {
    func testWithMockPermissions() async {
        let mockManager = PermissionManagerFactory.mock()
        
        // Configure mock behavior
        if let mock = mockManager as? MockPermissionManager {
            mock.setShouldGrantPermissions(false)
            mock.setMockStatus(.denied, for: .camera)
        }
        
        let myFeature = MyFeature(permissionManager: mockManager)
        let result = await myFeature.requestCameraAccess()
        
        XCTAssertFalse(result.isSuccess)
    }
}
```

## Performance Considerations

1. **Lazy Loading**: Permission checks are performed on-demand
2. **Caching**: Status is cached and updated through the publisher system
3. **Platform Optimization**: Conditional compilation ensures only relevant code runs
4. **Memory Efficiency**: Minimal singleton pattern with weak references

## Platform-Specific Notes

### iOS
- All permission types are fully supported
- Biometric permissions require device capability
- Health permissions need specific HealthKit setup

### macOS
- Motion permissions are not available
- Some permissions work differently (e.g., camera/microphone)
- App Sandbox considerations

### tvOS & watchOS
- Limited permission set
- UI components adapt to platform capabilities
- Some permissions may not be applicable

## Migration Guide

If upgrading from a single-module version:

```swift
// Old way
import SwiftPermissions

// New way (same import, enhanced functionality)
import SwiftPermissions

// Or use specific modules for better control
import SwiftPermissionsCore  // For logic only
import SwiftPermissionsUI    // For UI components
```

The umbrella framework maintains full backward compatibility while providing new modular options.
