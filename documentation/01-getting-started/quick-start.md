# Quick Start Guide

## Build and Run in 5 Minutes

This guide gets you running Awful.app as quickly as possible.

## Prerequisites

- Xcode 16+ installed
- Git installed
- 5GB free disk space

## Steps

### 1. Clone and Open

```bash
# Clone the repository
git clone https://github.com/AwfulDevs/Awful.app.git
cd Awful.app

# Copy sample configuration
cp Local.sample.xcconfig Local.xcconfig

# Open in Xcode
open Awful.xcodeproj
```

### 2. Configure Team (Required for Device Builds)

In Xcode:
1. Select the project in navigator
2. Select "Awful" target
3. Go to "Signing & Capabilities"
4. Select your team from dropdown

### 3. Build and Run

1. Select "Awful" scheme (top toolbar)
2. Select a simulator (iPhone 15 Pro recommended)
3. Press ⌘R or click the play button

## First Launch

### What You'll See

1. **Launch Screen**: Shows while app loads
2. **Login Prompt**: Requires Something Awful account
3. **Forums List**: After login, shows forum categories

### Quick Test Without Login

To explore the UI without a forums account:

1. Cancel the login prompt
2. Some features will be limited
3. You can browse the UI structure

## Common Quick Start Issues

### "No account for team"

Edit `Local.xcconfig`:
```
DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

Find your Team ID in Xcode → Settings → Accounts

### Build Fails on First Run

1. Let Xcode finish indexing (progress bar in top toolbar)
2. File → Packages → Resolve Package Versions
3. Clean and rebuild: ⇧⌘K then ⌘B

### App Crashes on Launch

1. Check the console output
2. Usually a configuration issue
3. Verify all SPM packages resolved

## Quick Feature Tour

### After Successful Login

1. **Forums List**
   - Tap any forum to see threads
   - Pull to refresh
   - Long press for options

2. **Thread View**
   - Swipe between pages
   - Tap posts for actions
   - Use bottom toolbar

3. **Themes**
   - Settings → Themes
   - Try YOSPOS or FYAD themes
   - Dark mode support

4. **Smilie Keyboard**
   - In any text field
   - Tap globe icon
   - Select Awful Smilies

## Development Workflow

### Making Changes

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature
   ```

2. Make your changes

3. Test thoroughly:
   - Different screen sizes
   - Light/dark modes
   - Logged in/out states

4. Commit with clear messages:
   ```bash
   git add .
   git commit -m "Add feature: description"
   ```

### Running Tests

Using Xcode:
1. Press ⌘U to run all tests
2. Or use Test navigator (⌘+6)

Using XcodeBuildMCP:
```bash
# Run all tests
mcp__XcodeBuildMCP__test_macos_proj projectPath:Awful.xcodeproj scheme:Awful
```

## Quick Debugging Tips

### View Hierarchy
- Debug → View Debugging → Capture View Hierarchy
- Inspect UI layout issues

### Network Traffic
- Use Xcode's network instrument
- Or set up Charles Proxy

### Core Data
- Open `.sqlite` file in DB browser
- Located in app's documents directory

## Next Steps

### For UI Development
1. Review [UI Components](../05-ui-components/)
2. Understand [Theming System](../07-theming/)
3. Learn [User Flows](../04-user-flows/)

### For Core Development
1. Study [Architecture](../02-architecture/)
2. Understand [Core Systems](../03-core-systems/)
3. Review [Data Layer](../06-data-layer/)

### For Modernization
1. Read [Migration Guides](../09-migration-guides/)
2. Review [Legacy Code](../10-legacy-code/)
3. Plan SwiftUI conversions

## Useful Commands

```bash
# Update version
Scripts/bump --build

# Create beta build
Scripts/beta

# Update app icons
Scripts/app-icons

# Clean everything
git clean -xfd
```

## Getting Help

1. Check [Troubleshooting](../13-troubleshooting/)
2. Review existing GitHub issues
3. Ask in the development thread on Something Awful
4. Contact maintainers through GitHub

## Important Notes

- This is a community project maintained by volunteers
- Always test changes thoroughly
- Preserve existing functionality
