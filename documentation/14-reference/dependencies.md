# Dependencies Reference

Comprehensive reference for all third-party libraries, frameworks, and dependencies used in the Awful.app project.

## Table of Contents

- [Swift Package Manager Dependencies](#swift-package-manager-dependencies)
- [Vendor Dependencies](#vendor-dependencies)
- [System Framework Dependencies](#system-framework-dependencies)
- [Development Dependencies](#development-dependencies)
- [Build Tool Dependencies](#build-tool-dependencies)
- [Dependency Management Guidelines](#dependency-management-guidelines)
- [Version Requirements](#version-requirements)
- [Security Considerations](#security-considerations)

## Swift Package Manager Dependencies

### Core Dependencies

#### HTMLReader
**Purpose**: HTML parsing and manipulation
**Version**: Latest compatible
**Package URL**: `https://github.com/nolanw/HTMLReader`

```swift
// Package.swift
.package(url: "https://github.com/nolanw/HTMLReader", from: "2.1.7")
```

**Usage:**
- Parsing HTML responses from Something Awful Forums
- Extracting structured data from forum pages
- Manipulating HTML content for display

**Key Classes:**
- `HTMLDocument`: Main HTML document representation
- `HTMLElement`: Individual HTML elements
- `HTMLSelector`: CSS selector support

**Example:**
```swift
let document = HTMLDocument(string: htmlString)
let posts = document.nodes(matchingSelector: ".postbody")
```

#### Nuke
**Purpose**: Advanced image loading and caching
**Version**: Latest compatible
**Package URL**: `https://github.com/kean/Nuke`

```swift
// Package.swift
.package(url: "https://github.com/kean/Nuke", from: "12.0.0")
```

**Usage:**
- Loading user avatars and profile images
- Caching images for offline viewing
- Handling animated GIFs and WebP images
- Progressive image loading

**Key Features:**
- Memory and disk caching
- Request deduplication
- Progressive JPEG support
- Animated image support

**Example:**
```swift
Nuke.loadImage(with: url, into: imageView)
```

#### Stencil
**Purpose**: Template engine for HTML generation
**Version**: Latest compatible
**Package URL**: `https://github.com/stencilproject/Stencil`

```swift
// Package.swift
.package(url: "https://github.com/stencilproject/Stencil", from: "0.15.1")
```

**Usage:**
- Rendering forum posts with custom styling
- Generating HTML for web views
- Template-based email composition

**Key Classes:**
- `Template`: Template representation
- `Environment`: Template rendering environment
- `Context`: Template variable context

**Example:**
```swift
let template = Template(templateString: templateString)
let rendered = try template.render(context)
```

#### Lottie
**Purpose**: Vector animation playback
**Version**: Latest compatible
**Package URL**: `https://github.com/airbnb/lottie-ios`

```swift
// Package.swift
.package(url: "https://github.com/airbnb/lottie-ios", from: "4.0.0")
```

**Usage:**
- Loading animations and spinners
- Refresh animations (frog, ghost)
- Interactive UI elements

**Key Classes:**
- `LottieAnimationView`: Main animation view
- `LottieAnimation`: Animation data model

**Example:**
```swift
let animationView = LottieAnimationView(name: "frogrefresh60")
animationView.play()
```

#### FLAnimatedImage
**Purpose**: High-performance animated GIF support
**Version**: Latest compatible
**Package URL**: `https://github.com/Flipboard/FLAnimatedImage`

```swift
// Package.swift
.package(url: "https://github.com/Flipboard/FLAnimatedImage", from: "1.0.17")
```

**Usage:**
- Displaying animated GIFs in posts
- Efficient memory usage for large GIFs
- Smooth animation playback

**Key Classes:**
- `FLAnimatedImageView`: View for animated images
- `FLAnimatedImage`: Animated image data model

**Example:**
```swift
let animatedImageView = FLAnimatedImageView()
animatedImageView.animatedImage = FLAnimatedImage(animatedGIFData: gifData)
```

#### Foil
**Purpose**: UserDefaults property wrapper with type safety
**Version**: Latest compatible
**Package URL**: `https://github.com/jessesquires/Foil`

```swift
// Package.swift
.package(url: "https://github.com/jessesquires/Foil", from: "4.0.0")
```

**Usage:**
- Type-safe UserDefaults access in AwfulSettings
- Settings property wrapper implementation
- Default value management

**Key Features:**
- `@FoilDefaultStorage` property wrapper
- Type-safe UserDefaults access
- Default value specification

**Example:**
```swift
@FoilDefaultStorage(Settings.darkMode)
private var darkMode: Bool
```

### Internal Package Dependencies

#### AwfulCore
**Purpose**: Core business logic and networking
**Location**: Local package in project

**Dependencies:**
- HTMLReader
- Foundation
- CoreData

**Exports:**
- `ForumsClient` - Main API client
- Core Data model objects
- Networking utilities

#### AwfulSettings
**Purpose**: Settings management with type safety
**Location**: Local package in project

**Dependencies:**
- Foil
- SystemCapabilities
- Foundation

**Exports:**
- `Settings` enum with all app settings
- `@FoilDefaultStorage` property wrapper
- Settings migration support

#### AwfulTheming
**Purpose**: Theme system and UI styling
**Location**: Local package in project

**Dependencies:**
- AwfulSettings
- AwfulModelTypes
- SwiftUI
- UIKit

**Exports:**
- `Theme` class for theme management
- Theme-related extensions
- CSS compilation utilities

#### Smilies
**Purpose**: Smilie keyboard and data management
**Location**: Local package in project

**Dependencies:**
- Core Data
- Foundation

**Exports:**
- Smilie data management
- Keyboard view components
- Web archive parsing

## Vendor Dependencies

### Manually Included Libraries

#### ARChromeActivity / TUSafariActivity
**Purpose**: Activity items for external browsers
**Location**: `Vendor/ARChromeActivity/`, `Vendor/TUSafariActivity/`
**Version**: Custom implementation using original assets

**Usage:**
- Share sheet integration for Chrome
- Share sheet integration for Safari
- Custom UIActivity implementations

**Files:**
```
Vendor/ARChromeActivity/
├── ARChromeActivity.xcassets/
└── LICENSE

Vendor/TUSafariActivity/
├── TUSafariActivity.bundle/
└── LICENSE.md
```

**Why Vendor:** Assets only - custom UIActivity implementation

#### MRProgress
**Purpose**: Progress indicators and HUDs
**Location**: `Vendor/MRProgress/`
**Version**: Custom Swift Package Manager integration

**Usage:**
- Loading indicators
- Progress overlays
- Status updates

**Migration Note:** Has Package.swift for potential SPM migration

#### PSMenuItem
**Purpose**: Custom menu item components
**Location**: `Vendor/PSMenuItem/`
**Version**: Custom Swift Package Manager integration

**Usage:**
- Context menu items
- Action sheet components
- Custom menu interfaces

**Migration Note:** Has Package.swift for potential SPM migration

#### PullToRefresh
**Purpose**: Custom pull-to-refresh implementation
**Location**: `Vendor/PullToRefresh/`
**Version**: Custom Swift Package Manager integration

**Usage:**
- Custom refresh animations
- Specialized refresh behavior
- Theme-aware refresh indicators

**Migration Note:** Has Package.swift for potential SPM migration

#### lottie-player.js
**Purpose**: Lottie animation playback in web views
**Location**: `Vendor/lottie-player.js`
**Version**: Bundled JavaScript file

**Usage:**
- Web view animation support
- Forum post animations
- Cross-platform animation consistency

**Why Vendor:** JavaScript dependency for web views

### ScrollViewDelegateMultiplexer
**Purpose**: Multiple delegate support for scroll views
**Location**: Local package in project
**Language**: Objective-C

**Usage:**
- Supporting multiple scroll view delegates
- Complex scroll view coordination
- Legacy Objective-C integration

## System Framework Dependencies

### Core iOS Frameworks

#### Foundation
**Purpose**: Fundamental data types and services
**Usage:**
- Basic data types (String, Array, Dictionary)
- Networking (URLSession)
- Date and time handling
- UserDefaults

#### UIKit
**Purpose**: User interface framework
**Usage:**
- View controllers and views
- Table views and collection views
- Navigation and tab bar controllers
- Gesture recognition

#### SwiftUI
**Purpose**: Modern declarative UI framework
**Usage:**
- Settings interface components
- New UI components
- Cross-platform UI elements
- State management

#### Core Data
**Purpose**: Object persistence framework
**Usage:**
- Forum data persistence
- Core Data model management
- Relationship handling
- Data migration

#### WebKit
**Purpose**: Web content rendering
**Usage:**
- Posts view rendering
- HTML content display
- JavaScript execution
- Custom web view behavior

#### CoreGraphics
**Purpose**: 2D graphics rendering
**Usage:**
- Custom drawing
- Image manipulation
- Graphics context operations
- Path drawing

#### QuartzCore
**Purpose**: Core animation framework
**Usage:**
- Layer animations
- Custom transitions
- Visual effects
- Performance optimizations

### System Integration Frameworks

#### SafariServices
**Purpose**: Safari integration
**Usage:**
- SFSafariViewController for web browsing
- Safari-based authentication
- Web content presentation

#### MessageUI
**Purpose**: Mail and message composition
**Usage:**
- Sharing forum content via email
- Bug report composition
- Contact integration

#### StoreKit
**Purpose**: App Store integration
**Usage:**
- App Store reviews
- In-app purchase support (future)
- App Store Connect integration

## Development Dependencies

### Testing Frameworks

#### XCTest
**Purpose**: Unit and integration testing
**Usage:**
- Unit test cases
- Integration testing
- UI testing
- Performance testing

### Development Tools

#### Swift Package Manager
**Purpose**: Dependency management
**Usage:**
- Managing external dependencies
- Local package development
- Version resolution

#### Xcode Build System
**Purpose**: Build process management
**Usage:**
- Swift compilation
- Resource bundling
- Code signing
- Archive creation

## Build Tool Dependencies

### Node.js Dependencies (package.json)

#### Less CSS Compiler
**Purpose**: CSS preprocessing
**Version**: Specified in package.json

```json
{
  "dependencies": {
    "less": "^4.1.0"
  }
}
```

**Usage:**
- Compiling .less files to CSS
- Theme stylesheet generation
- Build-time CSS processing

### Python Dependencies

#### Scripts
**Purpose**: Build automation
**Location**: `Scripts/` directory

**Files:**
- `bump.py` - Version bumping
- `submit.py` - App Store submission
- Various shell scripts

**Usage:**
- Automated version management
- Build process automation
- App Store Connect integration

## Dependency Management Guidelines

### Adding New Dependencies

1. **Evaluation Criteria:**
   - Active maintenance
   - Swift Package Manager support
   - iOS version compatibility
   - Performance impact
   - License compatibility

2. **Preference Order:**
   - Swift Package Manager
   - Vendor integration (if SPM unavailable)
   - System frameworks (when possible)

3. **Documentation Requirements:**
   - Update this dependency reference
   - Document usage patterns
   - Include migration notes

### Updating Dependencies

1. **Testing Requirements:**
   - Run full test suite
   - Test on multiple iOS versions
   - Verify performance impact

2. **Version Strategy:**
   - Use semantic versioning ranges
   - Pin major versions for stability
   - Document breaking changes

3. **Rollback Plan:**
   - Maintain previous working versions
   - Document compatibility requirements
   - Test downgrade scenarios

### Removing Dependencies

1. **Migration Strategy:**
   - Identify replacement functionality
   - Create migration timeline
   - Update documentation

2. **Code Cleanup:**
   - Remove unused imports
   - Update build configurations
   - Clean up vendor directories

## Version Requirements

### Minimum iOS Version
- **Current Target:** iOS 15.0
- **Rationale:** Balance of feature availability and device support

### Swift Version
- **Current Version:** Swift 5.0+
- **Xcode Version:** Xcode 16+

### Dependency Version Constraints

```swift
// Example Package.swift constraints
.package(url: "https://github.com/kean/Nuke", from: "12.0.0"),           // Allow minor updates
.package(url: "https://github.com/nolanw/HTMLReader", from: "2.1.7"),    // Allow minor updates
.package(url: "https://github.com/stencilproject/Stencil", from: "0.15.1"), // Allow minor updates
```

### Compatibility Matrix

| Dependency | Minimum iOS | Swift Version | Notes |
|------------|-------------|---------------|-------|
| Nuke | 13.0 | 5.0+ | Image loading |
| HTMLReader | 9.0 | 4.0+ | HTML parsing |
| Stencil | 10.0 | 5.0+ | Templating |
| Lottie | 11.0 | 5.0+ | Animations |
| FLAnimatedImage | 9.0 | 4.0+ | GIF support |

## Security Considerations

### Dependency Security

1. **Source Verification:**
   - Use official repositories
   - Verify package signatures
   - Review dependency chains

2. **Vulnerability Monitoring:**
   - Regular security audits
   - Monitor security advisories
   - Update vulnerable dependencies

3. **Network Dependencies:**
   - Validate SSL/TLS usage
   - Review network permissions
   - Audit data transmission

### Privacy Considerations

1. **Data Collection:**
   - Review dependency privacy policies
   - Audit data collection practices
   - Document privacy implications

2. **Third-Party Services:**
   - Limit external service dependencies
   - Review terms of service
   - Implement privacy controls

### License Compliance

1. **License Compatibility:**
   - GPL-compatible licenses only
   - Document license requirements
   - Include license files

2. **Attribution Requirements:**
   - Maintain license files
   - Include required attributions
   - Update acknowledgments

### Common License Types

| Dependency | License | Requirements |
|------------|---------|--------------|
| HTMLReader | MIT | Attribution |
| Nuke | MIT | Attribution |
| Stencil | MIT | Attribution |
| Lottie | Apache 2.0 | Attribution |
| FLAnimatedImage | MIT | Attribution |

This dependency reference provides a comprehensive overview of all external and internal dependencies used in the Awful.app project, enabling developers to understand the project's dependency landscape and make informed decisions about dependency management.