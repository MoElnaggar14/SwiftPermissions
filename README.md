# SwiftPermissions

A comprehensive Swift package for managing iOS permissions with a modern async/await API and SwiftUI integration.

[![Swift Version](https://img.shields.io/badge/Swift-5.7+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-brightgreen.svg)](https://developer.apple.com/swift/)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## 🌟 Features

- 🎯 **Comprehensive Permission Support**: Location, Notifications, Camera, Microphone, Photo Library, Contacts, Calendar, Reminders, Health, Motion, Biometrics, and App Tracking Transparency
- ⚡ **Modern API**: Built with async/await and Combine for reactive programming
- 🧩 **SwiftUI Integration**: Ready-to-use view modifiers and components
- 🔍 **Protocol-Based**: Easily mockable for testing
- 📱 **Multi-Platform**: iOS, macOS, tvOS, watchOS support
- 🧪 **Fully Tested**: Comprehensive unit test coverage
- 🎨 **Customizable UI**: Beautiful permission request views and dashboards

## 📦 Installation

### Swift Package Manager

Add SwiftPermissions to your project through Xcode:

1. File → Add Package Dependencies...
2. Enter the repository URL: `https://github.com/MoElnaggar14/SwiftPermissions`
3. Choose your version preference

Or add it to your `Package.swift`:

```swift
dependencies: [
.package(url: "https://github.com/MoElnaggar14/SwiftPermissions", from: "1.0.0")
]
```

## 🚀 Quick Start

## Usage

### Basic Usage

```swift
import SwiftPermissions

// Check permission status
let status = await PermissionManager.shared.status(for: .camera)

// Request a permission
let result = await PermissionManager.shared.request(.camera)
if result.isSuccess {
    // Permission granted
} else {
    // Permission denied or error occurred
}

// Request multiple permissions
let results = await PermissionManager.shared.requestMultiple([.camera, .microphone, .photoLibrary])
```

### Convenience Methods

```swift
// Quick access to common permissions
let cameraResult = await Permissions.requestCamera()
let locationResult = await Permissions.requestLocation()
let notificationResult = await Permissions.requestNotifications()
```

### Permission Groups

```swift
// Request permissions by category
let mediaResults = await PermissionManager.shared.requestMultiple(.media) // Camera, microphone, photo library
let locationResults = await PermissionManager.shared.requestMultiple(.location) // Location when in use, notifications
let socialResults = await PermissionManager.shared.requestMultiple(.social) // Contacts, photo library, camera, notifications
```

### SwiftUI Integration

#### Using View Modifiers

```swift
import SwiftUI
import SwiftPermissions

struct ContentView: View {
    @State private var showPermissionAlert = false
    
    var body: some View {
        VStack {
            Text("My App")
            
            Button("Request Camera Permission") {
                showPermissionAlert = true
            }
        }
        .requestPermissionsOnAppear([.notification]) { results in
            // Handle results
        }
        .permissionAlert(
            for: .camera,
            isPresented: $showPermissionAlert,
            config: PermissionConfig(
                title: "Camera Access Required",
                message: "We need camera access to take photos."
            )
        )
        .conditionalOnPermission(.camera) {
            // Show when camera is authorized
            CameraView()
        } notAuthorized: {
            // Show when camera is not authorized
            PermissionDeniedView()
        }
    }
}
```

#### Using Observable Permission Manager

```swift
struct PermissionView: View {
    @StateObject private var permissionManager = ObservablePermissionManager.shared
    
    var body: some View {
        VStack {
            if permissionManager.isAuthorized(.camera) {
                Text("Camera is authorized")
                    .foregroundColor(.green)
            } else {
                Button("Request Camera Permission") {
                    Task {
                        await permissionManager.requestPermission(.camera)
                    }
                }
            }
        }
        .task {
            await permissionManager.checkStatus(for: .camera)
        }
    }
}
```

#### Permission Status Views

```swift
struct SettingsView: View {
    var body: some View {
        List {
            PermissionStatusView(.camera)
            PermissionStatusView(.microphone)
            PermissionStatusView(.photoLibrary)
        }
    }
}
```

#### Permissions Dashboard

```swift
struct PermissionsView: View {
    var body: some View {
        PermissionsDashboardView(permissions: [.camera, .microphone, .photoLibrary, .location])
    }
}
```

### Custom Configuration

```swift
let config = PermissionConfig(
    title: "Location Permission Required",
    message: "This app uses location to provide personalized recommendations.",
    settingsTitle: "Enable Location in Settings",
    settingsMessage: "Go to Settings > Privacy > Location Services to enable location for this app."
)

let result = await PermissionManager.shared.request(.location, config: config)
```

### Reactive Programming with Combine

```swift
import Combine

class ViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        PermissionManager.shared.permissionStatusChanged
            .sink { (type, status) in
                print("Permission \(type) changed to \(status)")
            }
            .store(in: &cancellables)
    }
}
```

## Permission Types

The package supports the following permission types:

| Permission Type | Description |
|----------------|-------------|
| `.location` | General location access |
| `.locationWhenInUse` | Location when app is in use |
| `.locationAlways` | Always-on location access |
| `.notification` | Push notifications |
| `.camera` | Camera access |
| `.microphone` | Microphone access |
| `.photoLibrary` | Photo library access |
| `.contacts` | Contacts access |
| `.calendar` | Calendar access |
| `.reminders` | Reminders access |
| `.health` | HealthKit data access |
| `.motion` | Motion and fitness data |
| `.faceID` | Face ID authentication |
| `.touchID` | Touch ID authentication |
| `.tracking` | App tracking transparency |

## Permission Status

Each permission can have one of the following statuses:

- `.notDetermined` - Permission hasn't been requested yet
- `.authorized` - Permission is granted
- `.denied` - Permission is denied
- `.restricted` - Permission is restricted (parental controls, etc.)
- `.provisional` - Provisional permission (notifications only)

## Testing

The package includes a mock implementation for testing:

```swift
import SwiftPermissions

class MyTestCase: XCTestCase {
    func testPermissions() async {
        let mockManager = PermissionManagerFactory.mock()
        
        // Configure mock behavior
        if let mock = mockManager as? MockPermissionManager {
            mock.setShouldGrantPermissions(true)
            mock.setMockStatus(.authorized, for: .camera)
        }
        
        let result = await mockManager.request(.camera)
        XCTAssertTrue(result.isSuccess)
    }
}
```

## Info.plist Requirements

Make sure to add the required usage descriptions to your app's `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs access to camera to take photos.</string>

<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to microphone to record audio.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to photo library to save and select photos.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to provide location-based features.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access to provide location-based features.</string>

<key>NSContactsUsageDescription</key>
<string>This app needs access to contacts to help you connect with friends.</string>

<key>NSCalendarsUsageDescription</key>
<string>This app needs access to calendar to schedule events.</string>

<key>NSRemindersUsageDescription</key>
<string>This app needs access to reminders to create tasks.</string>

<key>NSMotionUsageDescription</key>
<string>This app needs access to motion data to track your activity.</string>

<key>NSFaceIDUsageDescription</key>
<string>This app uses Face ID for secure authentication.</string>

<key>NSUserTrackingUsageDescription</key>
<string>This app would like to track you across apps and websites to provide personalized ads.</string>
```

## Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 5.7+
- Xcode 14.0+

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for more details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Support

- 📧 Email: [moelnaggar14@gmail.com](mailto:moelnaggar14@gmail.com)
- 💬 Discussions: [GitHub Discussions](https://github.com/MoElnaggar14/SwiftPermissions/discussions)
- 🐛 Issues: [GitHub Issues](https://github.com/MoElnaggar14/SwiftPermissions/issues)

## License

This package is available under the MIT license. See the LICENSE file for more info.
