# 🚀 SwiftPermissions v2.0.0 - Clean Architecture Release

We're excited to announce **SwiftPermissions v2.0.0**, a major release that completely removes architecture anti-patterns and introduces clean dependency injection!

## 🎯 What's New

### ❌ Breaking Changes (Intentional)
- **Removed singleton pattern** (`PermissionManager.shared` is gone!)
- **Removed static convenience API** (no more `Permissions.requestCamera()`)
- **No backward compatibility** - clean slate for better architecture

### ✅ New Clean Architecture
- **Dependency Injection**: Protocol-based design with `PermissionManagerFactory`
- **Better Testing**: Easy to mock with `MockPermissionManager`
- **Thread Safety**: No global state, no race conditions
- **Multiple Instances**: Create different managers for different contexts

## 💡 Why This Breaking Change?

We studied [architecture-antipatterns.tech](https://architecture-antipatterns.tech/) and identified that singletons cause:
- 🔗 **Tight coupling** between components
- 🕵️ **Hidden dependencies** that are hard to track
- 🧪 **Testing difficulties** with global state
- 🧵 **Thread safety issues** with shared mutable state

## 📋 Migration Example

### Before (v1.x):
```swift
let result = await PermissionManager.shared.request(.camera)
```

### After (v2.0):
```swift
class MyViewController {
    private let permissionManager: PermissionManagerProtocol
    
    init(permissionManager: PermissionManagerProtocol = PermissionManagerFactory.default()) {
        self.permissionManager = permissionManager
    }
    
    func requestCamera() async {
        let result = await permissionManager.request(.camera)
    }
}
```

## 🧪 Enhanced Testing

### Before (v1.x):
```swift
// Difficult to test with singleton
func testCameraRequest() async {
    // Hard to mock PermissionManager.shared
}
```

### After (v2.0):
```swift
func testCameraRequest() async {
    let mockManager = PermissionManagerFactory.mock(shouldGrantPermissions: true)
    let viewController = MyViewController(permissionManager: mockManager)
    
    let result = await viewController.requestCamera()
    XCTAssertTrue(result.isSuccess)
}
```

## 🎉 Benefits You Get

1. **🧪 Better Tests**: Mock everything easily
2. **🧹 Cleaner Code**: Explicit dependencies, no hidden globals
3. **🔒 Thread Safety**: No shared mutable state
4. **⚡ Performance**: Reduced memory footprint
5. **🔮 Future-proof**: Follows modern Swift patterns

## 📚 Resources

- **[README.md](README.md)**: Updated with new patterns
- **[MIGRATION.md](MIGRATION.md)**: Step-by-step upgrade guide  
- **[RELEASE_NOTES.md](RELEASE_NOTES.md)**: Complete changelog
- **GitHub**: [MoElnaggar14/SwiftPermissions](https://github.com/MoElnaggar14/SwiftPermissions)

## 🛠️ Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/MoElnaggar14/SwiftPermissions", from: "2.0.0")
]
```

## 📱 Platform Support

- iOS 15.0+
- macOS 12.0+  
- tvOS 15.0+
- watchOS 8.0+
- Swift 5.7+

---

**Ready to upgrade?** Check out our [migration guide](MIGRATION.md) for step-by-step instructions!

**Questions?** Open an issue on [GitHub](https://github.com/MoElnaggar14/SwiftPermissions/issues) or email [moelnaggar14@gmail.com](mailto:moelnaggar14@gmail.com)

Thank you for supporting clean architecture! 🏗️✨
