# Migration Guide: Removing Singleton Pattern

This guide helps you migrate from the singleton-based approach to the new dependency injection approach in SwiftPermissions.

## Overview

We've removed the singleton pattern to follow clean architecture principles and improve testability. This is a **breaking change** but provides significant benefits:

- ✅ Better testability
- ✅ No global state
- ✅ Clearer dependencies
- ✅ Thread safety
- ✅ Multiple instances when needed

## What Changed

### Before (Singleton Pattern)
```swift
// Old way - using singleton
let status = await PermissionManager.shared.status(for: .camera)
let result = await PermissionManager.shared.request(.camera)
```

### After (Dependency Injection)
```swift
// Recommended new way - dependency injection
class MyViewController {
    private let permissionManager: PermissionManagerProtocol
    
    init(permissionManager: PermissionManagerProtocol = PermissionManagerFactory.default()) {
        self.permissionManager = permissionManager
    }
    
    func checkPermissions() async {
        let status = await permissionManager.status(for: .camera)
        let result = await permissionManager.request(.camera)
    }
}
```

### Alternative (Static Convenience API)
```swift
// For simple use cases - static convenience API
let cameraResult = await Permissions.requestCamera()
let locationResult = await Permissions.requestLocation()
```

## Migration Steps

### 1. Update Direct Usage

**Before:**
```swift
let permissionManager = PermissionManager.shared
let result = await permissionManager.request(.camera)
```

**After:**
```swift
let permissionManager = PermissionManagerFactory.default()
let result = await permissionManager.request(.camera)
```

### 2. Update Dependency Injection

**Before:**
```swift
class MyService {
    private let permissionManager = PermissionManager.shared
}
```

**After:**
```swift
class MyService {
    private let permissionManager: PermissionManagerProtocol
    
    init(permissionManager: PermissionManagerProtocol = PermissionManagerFactory.default()) {
        self.permissionManager = permissionManager
    }
}
```

### 3. Update SwiftUI Usage

**Before:**
```swift
@StateObject private var permissionManager = ObservablePermissionManager.shared
```

**After:**
```swift
@StateObject private var permissionManager = ObservablePermissionManager()
```

### 4. Update Testing

**Before:**
```swift
// This was difficult with singleton
func testPermissions() async {
    // Hard to mock PermissionManager.shared
}
```

**After:**
```swift
func testPermissions() async {
    let mockManager = PermissionManagerFactory.mock(shouldGrantPermissions: true)
    let service = MyService(permissionManager: mockManager)
    
    let result = await service.requestCameraAccess()
    XCTAssertTrue(result.isSuccess)
}
```

## Factory Pattern

Use the factory to create instances:

```swift
// Standard production instance
let manager = PermissionManagerFactory.default()

// Another standard instance (if you need multiple)
let anotherManager = PermissionManagerFactory.standard()

// Mock for testing
let mockManager = PermissionManagerFactory.mock()

// Mock with specific behavior
let denyingMock = PermissionManagerFactory.mock(shouldGrantPermissions: false)
```

## SwiftUI Changes

### Permission Status Views

**Before:**
```swift
PermissionStatusView(.camera) // Used shared singleton internally
```

**After:**
```swift
// Uses default instance internally - no change needed
PermissionStatusView(.camera)

// Or inject custom manager
let customManager = ObservablePermissionManager()
PermissionStatusView(.camera, permissionManager: customManager)
```

### Permissions Dashboard

**Before:**
```swift
PermissionsDashboardView(permissions: [.camera, .microphone])
```

**After:**
```swift
// Uses default instance internally - no change needed
PermissionsDashboardView(permissions: [.camera, .microphone])

// Or inject custom manager
let customManager = ObservablePermissionManager()
PermissionsDashboardView(permissions: [.camera, .microphone], permissionManager: customManager)
```

## Benefits of Migration

1. **Testability**: Easy to inject mock managers for unit tests
2. **Flexibility**: Create multiple instances for different contexts
3. **Thread Safety**: No shared mutable global state
4. **Clean Architecture**: Clear dependencies, easier to reason about
5. **No Singleton Anti-patterns**: Avoids tight coupling and hidden dependencies

## Backwards Compatibility

For simple usage, you can still use static convenience methods:

```swift
// These still work and are convenient for simple cases
let cameraResult = await Permissions.requestCamera()
let locationResult = await Permissions.requestLocation()
let notificationResult = await Permissions.requestNotifications()
```

## Need Help?

If you encounter any issues during migration:

1. Check the [README](README.md) for updated examples
2. Review the test files for usage patterns
3. Open an issue on GitHub for specific questions

The migration to dependency injection makes your code more testable and maintainable while following modern Swift architecture patterns.
