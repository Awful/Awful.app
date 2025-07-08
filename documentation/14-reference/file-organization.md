# File Organization Guidelines

Comprehensive guidelines for organizing files and directories in the Awful.app project.

## Table of Contents

- [Project Structure Overview](#project-structure-overview)
- [Directory Naming Conventions](#directory-naming-conventions)
- [File Naming Conventions](#file-naming-conventions)
- [Module Organization](#module-organization)
- [Resource Organization](#resource-organization)
- [Configuration Files](#configuration-files)
- [Documentation Structure](#documentation-structure)
- [Best Practices](#best-practices)

## Project Structure Overview

The Awful.app project follows a modular architecture with clear separation between different concerns:

```
Awful.app/
├── App/                          # Main iOS application
├── AwfulCore/                    # Core business logic package
├── AwfulExtensions/              # Shared extensions package
├── AwfulSettings/                # Settings management package
├── AwfulTheming/                 # Theme system package
├── Smilies/                      # Smilie keyboard package
├── Vendor/                       # Third-party dependencies
├── Config/                       # Build configuration
├── Scripts/                      # Build and utility scripts
├── documentation/                # Project documentation
└── Supporting Files/             # Project metadata
```

### Root Level Structure

```
Awful.app/
├── Awful.xcodeproj/             # Xcode project file
├── Package.swift                # Swift Package Manager manifest
├── README.md                    # Project overview
├── CONTRIBUTING.md              # Contribution guidelines
├── CLAUDE.md                    # AI assistant instructions
├── Local.sample.xcconfig        # Sample local configuration
├── Local.sample.entitlements    # Sample entitlements
└── .gitignore                   # Git ignore rules
```

## Directory Naming Conventions

### General Rules

1. **Use PascalCase** for directories containing code
2. **Use lowercase with hyphens** for configuration and documentation
3. **Use descriptive names** that clearly indicate contents
4. **Group related files** in logical subdirectories

### Code Directories

```
App/
├── View Controllers/            # View controller classes
├── Views/                       # Custom view classes
├── Model/                       # Model classes (if not in separate package)
├── Extensions/                  # App-specific extensions
├── Resources/                   # App resources
├── Main/                        # App delegate and main files
├── Config/                      # App-specific configuration
└── Supporting Files/            # Info.plist, entitlements, etc.
```

### Feature-Based Organization

Organize by feature when directories become large:

```
App/View Controllers/
├── Posts/
│   ├── PostsPageViewController.swift
│   ├── PostPreviewViewController.swift
│   ├── ReportPostViewController.swift
│   └── Supporting Views/
├── Threads/
│   ├── ThreadsTableViewController.swift
│   ├── ThreadComposeViewController.swift
│   └── BookmarksTableViewController.swift
├── Forums/
│   ├── ForumsTableViewController.swift
│   ├── ForumListCell.swift
│   └── ForumListSectionHeaderView.swift
└── Messages/
    ├── MessageListViewController.swift
    ├── MessageComposeViewController.swift
    └── MessageViewController.swift
```

### Package Organization

Each Swift package follows this structure:

```
PackageName/
├── Package.swift                # Package manifest
├── README.md                    # Package documentation
├── Sources/
│   └── PackageName/
│       ├── Public API/          # Public interfaces
│       ├── Internal/            # Internal implementation
│       ├── Extensions/          # Package-specific extensions
│       └── Resources/           # Package resources
├── Tests/
│   └── PackageNameTests/
│       ├── Unit Tests/
│       ├── Integration Tests/
│       └── Resources/
└── Documentation/               # Package-specific docs
```

## File Naming Conventions

### Swift Files

#### Class and Struct Files

Name files after the primary type they contain:

```
✅ Good:
ForumsClient.swift               # Contains ForumsClient class
ThreadTag.swift                  # Contains ThreadTag struct
PostsPageViewController.swift    # Contains PostsPageViewController class

❌ Bad:
client.swift                     # Too generic
forums_client.swift              # Wrong case
ForumsClientClass.swift          # Redundant suffix
```

#### Extension Files

Use descriptive names for extension files:

```
✅ Good:
UIColor+Theme.swift              # UIColor theming extensions
String+HTML.swift                # String HTML utilities
ForumsClient+Search.swift        # ForumsClient search methods

❌ Bad:
Extensions.swift                 # Too generic
UIColorExt.swift                 # Non-standard abbreviation
```

#### Protocol Files

Name protocol files after the protocol:

```
✅ Good:
Refreshable.swift                # Contains Refreshable protocol
ThemeProviding.swift             # Contains ThemeProviding protocol

❌ Bad:
Protocols.swift                  # Too generic
RefreshableProtocol.swift        # Redundant suffix
```

#### Category Files

Group related functionality:

```
✅ Good:
NetworkingHelpers.swift          # Network utility functions
HTMLParsingHelpers.swift         # HTML parsing utilities
DateFormatters.swift             # Date formatting utilities

❌ Bad:
Helpers.swift                    # Too generic
Utils.swift                      # Too generic
```

### Objective-C Files

Follow the same naming conventions as Swift but with appropriate extensions:

```
✅ Good:
MessageViewController.h/.m       # Header and implementation
RenderView.h/.m                  # Custom view
SmilieDataStore.h/.m             # Data management

❌ Bad:
messageVC.h/.m                   # Abbreviated and wrong case
render_view.h/.m                 # Wrong case style
```

### Resource Files

#### Asset Catalogs

```
✅ Good:
Assets.xcassets                  # Main app assets
AppIcons.xcassets               # App icon variants
ThreadTags.xcassets             # Thread tag images

❌ Bad:
images.xcassets                 # Too generic
assets1.xcassets                # Numbered variants
```

#### Storyboards

```
✅ Good:
Main.storyboard                 # Main interface
Login.storyboard                # Login flow
Settings.storyboard             # Settings interface

❌ Bad:
Interface.storyboard            # Too generic
UI.storyboard                   # Abbreviated
```

#### XIB Files

```
✅ Good:
PostsPageSettings.xib           # Posts page settings
InAppActionSheet.xib            # In-app action sheet
Selectotron.xib                 # Custom component

❌ Bad:
Settings.xib                    # Too generic
UI1.xib                         # Numbered variants
```

### Configuration Files

```
✅ Good:
Common.xcconfig                 # Shared build settings
Common-Debug.xcconfig           # Debug-specific settings
Common-Release.xcconfig         # Release-specific settings
Awful-Debug.xcconfig            # App debug settings

❌ Bad:
config.xcconfig                 # Too generic
debug.xcconfig                  # Missing context
```

### Test Files

```
✅ Good:
ForumsClientTests.swift         # Tests for ForumsClient
HTMLParsingTests.swift          # HTML parsing tests
IntegrationTests.swift          # Integration test suite

❌ Bad:
Tests.swift                     # Too generic
TestCase1.swift                 # Numbered variants
UnitTests.swift                 # Category without specifics
```

## Module Organization

### AwfulCore Package

The core business logic package:

```
AwfulCore/
├── Package.swift
├── README.md
├── Sources/
│   └── AwfulCore/
│       ├── Networking/
│       │   ├── ForumsClient.swift
│       │   ├── URLSession+Extensions.swift
│       │   └── CachebustingSessionDelegate.swift
│       ├── Model/
│       │   ├── User.swift
│       │   ├── Forum.swift
│       │   ├── Thread.swift
│       │   ├── Post.swift
│       │   └── AwfulManagedObject.swift
│       ├── Data/
│       │   ├── DataStore.swift
│       │   └── CachePruner.swift
│       ├── Scraping/
│       │   ├── ScrapeResult.swift
│       │   └── HTMLDocument+Extensions.swift
│       └── Utilities/
│           ├── Base62.swift
│           └── Errors.swift
└── Tests/
    └── AwfulCoreTests/
        ├── ForumsClientTests.swift
        ├── ModelTests.swift
        └── Fixtures/
```

### AwfulSettings Package

Settings management:

```
AwfulSettings/
├── Package.swift
├── README.md
├── Sources/
│   └── AwfulSettings/
│       ├── Settings.swift           # Setting definitions
│       ├── FoilDefaultStorage.swift # Property wrapper
│       ├── Migration.swift          # Settings migration
│       └── UserDefaults+Extensions.swift
└── Tests/
    └── AwfulSettingsTests/
        └── SettingsTests.swift
```

### AwfulTheming Package

Theme system:

```
AwfulTheming/
├── Package.swift
├── Sources/
│   └── AwfulTheming/
│       ├── Themes.swift             # Theme management
│       ├── ForumTweaks.swift        # Forum-specific styling
│       ├── View+Themed.swift        # SwiftUI theming
│       ├── ViewController.swift     # UIKit theming
│       ├── Resources/
│       │   ├── Themes.plist         # Theme definitions
│       │   ├── ForumTweaks.plist    # Forum-specific tweaks
│       │   └── Stylesheets/
│       │       ├── posts-view.less
│       │       ├── posts-view-fyad.less
│       │       └── posts-view-yospos.less
│       └── Localizable.xcstrings
└── Tests/
    └── AwfulThemingTests/
```

### Smilies Package

Smilie keyboard functionality:

```
Smilies/
├── Package.swift
├── README.md
├── Sources/
│   ├── Smilies/
│   │   ├── SmilieDataStore.m        # Core Data management
│   │   ├── SmilieKeyboard.m         # Keyboard implementation
│   │   ├── SmilieButton.m           # UI components
│   │   └── SmilieOperation.m        # Download operations
│   └── WebArchive/
│       └── SmilieWebArchive.m       # Web archive parsing
└── Tests/
    └── SmiliesTests/
        ├── SmiliesTests.m
        ├── ScrapingTests.m
        └── Fixtures/
            └── showsmilies.webarchive
```

## Resource Organization

### App Resources

```
App/Resources/
├── Assets.xcassets/
│   ├── Colors/                      # Color definitions
│   ├── Images/                      # General images
│   ├── Thread Tags/                 # Thread tag icons
│   └── App Icons/                   # App icon variants
├── Images/                          # Legacy images
│   ├── bg_menu.jpg
│   ├── cat.gif
│   └── spinner-button.png
├── Theming/                         # Theme assets
│   ├── amberpos-ins.gif
│   ├── diamond-icon.png
│   └── macinyos-wallpaper@2x.png
├── Lotties/                         # Lottie animations
│   ├── frogrefresh60.json
│   ├── ghost60.json
│   └── niggly60.json
├── Templates/                       # HTML templates
│   ├── PostsView.html.stencil
│   ├── Post.html.stencil
│   └── Profile.html.stencil
├── Info.plist                       # App metadata
├── Localizable.xcstrings            # Localized strings
└── PrivacyInfo.xcprivacy           # Privacy manifest
```

### Package Resources

Each package organizes its resources appropriately:

```
AwfulTheming/Sources/AwfulTheming/
├── Resources/
│   ├── Themes.plist                 # Theme definitions
│   ├── ForumTweaks.plist           # Forum customizations
│   └── Stylesheets/                # CSS/Less files
│       ├── posts-view.less
│       ├── posts-view.css           # Generated
│       ├── posts-view-fyad.less
│       └── posts-view-yospos.less
└── Localizable.xcstrings            # Package strings
```

### Third-Party Resources

```
Vendor/
├── ARChromeActivity/
│   └── ARChromeActivity.xcassets/   # Activity icons
├── TUSafariActivity/
│   └── TUSafariActivity.bundle/     # Safari activity icons
├── MRProgress/                      # Progress indicators
├── PSMenuItem/                      # Menu items
├── PullToRefresh/                   # Pull-to-refresh
└── lottie-player.js                # Lottie web player
```

## Configuration Files

### Build Configuration

```
Config/
├── Common.xcconfig                  # Shared settings
├── Common-Debug.xcconfig            # Debug configuration
├── Common-Release.xcconfig          # Release configuration
└── Awful.xctestplan                # Test plan configuration
```

### App-Specific Configuration

```
App/Config/
├── Awful-Debug.xcconfig            # App debug settings
└── Awful-Release.xcconfig          # App release settings
```

### Local Configuration

```
# Root level (not committed)
Local.xcconfig                      # Local build settings
Local.entitlements                  # Local entitlements

# Samples (committed)
Local.sample.xcconfig               # Sample local settings
Local.sample.entitlements           # Sample entitlements
```

### Test Plans

```
Config/
└── Awful.xctestplan               # Test execution plan
    ├── Unit Tests
    ├── Integration Tests
    └── UI Tests
```

## Documentation Structure

### Project Documentation

```
documentation/
├── README.md                       # Documentation overview
├── 01-getting-started/
│   ├── README.md
│   ├── setup-guide.md
│   ├── quick-start.md
│   └── project-overview.md
├── 02-architecture/
│   ├── README.md
│   ├── system-overview.md
│   ├── module-structure.md
│   └── design-patterns.md
├── 03-core-systems/
│   ├── README.md
│   ├── forums-client.md
│   ├── core-data-stack.md
│   └── authentication.md
├── 04-user-flows/
│   ├── README.md
│   ├── forum-navigation.md
│   ├── thread-reading.md
│   └── posting-workflow.md
├── 05-ui-components/
│   ├── README.md
│   ├── view-controllers.md
│   ├── custom-views.md
│   └── navigation-patterns.md
├── 06-data-layer/
│   ├── README.md
│   ├── core-data-model.md
│   ├── data-flow.md
│   └── offline-support.md
├── 07-theming/
│   ├── README.md
│   ├── theme-architecture.md
│   ├── creating-themes.md
│   └── css-integration.md
├── 08-integrations/
│   ├── README.md
│   ├── third-party-libraries.md
│   ├── keyboard-extension.md
│   └── url-schemes.md
├── 09-migration-guides/
│   ├── README.md
│   ├── uikit-to-swiftui.md
│   └── authentication-migration.md
├── 10-legacy-code/
│   ├── README.md
│   ├── objective-c-components.md
│   └── refactoring-guidelines.md
├── 11-testing/
│   ├── README.md
│   ├── unit-testing.md
│   ├── integration-testing.md
│   └── ui-testing.md
├── 12-security/
│   ├── README.md
│   ├── authentication-security.md
│   └── data-protection.md
├── 13-troubleshooting/
│   ├── README.md
│   ├── common-issues.md
│   └── debugging-tools.md
└── 14-reference/
    ├── README.md
    ├── api-reference.md
    ├── code-standards.md
    ├── architecture-patterns.md
    ├── file-organization.md
    ├── naming-conventions.md
    ├── dependencies.md
    ├── build-configuration.md
    ├── keyboard-shortcuts.md
    └── glossary.md
```

### Package Documentation

Each package includes its own documentation:

```
PackageName/
├── README.md                       # Package overview
├── CHANGELOG.md                    # Version history
├── Documentation/
│   ├── API.md                      # API documentation
│   ├── Examples.md                 # Usage examples
│   └── Migration.md                # Migration guides
└── Sources/
    └── PackageName/
        └── Documentation.docc/     # DocC documentation
```

## Best Practices

### File Organization Principles

1. **Logical Grouping**: Group related files together
2. **Consistent Naming**: Follow established naming conventions
3. **Clear Hierarchy**: Use nested directories for complex features
4. **Separation of Concerns**: Keep different types of files separate

### Directory Structure Guidelines

1. **Flat When Possible**: Avoid deep nesting unless necessary
2. **Feature-Based**: Organize by feature rather than file type when features are complex
3. **Consistent Structure**: Use the same organization pattern across similar modules
4. **Clear Boundaries**: Make it obvious where different concerns are handled

### File Naming Best Practices

1. **Descriptive Names**: Names should clearly indicate file contents
2. **Avoid Abbreviations**: Use full words unless abbreviations are standard
3. **Consistent Case**: Follow Swift/iOS conventions (PascalCase for types, camelCase for instances)
4. **Extension Clarity**: Use appropriate file extensions

### Resource Management

1. **Asset Catalogs**: Use asset catalogs for images and colors when possible
2. **Bundle Resources**: Keep package resources within package bundles
3. **Localization**: Organize localized resources consistently
4. **Version Control**: Be mindful of binary file sizes in version control

### Documentation Organization

1. **Hierarchical Structure**: Organize documentation from general to specific
2. **Cross-References**: Include links between related documentation
3. **Maintenance**: Keep documentation synchronized with code changes
4. **Accessibility**: Make documentation easy to navigate and search

### Maintenance Considerations

1. **Regular Review**: Periodically review and reorganize file structure
2. **Cleanup**: Remove unused files and directories
3. **Migration**: Plan for file reorganization during major refactors
4. **Team Communication**: Communicate organizational changes to the team

This file organization system ensures that the Awful.app project remains maintainable, navigable, and scalable as it grows and evolves.