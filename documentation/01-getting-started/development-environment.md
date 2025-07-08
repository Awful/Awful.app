# Development Environment

## Overview

This document outlines the development environment setup and tools used for Awful.app development.

## Required Tools

### Xcode Configuration

#### Minimum Requirements
- **Xcode**: 16.0 or later
- **macOS**: 14.0 (Sonoma) or later
- **iOS SDK**: 15.0+ (transitioning to 16.1+)

#### Recommended Settings

1. **Text Editing**
   - Line numbers: On
   - Page guide at column: 120
   - Trim trailing whitespace: Yes
   - Include whitespace-only lines: No

2. **Swift Settings**
   - Use inferred types: Where appropriate
   - Prefer Self in static references: Yes
   - Format on paste: Yes

3. **Build Settings**
   - Parallelize Build: Yes
   - Build Active Architecture Only (Debug): Yes

### Command Line Tools

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Verify installation
xcode-select -p
# Should output: /Applications/Xcode.app/Contents/Developer
```

## Development Dependencies

### Swift Package Manager

The project uses SPM for dependency management. Dependencies are defined in the project file and include:

```swift
// Main dependencies
.package(url: "https://github.com/kean/Nuke.git", from: "12.0.0"),
.package(url: "https://github.com/nolanw/HTMLReader.git", from: "2.1.8"),
.package(url: "https://github.com/stencilproject/Stencil.git", from: "0.15.0"),
.package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.3.0"),
.package(url: "https://github.com/Flipboard/FLAnimatedImage.git", from: "1.0.17")
```

### Local Packages

The project includes several local Swift packages:
- **AwfulCore**: Networking and data layer
- **AwfulExtensions**: Shared extensions
- **AwfulTheming**: Theme system
- **AwfulSettings**: Settings management
- **Smilies**: Smilie keyboard functionality

## Debugging Tools

### Network Debugging

#### Debugging HTML Scraping
```swift
// Enable debug logging in ForumsClient
UserDefaults.standard.set(true, forKey: "AwfulDebugLogEnabled")
```

### Core Data Debugging

Add these launch arguments in Xcode:
```
-com.apple.CoreData.SQLDebug 1
-com.apple.CoreData.Logging.stderr 1
```

### Memory Debugging

1. Use Instruments with the Leaks template
2. Enable Malloc Stack logging
3. Monitor memory graph in Xcode

## Code Quality Tools

### SwiftLint (Recommended)

```bash
# Install via Homebrew
brew install swiftlint

# Create .swiftlint.yml
cat > .swiftlint.yml << EOF
disabled_rules:
  - line_length
  - file_length
  - type_body_length
  - function_body_length
  
opt_in_rules:
  - empty_count
  - closure_spacing
  - contains_over_filter_count
  - first_where
  
excluded:
  - Vendor
  - AwfulCore/Tests/Fixtures
  
line_length:
  warning: 120
  error: 200
EOF
```

### Instruments Templates

Useful Instruments templates for profiling:

1. **Time Profiler**: Identify performance bottlenecks
2. **Allocations**: Track memory usage
3. **Network**: Monitor API calls
4. **Core Data**: Analyze database queries
5. **System Trace**: Overall app performance

## Version Control

### Git Configuration

```bash
# Configure Git
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Useful aliases
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.st status
git config --global alias.last 'log -1 HEAD'
```

## Testing Environment

### Simulator Configuration

1. **Recommended Simulators**
   - iPhone 16 Pro (primary)
   - iPhone SE (small screen)
   - iPad Pro 11" (tablet)

2. **Testing Scenarios**
   - Light/Dark mode
   - Dynamic Type sizes
   - Different settings/preferences
   - Different forum themes
   - Logged in/out states

### Test Data

The project includes test fixtures in `AwfulCore/Tests/Fixtures/` for offline development:
- Forum listings
- Thread pages
- User profiles
- Private messages

## Environment Variables

### Debug Flags

```swift
// In your scheme's environment variables
AWFUL_DEBUG_LOGGING = 1
AWFUL_SKIP_LOGIN = 1  // For UI development
AWFUL_USE_FIXTURES = 1  // Use test data
```

## IDE Extensions

### Recommended Xcode Extensions

1. **SwiftFormat**: Code formatting
2. **Xcodes**: Manage multiple Xcode versions
3. **SimSim**: Quick simulator app access

## Performance Monitoring

### Build Time Optimization

```bash
# Add to Other Swift Flags in build settings
-Xfrontend -warn-long-function-bodies=100
-Xfrontend -warn-long-expression-type-checking=100
```

### Runtime Performance

1. Enable thread performance checker
2. Use main thread checker
3. Monitor hang reports in Xcode Organizer

## Troubleshooting Development Issues

### Common Problems

1. **Slow incremental builds**
   - Clean derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`
   - Reset package caches

2. **Debugger not attaching**
   - Kill simulator and restart
   - Clean build folder: ⇧⌘K

3. **SwiftUI previews not working**
   - Currently limited due to UIKit architecture
   - Will improve with migration

## Migration Considerations

As we move to SwiftUI and iOS 16.1+:

1. **Use Swift Concurrency**
   - Replace completion handlers with async/await
   - Update networking layer

2. **Adopt Modern APIs**
   - NavigationStack instead of UINavigationController
   - SwiftUI environment values
   - Observation framework

3. **Maintain Compatibility**
   - Test on iOS 15 during transition
   - Document any breaking changes
   - Preserve Core Data schema
