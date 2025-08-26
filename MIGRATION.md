# Migration Guide: v2.0.0 - Complete Singleton Removal

This guide helps you migrate from v1.x to v2.0.0 of SwiftPermissions, which completely removes the singleton pattern in favor of clean dependency injection.

## ⚠️ Breaking Changes

**Version 2.0.0 introduces breaking changes that require code updates.** We've completely removed:

- ❌ `PermissionManager.shared` singleton
- ❌ Static convenience API (`Permissions.requestCamera()`, etc.)
- ❌ All backward compatibility layers

This is a **major version bump** with significant architectural improvements:

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

### Alternative (Direct Factory Usage)
```swift
// For simple use cases - direct factory usage
let permissionManager = PermissionManagerFactory.default()
let cameraResult = await permissionManager.requestCamera()
let locationResult = await permissionManager.requestLocation()
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

## No Backwards Compatibility

**Version 2.0.0 breaks backward compatibility intentionally** to enforce clean architecture patterns. All singleton usage and static convenience APIs have been removed to provide:

- Clear dependency management
- Better testing capabilities
- Elimination of global state
- More explicit code architecture

## Need Help?

If you encounter any issues during migration:

1. Check the [README](README.md) for updated examples
2. Review the test files for usage patterns
3. Open an issue on GitHub for specific questions

The migration to dependency injection makes your code more testable and maintainable while following modern Swift architecture patterns.
