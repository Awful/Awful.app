# Build Problems

## Overview

This document covers compilation issues, dependency problems, and build configuration errors when developing Awful.app.

## Environment Setup Issues

### Xcode Version Requirements
**Problem**: Build fails with older Xcode versions
**Requirements**:
- Xcode 16.0 or later
- iOS 18.4+ deployment target
- macOS 15.4+ for development

**Solution**:
1. Update Xcode from Mac App Store
2. Check deployment target in project settings
3. Verify Swift version compatibility

### Missing Development Team
**Problem**: "No account for team" error
**Error Message**: `No account for team 'XXXXXXXXXX'`

**Solution**:
1. Create `Local.xcconfig` from sample:
   ```bash
   cp Local.sample.xcconfig Local.xcconfig
   ```
2. Set your development team:
   ```
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   ```
3. Find your team ID in Apple Developer portal

### Local Configuration Missing
**Problem**: Build fails due to missing local configuration
**Files Needed**:
- `Local.xcconfig`
- `Local.entitlements` (for App Group support)

**Setup Steps**:
```bash
# Copy configuration files
cp Local.sample.xcconfig Local.xcconfig
cp Local.sample.entitlements Local.entitlements

# Edit Local.xcconfig
nano Local.xcconfig
```

**Required Local.xcconfig Settings**:
```
DEVELOPMENT_TEAM = YOUR_TEAM_ID
CODE_SIGN_ENTITLEMENTS = Local.entitlements
```

## Dependency Issues

### Swift Package Manager Problems
**Problem**: Package resolution fails
**Error Messages**:
- `Package resolution failed`
- `Repository could not be accessed`
- `Package dependency is missing`

**Solutions**:
```bash
# Reset package caches
rm -rf ~/Library/Developer/Xcode/DerivedData
xcodebuild -resolvePackageDependencies

# In Xcode
# File → Packages → Reset Package Caches
# File → Packages → Update to Latest Package Versions
```

### Package Version Conflicts
**Problem**: Conflicting package versions
**Solution**:
1. Check Package.swift dependencies
2. Resolve version conflicts manually
3. Use exact version pins if needed
4. Clear package caches and retry

### Missing Package Dependencies
**Problem**: Required packages not found
**Check**:
1. Verify Package.swift includes all dependencies
2. Check package URLs are accessible
3. Ensure packages support current Swift version
4. Verify minimum platform requirements

## Code Signing Issues

### Provisioning Profile Problems
**Problem**: Code signing fails
**Error Messages**:
- `No matching provisioning profile found`
- `Code signing error`
- `Certificate not found`

**Solutions**:
1. Check Apple Developer account status
2. Verify certificates are installed
3. Update provisioning profiles
4. Set automatic signing if available

### App Group Configuration
**Problem**: App Group entitlements missing
**Required for**: Smilie keyboard extension sharing

**Setup**:
1. Create App Group in Apple Developer portal
2. Add to Local.entitlements:
   ```xml
   <key>com.apple.security.application-groups</key>
   <array>
       <string>group.com.robotsandpencils.Awful</string>
   </array>
   ```
3. Enable App Group in both app and extension targets

### Certificate Issues
**Problem**: Development certificates expired or missing
**Solutions**:
1. Check certificate validity in Keychain Access
2. Download new certificates from Apple Developer portal
3. Verify certificate trust settings
4. Clear old certificates if needed

## Compilation Errors

### Swift Compilation Failures
**Problem**: Swift code fails to compile
**Common Causes**:
- Swift version incompatibility
- Missing imports
- Type inference failures
- Syntax errors

**Debugging Steps**:
1. Check Swift version in build settings
2. Verify all imports are available
3. Add explicit type annotations
4. Check for breaking changes in dependencies

### Objective-C Bridging Issues
**Problem**: Swift-Objective-C bridging fails
**Solutions**:
1. Check bridging header configuration
2. Verify Objective-C imports in bridging header
3. Ensure proper header search paths
4. Check for circular dependencies

### Resource Compilation
**Problem**: Resources fail to compile
**Common Issues**:
- Missing asset catalog images
- Storyboard compilation errors
- Localization file problems

**Solutions**:
1. Verify all referenced resources exist
2. Check asset catalog configuration
3. Validate storyboard connections
4. Ensure localization files are well-formed

## Build Configuration Issues

### Debug vs Release Builds
**Problem**: Code works in debug but fails in release
**Common Causes**:
- Debug-only code paths
- Optimization issues
- Missing release configurations

**Solutions**:
1. Test release builds regularly
2. Use conditional compilation correctly:
   ```swift
   #if DEBUG
   // Debug-only code
   #endif
   ```
3. Check optimization settings
4. Verify release-specific configurations

### Build Settings Conflicts
**Problem**: Conflicting build settings
**Check**:
1. Project vs target settings
2. Configuration-specific overrides
3. xcconfig file conflicts
4. User-defined settings

