# Setup Guide

## Overview

This guide walks you through setting up Awful.app for local development. Due to the app's age and community-driven nature, there are some unique setup requirements.

## Prerequisites

### Required Software
- **macOS**: 14.0 or later
- **Xcode**: 16.0 or later
- **Command Line Tools**: Install via `xcode-select --install`
- **Git**: For version control

### Optional but Recommended
- **SwiftLint**: For code style consistency
- **Charles Proxy** or **Proxyman**: For debugging network requests
- **SF Symbols**: For icon reference

## Step 1: Clone the Repository

```bash
cd ~/Developer  # or your preferred directory
git clone https://github.com/Awful/Awful.app.git
cd Awful.app
```

## Step 2: Configure Local Settings

Awful.app uses local configuration files that are not tracked in git:

### Create Local.xcconfig

```bash
cp Local.sample.xcconfig Local.xcconfig
```

Edit `Local.xcconfig` to add your development team ID:

```
// Local.xcconfig
DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

To find your Team ID:
1. Open Xcode
2. Go to Settings → Accounts
3. Select your Apple ID
4. View your team details

### Configure App Groups (for Smilie Keyboard)

If you want to test the Smilie keyboard extension:

```bash
cp Local.sample.entitlements Local.entitlements
```

Edit `Local.entitlements` to add your app group identifier:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.YOUR_APP_GROUP_ID</string>
    </array>
</dict>
</plist>
```

Then update `Local.xcconfig`:

```
CODE_SIGN_ENTITLEMENTS = Local.entitlements
```

## Step 3: Open the Project

```bash
open Awful.xcodeproj
```

## Step 4: Configure Xcode Project Settings

1. Select the "Awful" project in the navigator
2. Select the "Awful" target
3. Go to "Signing & Capabilities"
4. Select your development team
5. Xcode should automatically manage signing

## Step 5: Install Dependencies

The project uses Swift Package Manager for most dependencies. Xcode should automatically resolve these when you open the project.

### SPM Dependencies
- **Nuke**: Image loading and caching
- **HTMLReader**: HTML parsing (custom fork)
- **Stencil**: Template rendering
- **Lottie**: Animation support
- **FLAnimatedImage**: GIF support

### Vendor Dependencies
Some older dependencies are included in the `Vendor/` directory:
- MRProgress
- PSMenuItem
- PullToRefresh
- TUSafariActivity

## Step 6: Build and Run

1. Select the "Awful" scheme
2. Choose a simulator (iPhone 15 Pro recommended)
3. Press ⌘R or click the Run button

## Step 7: Test Login

To test the full app functionality:

1. You need a Something Awful Forums account
2. Run the app
3. Tap "Log In" on the launch screen
4. Enter your forums credentials
5. The app will save your authentication cookie

## Troubleshooting

### Common Issues

#### "No account for team" error
- Make sure you've set `DEVELOPMENT_TEAM` in `Local.xcconfig`
- Verify your Apple Developer account is properly configured in Xcode

#### Build fails with missing dependencies
- File → Packages → Reset Package Caches
- Clean build folder: ⇧⌘K

#### Smilie keyboard doesn't appear
- Ensure app groups are properly configured
- Check that both the app and keyboard extension have the same app group

#### Login fails
- Verify your Something Awful account is active
- Check network connectivity
- Use a network proxy to inspect the authentication request

### Debug Build Scripts

The project includes several helper scripts in the `Scripts/` directory:

- `Scripts/bump`: Version management
- `Scripts/beta`: Beta build creation
- `Scripts/app-icons`: Icon generation

These are primarily used by the lead maintainer but can be useful for understanding the build process.

## Next Steps

- Review the [Development Environment](./development-environment.md) guide
- Understand the [Project Overview](./project-overview.md)
- Explore the [Architecture Documentation](../02-architecture/)

## Notes for Modernization

As we migrate to iOS 16.1+ and SwiftUI:
- Keep Core Data schema unchanged
- Preserve all existing functionality
- Test thoroughly against production data
- Document any behavioral changes
