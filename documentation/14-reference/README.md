# Reference Documentation

## Overview

This section provides quick reference materials, API documentation, and code standards for Awful.app development.

## Contents

- [API Reference](./api-reference.md) - Complete API documentation
- [Code Standards](./code-standards.md) - Coding conventions and style guide
- [Architecture Patterns](./architecture-patterns.md) - Design pattern reference
- [File Organization](./file-organization.md) - Project structure guidelines
- [Naming Conventions](./naming-conventions.md) - Consistent naming practices
- [Dependencies](./dependencies.md) - Third-party library reference
- [Build Configuration](./build-configuration.md) - Build settings and schemes
- [Keyboard Shortcuts](./keyboard-shortcuts.md) - Development productivity shortcuts
- [Glossary](./glossary.md) - Terms and definitions

## Quick Reference

### Key Classes
- **ForumsClient**: Main API client
- **Theme**: Theming system
- **Settings**: User preferences
- **AwfulSplitViewController**: Main navigation
- **PostsPageViewController**: Thread viewing

### Important Files
- **Themes.plist**: Theme definitions
- **Settings.swift**: User preference registry
- **ForumsClient.swift**: Network layer
- **AppDelegate.swift**: App lifecycle
- **Local.xcconfig**: Local configuration

### Useful Extensions
- **UIView+AwfulTheme**: Theme application
- **String+AwfulHTML**: HTML utilities
- **UIViewController+AwfulTheme**: Controller theming
- **UserDefaults+AwfulSettings**: Settings access

## Development Standards

### Swift Style Guide
- Follow Swift API Design Guidelines
- Use meaningful variable names
- Prefer value types when appropriate
- Use extensions for organization
- Document public APIs

### Architecture Guidelines
- Separate concerns clearly
- Use protocols for abstraction
- Minimize dependencies
- Prefer composition over inheritance
- Test public interfaces

### Git Practices
- Use descriptive commit messages
- Keep commits focused and atomic
- Use feature branches
- Review code before merging
- Tag releases appropriately

## Configuration Reference

### Build Schemes
- **Debug**: Development builds
- **Release**: App Store builds
- **Test**: Unit testing
- **Profile**: Performance testing

### Environment Variables
- **AWFUL_DEBUG_LOGGING**: Enable debug output
- **AWFUL_SKIP_LOGIN**: Bypass authentication
- **AWFUL_USE_FIXTURES**: Use test data

### User Defaults Keys
- See Settings.swift for complete list
- All keys use reverse domain notation
- Settings use type-safe wrappers

## Migration Reference

### SwiftUI Equivalents
- UIViewController → View
- UITableView → List
- UINavigationController → NavigationStack
- UISplitViewController → NavigationSplitView
- UITabBarController → TabView

### Modern iOS APIs
- Async/await for networking
- Swift Concurrency
- SwiftUI state management
- Observation framework
- NavigationStack

### Deprecated Patterns
- Manual layout code
- Delegation chains
- Completion handler callbacks
- String-based APIs
- Manual memory management

## Performance Benchmarks

### Target Metrics
- Launch time: < 2 seconds
- Scroll performance: 60 fps
- Memory usage: < 100MB typical
- Network efficiency: Minimal requests
- Battery usage: Background minimal

### Measurement Tools
- Instruments Time Profiler
- Instruments Allocations
- Instruments Network
- Xcode Memory Graph
- MetricKit framework

## Accessibility Standards

### VoiceOver Support
- All interactive elements labeled
- Proper reading order
- Custom actions where appropriate
- Hints for complex interactions

### Dynamic Type Support
- Scalable fonts throughout
- Layout adapts to text size
- Minimum touch targets maintained
- Content doesn't truncate

### Accessibility Guidelines
- WCAG 2.1 AA compliance
- iOS accessibility guidelines
- Test with real assistive technology
- Consider cognitive accessibility

## Security Guidelines

### Data Protection
- Use Keychain for sensitive data
- Encrypt local databases
- Validate all inputs
- Use HTTPS exclusively

### Authentication
- Secure session management
- Proper logout procedures
- Session timeout handling
- Biometric authentication support

### Privacy
- Minimal data collection
- No third-party tracking
- Clear privacy policy
- User control over data

## Testing Standards

### Unit Testing
- Test public interfaces
- Mock external dependencies
- Use descriptive test names
- Aim for high coverage

### Integration Testing
- Test component interactions
- Use realistic test data
- Test error conditions
- Verify performance

### UI Testing
- Test critical user flows
- Use accessibility identifiers
- Test on multiple devices
- Verify visual consistency

## Documentation Standards

### Code Documentation
- Use Swift DocC format
- Document public APIs
- Include usage examples
- Explain complex algorithms

### Architecture Documentation
- Keep diagrams current
- Document design decisions
- Explain trade-offs
- Include migration notes

### User Documentation
- Clear setup instructions
- Step-by-step guides
- Troubleshooting sections
- FAQ for common issues
