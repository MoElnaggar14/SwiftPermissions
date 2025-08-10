# SwiftPermissions Quick Start Guide

Get started with SwiftPermissions in under 5 minutes!

## 1. Installation

Add SwiftPermissions to your Xcode project:

1. File → Add Package Dependencies...
2. Enter: `https://github.com/mohammedelnaggar/SwiftPermissions`
3. Choose version `1.0.0` or later

## 2. Import the Package

```swift
import SwiftPermissions
```

## 3. Request a Single Permission

```swift
let result = await PermissionManager.shared.request(.camera)
if result.isSuccess {
    // Camera permission granted!
    print("Camera access granted")
} else {
    // Permission denied
    print("Camera access denied: \(result.status)")
}
```

## 4. Request Multiple Permissions

```swift
let results = await PermissionManager.shared.requestMultiple([
    .camera,
    .microphone,
    .locationWhenInUse
])

for result in results {
    print("\(result.type): \(result.status)")
}
```

## 5. Use Permission Groups

```swift
// Request all media permissions at once
let mediaResults = await PermissionManager.shared.requestMultiple(.media)
// This requests: camera, microphone, photoLibrary
```

## 6. SwiftUI Integration

### Basic Status View
```swift
struct ContentView: View {
    var body: some View {
        List {
            PermissionStatusView(.camera)
            PermissionStatusView(.microphone)
            PermissionStatusView(.locationWhenInUse)
        }
    }
}
```

### Full Dashboard
```swift
struct PermissionsView: View {
    var body: some View {
        PermissionsDashboardView(permissions: [
            .camera,
            .microphone,
            .photoLibrary,
            .locationWhenInUse,
            .notification
        ])
    }
}
```

### Observable Permission Manager
```swift
struct CameraView: View {
    @StateObject private var permissions = ObservablePermissionManager.shared
    
    var body: some View {
        VStack {
            if permissions.isAuthorized(.camera) {
                Text("Camera Ready!")
                    .foregroundColor(.green)
            } else {
                Button("Enable Camera") {
                    Task {
                        await permissions.requestPermission(.camera)
                    }
                }
            }
        }
        .task {
            await permissions.checkStatus(for: .camera)
        }
    }
}
```

## 7. Add Info.plist Descriptions

Don't forget to add usage descriptions to your `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to take photos.</string>

<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to record audio.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access for location-based features.</string>
```

## 8. Testing

Use the mock manager for testing:

```swift
func testCameraPermission() async {
    let mockManager = PermissionManagerFactory.mock()
    
    if let mock = mockManager as? MockPermissionManager {
        mock.setShouldGrantPermissions(true)
    }
    
    let result = await mockManager.request(.camera)
    XCTAssertTrue(result.isSuccess)
}
```

## Available Permission Groups

- `.media` - Camera, microphone, photo library
- `.location` - Location when in use, notifications
- `.social` - Contacts, photo library, camera, notifications
- `.fitness` - Motion, health, location, notifications
- `.all` - All available permissions

That's it! You're ready to use SwiftPermissions in your app. 🎉

For more advanced usage, check out the full [README](README.md) and [API documentation](Documentation/).
