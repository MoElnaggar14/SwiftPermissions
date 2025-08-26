# Release Notes

## Version 2.0.0 - Clean Architecture Release 🏗️

**Release Date:** August 26, 2025

### 🚨 Breaking Changes

This is a major version release with intentional breaking changes to eliminate architecture anti-patterns and improve code quality.

#### Removed Features
- ❌ **Singleton Pattern**: Completely removed `PermissionManager.shared`
- ❌ **Static Convenience API**: Removed `Permissions.requestCamera()`, `Permissions.requestLocation()`, etc.
- ❌ **Backward Compatibility**: No compatibility layers with v1.x

#### Why These Breaking Changes?

We removed these patterns to address architecture anti-patterns identified in [architecture-antipatterns.tech](https://architecture-antipatterns.tech/):

1. **Singleton Anti-pattern**: Caused tight coupling, hidden dependencies, and testing difficulties
2. **Global State**: Led to unpredictable behavior and thread safety issues
3. **Poor Testability**: Made unit testing complex and unreliable

### ✅ New Features

#### Dependency Injection Architecture
- ✅ **Protocol-based design**: Easy to mock and test
- ✅ **Factory pattern**: `PermissionManagerFactory` for creating instances
- ✅ **Clean dependencies**: Explicit dependency injection
- ✅ **Multiple instances**: Create different managers for different contexts

#### Enhanced Testing
- ✅ **Mockable by default**: All managers implement `PermissionManagerProtocol`
- ✅ **Test helpers**: `PermissionManagerFactory.mock()` with configurable behavior
- ✅ **No global state**: Each test can use isolated instances

#### Improved SwiftUI Integration
- ✅ **Flexible initialization**: SwiftUI views accept custom permission managers
- ✅ **Better composition**: Components can be reused with different managers
- ✅ **Dependency injection**: Full support for DI in SwiftUI apps

### 📋 Migration Required

**All users must migrate their code.** See [MIGRATION.md](MIGRATION.md) for detailed instructions.

#### Quick Migration Examples

**Before (v1.x):**
```swift
let result = await PermissionManager.shared.request(.camera)
let status = await Permissions.requestCamera()
```

**After (v2.0):**
```swift
let permissionManager = PermissionManagerFactory.default()
let result = await permissionManager.request(.camera)
let status = await permissionManager.requestCamera()
```

**Dependency Injection (Recommended):**
```swift
class MyService {
    private let permissionManager: PermissionManagerProtocol
    
    init(permissionManager: PermissionManagerProtocol = PermissionManagerFactory.default()) {
        self.permissionManager = permissionManager
    }
}
```

### 🎯 Benefits of Upgrading

1. **Better Testing**: Easy to mock and unit test
2. **Cleaner Code**: Explicit dependencies, no hidden global state
3. **Thread Safety**: No shared mutable state
4. **Flexibility**: Multiple instances, custom configurations
5. **Future-proof**: Follows modern Swift architecture patterns

### 🔧 Technical Improvements

- **Performance**: Reduced memory footprint by eliminating global state
- **Concurrency**: Better async/await support without singleton bottlenecks
- **Modularity**: Each component can have its own permission manager
- **Debugging**: Clearer call stacks without global state mutations

### 📱 Platform Support

- iOS 15.0+
- macOS 12.0+
- tvOS 15.0+
- watchOS 8.0+
- Swift 5.7+

### 📚 Documentation

- Updated [README.md](README.md) with new usage patterns
- Comprehensive [MIGRATION.md](MIGRATION.md) guide
- All examples updated to show dependency injection patterns
- Enhanced inline documentation

### 🧪 Testing

- All tests pass with new architecture
- Enhanced test coverage for factory patterns
- Mock implementations improved
- Performance tests validate improvements

---

## Previous Versions

### Version 1.x (Legacy)

Previous versions used singleton patterns which have been completely removed in v2.0.0. Users on v1.x should migrate to v2.0.0 to benefit from improved architecture and testing capabilities.

---

## Support

If you encounter any issues during migration:

1. Review the [MIGRATION.md](MIGRATION.md) guide
2. Check updated examples in [README.md](README.md)
3. Open an issue on [GitHub](https://github.com/MoElnaggar14/SwiftPermissions/issues)
4. Email: [moelnaggar14@gmail.com](mailto:moelnaggar14@gmail.com)

Thank you for upgrading to SwiftPermissions 2.0.0! 🚀
