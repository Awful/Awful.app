# Common Issues

## Overview

This document covers the most frequently encountered problems when developing or using Awful.app, along with their solutions.

## Build Issues

### Xcode Version Compatibility
**Problem**: App fails to build with older Xcode versions
**Solution**: 
- Ensure you're using Xcode 16.0 or later
- Check minimum deployment target requirements
- Update to latest Xcode from Mac App Store

### Development Team Not Set
**Problem**: "No account for team" error during build
**Solution**:
1. Create `Local.xcconfig` from `Local.sample.xcconfig`
2. Set your `DEVELOPMENT_TEAM` identifier
3. Ensure you have a valid Apple Developer account

### Package Dependencies Failed
**Problem**: Swift Package Manager fails to resolve dependencies
**Solution**:
```bash
# Reset package caches
rm -rf ~/Library/Developer/Xcode/DerivedData
xcodebuild -resolvePackageDependencies

# In Xcode: File → Packages → Reset Package Caches
```

### Missing Local Configuration
**Problem**: Build fails due to missing local configuration
**Solution**:
1. Copy `Local.sample.xcconfig` to `Local.xcconfig`
2. Set required values:
   ```
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   CODE_SIGN_ENTITLEMENTS = Local.entitlements
   ```
3. Copy `Local.sample.entitlements` to `Local.entitlements`

## Runtime Issues

### App Crashes on Launch
**Problem**: App crashes immediately after launch
**Common Causes**:
- Core Data model incompatibility
- Missing required files
- Corrupted user defaults
- Invalid theme configuration

**Solutions**:
1. Check Console.app for crash logs
2. Reset simulator/device data
3. Clear app data and preferences
4. Rebuild with clean build folder

### Login Screen Not Appearing
**Problem**: App bypasses login screen
**Cause**: Debug flag still enabled
**Solution**:
```swift
// Remove debug flag
UserDefaults.standard.removeObject(forKey: "AwfulSkipLogin")
```

### Smilie Keyboard Not Working
**Problem**: Smilie keyboard extension doesn't load
**Solutions**:
1. Check App Group configuration in `Local.entitlements`
2. Ensure keyboard extension is enabled in Settings
3. Verify bundle IDs match between app and extension
4. Restart device after installation

## Network Issues

### Forums Not Loading
**Problem**: Forum content fails to load
**Common Causes**:
- Something Awful server issues
- Network connectivity problems
- HTML parsing failures
- Authentication expired

**Solutions**:
1. Check Something Awful website directly
2. Verify network connection
3. Clear cookies and re-login
4. Check server status pages

### Image Loading Problems
**Problem**: Images don't load or display incorrectly
**Solutions**:
1. Clear image cache:
   ```swift
   ImageCache.shared.removeAll()
   ```
2. Check network permissions
3. Verify image URLs are accessible
4. Test with different image formats

## Core Data Issues

### Migration Failures
**Problem**: App crashes during Core Data migration
**Solutions**:
1. Delete app and reinstall (loses data)
2. Check migration mapping models
3. Verify model version compatibility
4. Test migration with sample data

### Data Corruption
**Problem**: Core Data store becomes corrupted
**Solutions**:
1. Enable SQL debugging:
   ```swift
   UserDefaults.standard.set(true, forKey: "AwfulCoreDataDebug")
   ```
2. Delete and recreate store
3. Check for concurrent access issues
4. Verify background context usage

## Theme Issues

### Custom Themes Not Loading
**Problem**: Custom themes don't apply correctly
**Solutions**:
1. Check theme file syntax
2. Verify parent theme exists
3. Clear theme cache
4. Restart app to reload themes

### CSS Styles Not Applied
**Problem**: Post styling appears broken
**Solutions**:
1. Check CSS file compilation
2. Verify Less.js processing
3. Clear web view cache
4. Test with default theme

## Performance Issues

### Slow App Launch
**Problem**: App takes long time to start
**Solutions**:
1. Profile with Instruments
2. Check for excessive database queries
3. Optimize image loading
4. Reduce initialization overhead

### Memory Warnings
**Problem**: App receives memory warnings
**Solutions**:
1. Profile memory usage
2. Clear image caches
3. Optimize Core Data queries
4. Check for retain cycles

## Authentication Issues

### Login Failures
**Problem**: Cannot log into Something Awful account
**Solutions**:
1. Verify account credentials
2. Check account status (not banned)
3. Try logging in via web browser
4. Clear cookies and app data

### Session Expiration
**Problem**: Frequent authentication timeouts
**Solutions**:
1. Check server-side session settings
2. Verify cookie handling
3. Implement proper session renewal
4. Monitor authentication state

## User Interface Issues

### UI Elements Not Responding
**Problem**: Buttons or controls don't respond to touch
**Solutions**:
1. Check view hierarchy for overlapping views
2. Verify touch event handling
3. Test with different device orientations
4. Check for modal presentation issues

### Layout Problems
**Problem**: UI elements appear misaligned or cut off
**Solutions**:
1. Check Auto Layout constraints
2. Test on different device sizes
3. Verify Safe Area usage
4. Check for dynamic type compatibility

## Debug Information

### Enabling Debug Logging
```swift
// Enable comprehensive logging
UserDefaults.standard.set(true, forKey: "AwfulDebugLogging")

// Log network requests
UserDefaults.standard.set(true, forKey: "AwfulNetworkDebug")

// Log Core Data operations
UserDefaults.standard.set(true, forKey: "AwfulCoreDataDebug")
```

### Useful Console Commands
```bash
# View device logs
xcrun simctl spawn booted log stream --predicate 'process == "Awful"'

# Reset all simulators
xcrun simctl erase all

# Clear Xcode caches
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/com.apple.dt.Xcode
```

## Quick Fixes

### General Troubleshooting Steps
1. **Clean Build**: Product → Clean Build Folder
2. **Reset Packages**: File → Packages → Reset Package Caches
3. **Clear Derived Data**: Delete ~/Library/Developer/Xcode/DerivedData
4. **Restart Xcode**: Quit and reopen Xcode
5. **Reset Simulator**: Device → Erase All Content and Settings

### Emergency Resets
```bash
# Complete development environment reset
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/com.apple.dt.Xcode
xcrun simctl erase all
```

## Getting Help

### Before Asking for Help
1. Check this documentation
2. Search existing GitHub issues
3. Verify you're using supported versions
4. Try the quick fixes above

### When Reporting Issues
Include:
- Exact error messages
- Steps to reproduce
- Environment details (Xcode version, iOS version, device)
- Console output or crash logs
- Screenshots if relevant

### Community Resources
- GitHub Issues: Report bugs and feature requests
- Development Community: Ask questions and share solutions
- Documentation: Check for updates and additional guides