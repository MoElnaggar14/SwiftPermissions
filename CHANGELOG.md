# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of SwiftPermissions
- Comprehensive permission support for 15+ permission types
- Modern async/await API
- SwiftUI integration with view modifiers and components
- Protocol-based design for easy testing
- Multi-platform support (iOS, macOS, tvOS, watchOS)
- Reactive programming with Combine
- Observable permission manager for SwiftUI
- Permission dashboards and status views
- Comprehensive unit test coverage
- Mock implementation for testing

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
