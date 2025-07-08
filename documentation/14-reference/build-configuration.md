# Build Configuration Reference

Comprehensive reference for build settings, schemes, configurations, and environment setup for the Awful.app project.

## Table of Contents

- [Project Structure](#project-structure)
- [Build Configurations](#build-configurations)
- [Schemes and Targets](#schemes-and-targets)
- [Xcode Configuration Files](#xcode-configuration-files)
- [Environment Variables](#environment-variables)
- [Code Signing](#code-signing)
- [Swift Package Manager](#swift-package-manager)
- [Build Scripts](#build-scripts)
- [CI/CD Configuration](#cicd-configuration)
- [Troubleshooting](#troubleshooting)

## Project Structure

### Xcode Project Organization

```
Awful.xcodeproj/
├── project.pbxproj                  # Main project file
├── project.xcworkspace/
│   ├── contents.xcworkspacedata     # Workspace configuration
│   ├── xcshareddata/
│   │   ├── IDEWorkspaceChecks.plist
│   │   └── swiftpm/
│   │       └── Package.resolved     # SPM dependency resolution
│   └── xcuserdata/                  # User-specific settings (not committed)
└── xcshareddata/
    └── xcschemes/                   # Shared build schemes
        ├── Awful.xcscheme
        ├── Smilie Keyboard.xcscheme
        ├── SmilieExtractor.xcscheme
        └── Smilies Stickers.xcscheme
```

### Build Configuration Files

```
Config/
├── Common.xcconfig                  # Shared build settings
├── Common-Debug.xcconfig            # Debug-specific settings
├── Common-Release.xcconfig          # Release-specific settings
└── Awful.xctestplan                # Test execution plan

App/Config/
├── Awful-Debug.xcconfig            # App-specific debug settings
└── Awful-Release.xcconfig          # App-specific release settings
```

## Build Configurations

### Common Settings (Common.xcconfig)

Base settings shared across all configurations:

```xcconfig
// Project-level build settings common to all configurations

// Place for settings that shouldn't be committed, like API keys
#include? "Local.xcconfig"

// Basic compiler settings
ALWAYS_SEARCH_USER_PATHS = NO
CLANG_ANALYZER_NONNULL = YES
CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE
CLANG_CXX_LANGUAGE_STANDARD = gnu++20
CLANG_ENABLE_MODULES = YES
CLANG_ENABLE_OBJC_ARC = YES
CLANG_ENABLE_OBJC_WEAK = YES

// Warning settings
CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES
CLANG_WARN_BOOL_CONVERSION = YES
CLANG_WARN_COMMA = YES
CLANG_WARN_CONSTANT_CONVERSION = YES
CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES
CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR
CLANG_WARN__DUPLICATE_METHOD_MATCH = YES
CLANG_WARN_EMPTY_BODY = YES
CLANG_WARN_ENUM_CONVERSION = YES
CLANG_WARN_INFINITE_RECURSION = YES
CLANG_WARN_INT_CONVERSION = YES
CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES
CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES
CLANG_WARN_OBJC_LITERAL_CONVERSION = YES
CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR
CLANG_WARN_RANGE_LOOP_ANALYSIS = YES
CLANG_WARN_STRICT_PROTOTYPES = YES
CLANG_WARN_SUSPICIOUS_IMPLICIT_CONVERSION = YES
CLANG_WARN_SUSPICIOUS_MOVE = YES
CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE
CLANG_WARN_UNREACHABLE_CODE = YES

// GCC settings
GCC_C_LANGUAGE_STANDARD = gnu17
GCC_NO_COMMON_BLOCKS = YES
GCC_THREADSAFE_STATICS = NO
GCC_TREAT_WARNINGS_AS_ERRORS = YES
GCC_WARN_64_TO_32_BIT_CONVERSION = YES
GCC_WARN_ABOUT_MISSING_FIELD_INITIALIZERS = YES
GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR
GCC_WARN_INITIALIZER_NOT_FULLY_BRACKETED = YES
GCC_WARN_SIGN_COMPARE = YES
GCC_WARN_UNDECLARED_SELECTOR = YES
GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE
GCC_WARN_UNUSED_FUNCTION = YES
GCC_WARN_UNUSED_LABEL = YES
GCC_WARN_UNUSED_VARIABLE = YES

// Swift settings
SWIFT_EMIT_LOC_STRINGS = YES
SWIFT_TREAT_WARNINGS_AS_ERRORS = YES
SWIFT_VERSION = 5.0

// Asset compilation
ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES

// Localization
LOCALIZATION_PREFERS_STRING_CATALOGS = YES

// Version information
MARKETING_VERSION = 7.9
DYLIB_CURRENT_VERSION = 70900

// Target platform
SDKROOT = iphoneos
TARGETED_DEVICE_FAMILY = 1,2

// Static analysis
RUN_CLANG_STATIC_ANALYZER = YES

// Metal settings
MTL_ENABLE_DEBUG_INFO = NO
MTL_FAST_MATH = YES

// Linking
LD_RUNPATH_SEARCH_PATHS = $(inherited) @executable_path/Frameworks @loader_path/Frameworks

// Additional warning flags
WARNING_CFLAGS = -Wall -Wextra -Wno-unused-parameter
```

### Debug Configuration (Common-Debug.xcconfig)

Debug-specific settings:

```xcconfig
#include "Common.xcconfig"

// Debug optimization
GCC_OPTIMIZATION_LEVEL = 0
SWIFT_OPTIMIZATION_LEVEL = -Onone

// Debug information
DEBUG_INFORMATION_FORMAT = dwarf
GCC_PREPROCESSOR_DEFINITIONS = DEBUG=1 $(inherited)

// Swift debugging
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG

// Metal debugging
MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE

// Enable assertions
ENABLE_NS_ASSERTIONS = YES

// Runtime checks
ENABLE_STRICT_OBJC_MSGSEND = YES

// No copy phase strip for debugging
COPY_PHASE_STRIP = NO

// Code generation
GCC_DYNAMIC_NO_PIC = NO

// Only active arch for faster builds
ONLY_ACTIVE_ARCH = YES
```

### Release Configuration (Common-Release.xcconfig)

Release-specific settings:

```xcconfig
#include "Common.xcconfig"

// Release optimization
GCC_OPTIMIZATION_LEVEL = s
SWIFT_OPTIMIZATION_LEVEL = -O

// Strip debug symbols
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
COPY_PHASE_STRIP = YES
STRIP_INSTALLED_PRODUCT = YES

// Disable assertions
ENABLE_NS_ASSERTIONS = NO

// All architectures
ONLY_ACTIVE_ARCH = NO

// Dead code stripping
DEAD_CODE_STRIPPING = YES

// Swift compilation mode
SWIFT_COMPILATION_MODE = wholemodule
```

### App-Specific Configurations

#### Awful-Debug.xcconfig
```xcconfig
#include "../Config/Common-Debug.xcconfig"

// App-specific debug settings
PRODUCT_BUNDLE_IDENTIFIER = com.awfulapp.Awful.debug
PROVISIONING_PROFILE_SPECIFIER = 

// Development team (override in Local.xcconfig)
DEVELOPMENT_TEAM = 

// Code signing
CODE_SIGN_STYLE = Automatic
CODE_SIGN_IDENTITY = iPhone Developer

// Entitlements (override in Local.xcconfig if needed)
CODE_SIGN_ENTITLEMENTS = 

// Base URL configuration
AWFUL_BASE_URL = https://forums.somethingawful.com
```

#### Awful-Release.xcconfig
```xcconfig
#include "../Config/Common-Release.xcconfig"

// App-specific release settings
PRODUCT_BUNDLE_IDENTIFIER = com.awfulapp.Awful
PROVISIONING_PROFILE_SPECIFIER = 

// Development team
DEVELOPMENT_TEAM = 

// Code signing
CODE_SIGN_STYLE = Automatic
CODE_SIGN_IDENTITY = iPhone Distribution

// Entitlements
CODE_SIGN_ENTITLEMENTS = 

// Base URL configuration
AWFUL_BASE_URL = https://forums.somethingawful.com
```

## Schemes and Targets

### Available Schemes

#### Awful (Main App)
**Target:** Awful
**Purpose:** Main iOS application

**Build Configuration:**
- Debug: Uses Awful-Debug.xcconfig
- Release: Uses Awful-Release.xcconfig

**Run Configuration:**
- Build Configuration: Debug
- Arguments: None by default
- Environment Variables: Configurable

**Test Configuration:**
- Test Plan: Awful.xctestplan
- Code Coverage: Enabled
- Parallelizable: Yes

**Archive Configuration:**
- Build Configuration: Release
- Strip Debug Symbols: Yes

#### Smilie Keyboard
**Target:** SmilieKeyboard
**Purpose:** Keyboard extension for smilies

**Dependencies:**
- Smilies package
- App Groups entitlement

**Build Configuration:**
- Inherits from main app configuration
- Extension-specific bundle identifier

#### SmilieExtractor
**Target:** SmilieExtractor
**Purpose:** Utility app for extracting smilie resources

**Purpose:** Development and maintenance tool
**Usage:** Extract smilies from web archives

#### Smilies Stickers
**Target:** SmiliesStickers
**Purpose:** iMessage sticker pack

**Dependencies:**
- Sticker assets
- iMessage framework

### Target Dependencies

```
Awful (Main App)
├── AwfulCore
├── AwfulSettings
├── AwfulTheming
├── AwfulExtensions
├── ImgurAnonymousAPI
├── LessStylesheet
├── SystemCapabilities
└── Vendor libraries

SmilieKeyboard
├── Smilies
├── AwfulExtensions
└── App Group sharing

SmilieExtractor
├── Smilies
└── WebArchive processing

SmiliesStickers
└── Static sticker assets
```

## Xcode Configuration Files

### Local Configuration

#### Local.xcconfig (Not Committed)
Template for local developer settings:

```xcconfig
// Local build settings that should not be committed
// Copy from Local.sample.xcconfig and customize

// Development team for code signing
DEVELOPMENT_TEAM = YOUR_TEAM_ID

// Code signing identity (optional)
CODE_SIGN_IDENTITY = iPhone Developer

// Custom entitlements file (optional)
CODE_SIGN_ENTITLEMENTS = Local.entitlements

// Base URL override (optional)
AWFUL_BASE_URL = https://forums.somethingawful.com

// Custom provisioning profiles (optional)
PROVISIONING_PROFILE_SPECIFIER = 

// API keys (if needed)
// IMGUR_CLIENT_ID = your_client_id
```

#### Local.entitlements (Not Committed)
Template for local entitlements:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Groups for sharing data with keyboard extension -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.YOUR_APP_GROUP_ID</string>
    </array>
    
    <!-- Keychain sharing (if needed) -->
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.awfulapp.Awful</string>
    </array>
</dict>
</plist>
```

### Test Plan Configuration

#### Awful.xctestplan
```json
{
  "configurations" : [
    {
      "id" : "Debug",
      "name" : "Debug",
      "options" : {
        "codeCoverage" : true,
        "testExecutionOrdering" : "random"
      }
    },
    {
      "id" : "Release", 
      "name" : "Release",
      "options" : {
        "codeCoverage" : false,
        "testExecutionOrdering" : "random"
      }
    }
  ],
  "defaultOptions" : {
    "codeCoverage" : true,
    "testExecutionOrdering" : "random",
    "testTimeoutsEnabled" : true
  },
  "testTargets" : [
    {
      "target" : {
        "containerPath" : "container:Awful.xcodeproj",
        "identifier" : "AwfulTests",
        "name" : "AwfulTests"
      }
    },
    {
      "target" : {
        "containerPath" : "container:AwfulCore",
        "identifier" : "AwfulCoreTests", 
        "name" : "AwfulCoreTests"
      }
    },
    {
      "target" : {
        "containerPath" : "container:AwfulExtensions",
        "identifier" : "AwfulExtensionsTests",
        "name" : "AwfulExtensionsTests"
      }
    },
    {
      "target" : {
        "containerPath" : "container:Smilies",
        "identifier" : "SmiliesTests",
        "name" : "SmiliesTests"
      }
    },
    {
      "target" : {
        "containerPath" : "container:AwfulScraping",
        "identifier" : "AwfulScrapingTests",
        "name" : "AwfulScrapingTests"
      }
    }
  ],
  "version" : 1
}
```

## Environment Variables

### Build-Time Variables

#### Xcode Environment Variables
```bash
# Set in scheme environment variables
AWFUL_BASE_URL = https://forums.somethingawful.com
DEVELOPMENT_LANGUAGE = en
SRCROOT = /path/to/project
BUILT_PRODUCTS_DIR = /path/to/build/products
```

#### Custom Environment Variables
```bash
# Debug mode
AWFUL_DEBUG_LOGGING = 1
AWFUL_MOCK_NETWORK = 0
AWFUL_SKIP_AUTHENTICATION = 0

# Testing
AWFUL_TEST_MODE = 1
AWFUL_FIXTURE_MODE = 1
```

### Runtime Environment

#### Info.plist Configuration
```xml
<dict>
    <!-- Base URL for forums -->
    <key>AwfulBaseURL</key>
    <string>https://forums.somethingawful.com</string>
    
    <!-- API version -->
    <key>AwfulAPIVersion</key>
    <string>1.0</string>
    
    <!-- Feature flags -->
    <key>AwfulFeatureFlags</key>
    <dict>
        <key>EnableSearchBeta</key>
        <true/>
    </dict>
</dict>
```

## Code Signing

### Development Code Signing

```xcconfig
// Automatic code signing for development
CODE_SIGN_STYLE = Automatic
CODE_SIGN_IDENTITY = iPhone Developer
DEVELOPMENT_TEAM = YOUR_TEAM_ID

// Entitlements for development
CODE_SIGN_ENTITLEMENTS = Local.entitlements
```

### App Store Code Signing

```xcconfig
// Manual code signing for distribution
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = iPhone Distribution
PROVISIONING_PROFILE_SPECIFIER = Awful App Store Profile

// Production entitlements
CODE_SIGN_ENTITLEMENTS = Awful.entitlements
```

### App Groups Setup

Required for sharing data between main app and keyboard extension:

1. **Create App Group in Developer Portal:**
   - Login to Apple Developer Portal
   - Create App Group with identifier like `group.com.yourname.awful`

2. **Configure Local.entitlements:**
   ```xml
   <key>com.apple.security.application-groups</key>
   <array>
       <string>group.com.yourname.awful</string>
   </array>
   ```

3. **Update Local.xcconfig:**
   ```xcconfig
   CODE_SIGN_ENTITLEMENTS = Local.entitlements
   ```

## Swift Package Manager

### Package.swift Structure

Each internal package follows this pattern:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AwfulCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "AwfulCore",
            targets: ["AwfulCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/nolanw/HTMLReader", from: "2.1.7"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "AwfulCore",
            dependencies: [
                "HTMLReader",
                .product(name: "Collections", package: "swift-collections"),
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AwfulCoreTests",
            dependencies: ["AwfulCore"],
            resources: [
                .process("Fixtures")
            ]
        ),
    ]
)
```

### Package Resolution

Package.resolved tracks exact dependency versions:

```json
{
  "pins" : [
    {
      "identity" : "htmlreader",
      "kind" : "remoteSourceControl",
      "location" : "https://github.com/nolanw/HTMLReader",
      "state" : {
        "revision" : "abcd1234",
        "version" : "2.1.7"
      }
    }
  ],
  "version" : 2
}
```

## Build Scripts

### Automated Version Management

#### Scripts/bump
```bash
#!/bin/bash
# Increment version numbers throughout the project

# Usage:
# Scripts/bump --build    # Increment build number
# Scripts/bump --minor    # Increment minor version
# Scripts/bump --major    # Increment major version

case "$1" in
    --build)
        python3 Scripts/bump.py --build
        ;;
    --minor)
        python3 Scripts/bump.py --minor
        ;;
    --major)
        python3 Scripts/bump.py --major
        ;;
    *)
        echo "Usage: $0 {--build|--minor|--major}"
        exit 1
        ;;
esac
```

#### Scripts/beta
```bash
#!/bin/bash
# Create beta build and optionally upload to App Store Connect

# Build archive
xcodebuild -scheme Awful -configuration Release archive \
    -archivePath build/Awful.xcarchive

# Export for App Store
xcodebuild -exportArchive \
    -archivePath build/Awful.xcarchive \
    -exportPath build/ \
    -exportOptionsPlist ExportOptions.plist

# Upload to App Store Connect (optional)
if [ "$1" = "--upload" ]; then
    xcrun altool --upload-app \
        --file build/Awful.ipa \
        --type ios \
        --username "$APPLE_ID" \
        --password "$APP_SPECIFIC_PASSWORD"
fi
```

### Build Phase Scripts

#### Less CSS Compilation
```bash
# Compile Less stylesheets to CSS
if which node >/dev/null; then
    cd "${SRCROOT}/AwfulTheming/Sources/AwfulTheming/Resources/Stylesheets"
    for lessfile in *.less; do
        if [ -f "$lessfile" ]; then
            cssfile="${lessfile%.less}.css"
            node_modules/.bin/lessc "$lessfile" "$cssfile"
        fi
    done
else
    echo "warning: Node.js not found, skipping Less compilation"
fi
```

#### App Icon Processing
```bash
# Process app icons after changes
python3 "${SRCROOT}/Scripts/app-icons"
```

## CI/CD Configuration

### GitHub Actions

#### CI Workflow (.github/workflows/ci.yml)
```yaml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
      with:
        submodules: recursive
        
    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: '16.0'
        
    - name: Install Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        
    - name: Install dependencies
      run: npm install
      
    - name: Build and test
      run: |
        xcodebuild test \
          -scheme Awful \
          -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
          -testPlan Awful \
          -enableCodeCoverage YES
          
    - name: Upload coverage
      uses: codecov/codecov-action@v3
```

### Continuous Deployment

#### App Store Connect Upload
```yaml
name: Deploy

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: '16.0'
        
    - name: Build archive
      run: |
        xcodebuild -scheme Awful \
          -configuration Release \
          archive -archivePath build/Awful.xcarchive
          
    - name: Export for App Store
      run: |
        xcodebuild -exportArchive \
          -archivePath build/Awful.xcarchive \
          -exportPath build/ \
          -exportOptionsPlist ExportOptions.plist
          
    - name: Upload to App Store Connect
      env:
        APPLE_ID: ${{ secrets.APPLE_ID }}
        APP_PASSWORD: ${{ secrets.APP_PASSWORD }}
      run: |
        xcrun altool --upload-app \
          --file build/Awful.ipa \
          --type ios \
          --username "$APPLE_ID" \
          --password "$APP_PASSWORD"
```

## Troubleshooting

### Common Build Issues

#### Missing Local.xcconfig
**Problem:** Build warnings about missing Local.xcconfig
**Solution:** 
```bash
# Create empty Local.xcconfig file
touch Local.xcconfig
```

#### App Group Entitlements
**Problem:** Keyboard extension can't access shared data
**Solution:**
1. Create App Group in Developer Portal
2. Copy Local.sample.entitlements to Local.entitlements
3. Add App Group identifier to Local.entitlements
4. Set CODE_SIGN_ENTITLEMENTS in Local.xcconfig

#### Swift Package Resolution
**Problem:** Package resolution fails
**Solution:**
```bash
# Reset package caches
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf .swiftpm

# Resolve packages
xcodebuild -resolvePackageDependencies
```

#### Node.js Dependencies
**Problem:** Less compilation fails
**Solution:**
```bash
# Install Node.js dependencies
npm install

# Verify Less compiler
npx lessc --version
```

### Build Performance

#### Slow Clean Builds
**Solutions:**
- Enable "Build Active Architecture Only" for Debug
- Use Derived Data on SSD
- Increase Xcode's CPU core usage

#### Large App Size
**Solutions:**
- Enable dead code stripping for Release
- Use asset catalogs for images
- Optimize image assets

### Debug Configuration

#### Network Request Debugging
```swift
#if DEBUG
URLProtocol.registerClass(DebugURLProtocol.self)
#endif
```

#### Core Data Debugging
```bash
# Add to scheme environment variables
com.apple.CoreData.SQLDebug = 1
com.apple.CoreData.ConcurrencyDebug = 1
```

This build configuration reference provides comprehensive information for setting up, configuring, and maintaining the build system for the Awful.app project.