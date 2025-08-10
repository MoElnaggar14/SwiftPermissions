# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- TBD

### Changed
- TBD

### Fixed
- TBD

## [1.1.0] - 2024-08-11

### Added  
- Performance benchmarks for permission operations (4 new tests)
- Comprehensive Documentation.md with architecture guide
- Enhanced demo app with batch requests and visual feedback
- Thread-safe implementations throughout codebase
- Modular architecture: SwiftPermissionsCore + SwiftPermissionsUI + SwiftPermissions umbrella

### Changed
- **BREAKING CHANGE**: Restructured into modular components
- Enhanced test coverage (28 total tests, 100% passing)
- Optimized performance for high-frequency operations
- Improved CI/CD with macOS-compatible SwiftLint
- Updated platform requirements to iOS 15.0+, macOS 12.0+, tvOS 15.0+, watchOS 8.0+

### Fixed
- Thread safety issues in concurrent permission requests
- SwiftLint violations and code quality issues
- GitHub Actions compatibility with macOS runners
- Performance bottlenecks in batch operations

### Performance Metrics
- Status checks: ~0.3ms average
- Batch requests: ~31ms for 5 permissions  
- Permission groups: ~1ms for 1000 operations
- Factory methods: ~0.3ms

### Features
- Location services (when in use, always)
- Push notifications
- Camera and microphone access
- Photo library access
- Contacts and calendar access
- Health and motion data
- Biometric authentication (Face ID, Touch ID)
- App tracking transparency
- Custom permission configurations
- Permission grouping (media, location, social, fitness)

### SwiftUI Components
- `PermissionsDashboardView` - Complete permissions dashboard
- `PermissionStatusView` - Individual permission status display
- `ObservablePermissionManager` - Reactive permission management
- View modifiers for conditional content based on permissions
- Permission alert presentations
- Automatic permission requests on view appear

### Testing
- `MockPermissionManager` - Full mock implementation
- `PermissionManagerFactory` - Factory for production and test managers
- Comprehensive test suite covering all permission types
- Combine publisher testing

## [1.0.0] - 2024-12-10

### Added
- Initial public release
