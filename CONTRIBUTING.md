# Contributing to SwiftPermissions

Thank you for your interest in contributing to SwiftPermissions! This document provides guidelines and information for contributors.

## 🎯 How to Contribute

### Reporting Issues
- Use the [GitHub Issues](https://github.com/yourusername/SwiftPermissions/issues) page
- Search existing issues to avoid duplicates
- Provide detailed information including:
  - iOS/macOS version
  - Xcode version
  - Swift version
  - Steps to reproduce
  - Expected vs actual behavior

### Suggesting Features
- Open a [GitHub Discussion](https://github.com/yourusername/SwiftPermissions/discussions)
- Describe the use case and proposed solution
- Consider backward compatibility

### Code Contributions

#### Before You Start
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make sure all tests pass: `swift test`

#### Code Style
- Follow Swift conventions and best practices
- Use meaningful variable and function names
- Add documentation comments for public APIs
- Keep functions focused and concise

#### Testing
- Write unit tests for new functionality
- Ensure all existing tests pass
- Test on multiple iOS versions when possible
- Update mock implementations as needed

#### Documentation
- Update README.md if adding new features
- Add inline documentation for public APIs
- Include usage examples

#### Pull Request Process
1. Create a clear PR title and description
2. Reference any related issues
3. Ensure CI passes
4. Request review from maintainers

## 🏗️ Development Setup

### Prerequisites
- Xcode 14.0+
- Swift 5.7+
- iOS 14.0+ simulator

### Building
```bash
git clone https://github.com/yourusername/SwiftPermissions
cd SwiftPermissions
swift build
```

### Testing
```bash
swift test
```

### Example App
The package includes example usage in the test files. You can also create a new iOS app and add the package locally for testing.

## 📋 Code Guidelines

### Architecture
- Maintain protocol-based design for testability
- Keep platform-specific code isolated
- Use async/await for new APIs
- Maintain Combine support for reactive programming

### Error Handling
- Use Result types where appropriate
- Provide meaningful error messages
- Handle edge cases gracefully

### Performance
- Minimize permission requests
- Cache permission status when appropriate
- Avoid blocking the main thread

## 🚀 Release Process

Releases are managed by maintainers following semantic versioning:
- **Major**: Breaking changes
- **Minor**: New features, backward compatible
- **Patch**: Bug fixes

## 🤝 Community Guidelines

- Be respectful and inclusive
- Provide constructive feedback
- Help newcomers learn
- Follow the [Swift Code of Conduct](https://swift.org/code-of-conduct/)

## 📝 License

By contributing to SwiftPermissions, you agree that your contributions will be licensed under the MIT License.

## 🆘 Getting Help

- [GitHub Discussions](https://github.com/yourusername/SwiftPermissions/discussions) for questions
- [GitHub Issues](https://github.com/yourusername/SwiftPermissions/issues) for bugs
- Email: [your-email@example.com](mailto:your-email@example.com)

Thank you for contributing to SwiftPermissions! 🙏