### Scheme Configuration
**Problem**: Wrong scheme or configuration selected
**Solutions**:
1. Verify correct scheme is selected
2. Check scheme's build configuration
3. Ensure all targets are included
4. Verify scheme sharing settings

## Advanced Build Issues

### Derived Data Corruption
**Problem**: Build fails with mysterious errors
**Solution**:
```bash
# Clear derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Clear module cache
rm -rf ~/Library/Developer/Xcode/UserData/ModuleCache

# Reset Xcode preferences (last resort)
rm -rf ~/Library/Preferences/com.apple.dt.Xcode.plist
```

### Build System Issues
**Problem**: New build system causes failures
**Solutions**:
1. Try legacy build system temporarily
2. Check for unsupported build configurations
3. Verify build script compatibility
4. Update build scripts for new system

### Parallel Build Failures
**Problem**: Build fails only with parallel building
**Solutions**:
1. Disable parallel building temporarily
2. Check for build dependency issues
3. Verify thread-safe build scripts
4. Add explicit dependencies where needed

## Testing Build Issues

### Test Target Problems
**Problem**: Tests fail to build or run
**Common Issues**:
- Missing test dependencies
- Test host configuration
- Bundle loading failures

**Solutions**:
1. Check test target dependencies
2. Verify test host settings
3. Ensure test bundles are properly configured
4. Check for missing test resources

### UI Testing Issues
**Problem**: UI tests fail to build or run
**Solutions**:
1. Verify UI test target configuration
2. Check test app installation
3. Ensure proper test identifiers
4. Verify accessibility settings

## Build Script Problems

### Custom Build Scripts
**Problem**: Build scripts fail during compilation
**Common Issues**:
- Path problems
- Permission issues
- Missing dependencies
- Script syntax errors

**Debugging**:
1. Check script output in build log
2. Verify script permissions
3. Test scripts independently
4. Add error handling and logging

### Pre/Post Build Actions
**Problem**: Build phases fail
**Solutions**:
1. Check phase order and dependencies
2. Verify script paths and permissions
3. Test with minimal scripts
4. Add proper error handling

## Diagnostic Commands

### Build Diagnostics
```bash
# Verbose build output
xcodebuild -workspace Awful.xcworkspace -scheme Awful -destination "platform=iOS Simulator,name=iPhone 15" -verbose

# Check build settings
xcodebuild -workspace Awful.xcworkspace -scheme Awful -showBuildSettings

# Analyze build issues
xcodebuild -workspace Awful.xcworkspace -scheme Awful analyze

# Clean build
xcodebuild -workspace Awful.xcworkspace -scheme Awful clean
```

### Environment Verification
```bash
# Check Xcode version
xcodebuild -version

# Check available simulators
xcrun simctl list devices

# Check certificates
security find-identity -v -p codesigning

# Check provisioning profiles
security find-identity -v -p codesigning
```

## Resolution Strategies

### Systematic Troubleshooting
1. **Isolate the Issue**:
   - Test with clean project
   - Minimal reproduction case
   - Identify specific failing component

2. **Environment Reset**:
   - Clean build folder
   - Reset package caches
   - Clear derived data
   - Restart Xcode

3. **Configuration Verification**:
   - Check build settings
   - Verify scheme configuration
   - Validate local configuration files
   - Test with different configurations

4. **Dependency Management**:
   - Update packages
   - Resolve version conflicts
   - Check package requirements
   - Test with minimal dependencies

### Emergency Fixes
```bash
# Nuclear option - complete reset
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/com.apple.dt.Xcode
xcrun simctl erase all
# Restart Xcode
```

## Prevention Strategies

### Best Practices
1. **Version Control**:
   - Don't commit Local.xcconfig
   - Use .gitignore properly
   - Keep project files clean

2. **Configuration Management**:
   - Use consistent build settings
   - Document required local configuration
   - Test on clean environments

3. **Dependency Management**:
   - Pin package versions
   - Test updates thoroughly
   - Document dependency requirements

4. **Build Validation**:
   - Test both debug and release builds
   - Verify on different devices
   - Check with clean installs

### Continuous Integration
1. **Automated Building**:
   - Regular build verification
   - Multiple configuration testing
   - Dependency update monitoring

2. **Environment Consistency**:
   - Standardized build environments
   - Documented requirements
   - Automated setup scripts

## Getting Help

### When to Ask for Help
- After trying systematic troubleshooting
- With specific error messages
- When build works locally but fails elsewhere
- With configuration-specific issues

### Information to Provide
1. **Environment Details**:
   - Xcode version
   - macOS version
   - Project configuration

2. **Error Information**:
   - Complete error messages
   - Build log output
   - Console output

3. **Steps Taken**:
   - Troubleshooting attempts
   - Configuration changes
   - Workarounds tried

### Resources
- Apple Developer Documentation
- Xcode Release Notes
- Stack Overflow
- GitHub Issues
- Developer Forums