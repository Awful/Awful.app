# Keyboard Shortcuts Reference

Comprehensive reference for keyboard shortcuts and productivity commands for developing with Awful.app.

## Table of Contents

- [Xcode Shortcuts](#xcode-shortcuts)
- [Simulator Shortcuts](#simulator-shortcuts)
- [Terminal Commands](#terminal-commands)
- [Git Commands](#git-commands)
- [Development Workflow](#development-workflow)
- [Debugging Shortcuts](#debugging-shortcuts)
- [Testing Shortcuts](#testing-shortcuts)
- [Navigation Shortcuts](#navigation-shortcuts)

## Xcode Shortcuts

### Build and Run

| Shortcut | Action | Description |
|----------|---------|-------------|
| `⌘R` | Run | Build and run the current scheme |
| `⌘B` | Build | Build the current scheme without running |
| `⌘⇧B` | Analyze | Perform static analysis |
| `⌘⇧K` | Clean Build Folder | Clean all build products |
| `⌘⇧⌥K` | Clean Build Folder (Complete) | Deep clean including derived data |
| `⌘U` | Test | Run unit tests for current scheme |
| `⌘⌃U` | Test Again | Re-run the last test |
| `⌘⇧U` | Test All | Run all tests in the test plan |
| `⌘I` | Profile | Build and run with Instruments |
| `⌘⇧I` | Profile Without Building | Run last build with Instruments |

### Navigation

| Shortcut | Action | Description |
|----------|---------|-------------|
| `⌘⇧O` | Open Quickly | Quick file/symbol search |
| `⌘⌃↑` | Toggle Header/Implementation | Switch between .h and .m files |
| `⌘⌃J` | Jump to Definition | Navigate to symbol definition |
| `⌘⌥⌃J` | Jump to Declaration | Navigate to symbol declaration |
| `⌘⌃←` | Go Back | Navigate backward in history |
| `⌘⌃→` | Go Forward | Navigate forward in history |
| `⌘⇧J` | Reveal in Navigator | Show current file in navigator |
| `⌘1-9` | Show Navigator Tab | Switch between navigator panels |
| `⌘⌥1-9` | Show Inspector Tab | Switch between inspector panels |

### File Management

| Shortcut | Action | Description |
|----------|---------|-------------|
| `⌘N` | New File | Create new file in project |
| `⌘⌥N` | New Group | Create new group in navigator |
| `⌘⇧N` | New Project | Create new Xcode project |
| `⌘O` | Open | Open existing project/file |
| `⌘S` | Save | Save current file |
| `⌘⌥S` | Save All | Save all modified files |
| `⌘W` | Close Tab | Close current editor tab |
| `⌘⇧W` | Close Window | Close current window |

### Code Editing

| Shortcut | Action | Description |
|----------|---------|-------------|
| `⌘F` | Find | Find in current file |
| `⌘G` | Find Next | Find next occurrence |
| `⌘⇧G` | Find Previous | Find previous occurrence |
| `⌘⌥F` | Find and Replace | Find and replace in current file |
| `⌘⇧F` | Find in Project | Find in entire project |
| `⌘⌥⇧F` | Find and Replace in Project | Find and replace in project |
| `⌘D` | Duplicate Line | Duplicate current line |
| `⌘⌫` | Delete Line | Delete current line |
| `⌘/` | Toggle Comment | Comment/uncomment current line |
| `⌘⌥/` | Toggle Block Comment | Toggle block comment |
| `⌘⌃E` | Edit All in Scope | Edit all occurrences of symbol |

### Code Completion and Refactoring

| Shortcut | Action | Description |
|----------|---------|-------------|
| `⌃Space` | Show Completions | Show code completion suggestions |
| `⌘⌃E` | Rename | Rename symbol across project |
| `⌘⌃M` | Extract Method | Extract selected code to method |
| `⌘⌃X` | Extract Variable | Extract expression to variable |
| `⌘⌃P` | Extract Parameter | Extract value to parameter |
| `⌘⌃⇧M` | Encapsulate Field | Create getter/setter for property |

### Debugging

| Shortcut | Action | Description |
|----------|---------|-------------|
| `F6` | Step Over | Execute next line (step over calls) |
| `F7` | Step Into | Step into function calls |
| `F8` | Step Out | Step out of current function |
| `⌘⌃Y` | Continue | Resume execution |
| `⌘Y` | Activate/Deactivate Breakpoints | Toggle all breakpoints |
| `⌘\` | Toggle Breakpoint | Toggle breakpoint on current line |
| `⌘⌥\` | Edit Breakpoint | Edit breakpoint conditions |
| `⌘⇧\` | Create Symbolic Breakpoint | Create breakpoint by symbol name |

### Documentation and Help

| Shortcut | Action | Description |
|----------|---------|-------------|
| `⌥Click` | Quick Help | Show quick help for symbol |
| `⌘⌃?` | Quick Help Inspector | Toggle quick help inspector |
| `⌘⇧0` | Documentation Window | Open documentation browser |
| `⌘⌥⇧/` | Documentation Comment | Add documentation comment |

### Interface Builder

| Shortcut | Action | Description |
|----------|---------|-------------|
| `⌘=` | Size to Fit Content | Resize view to fit content |
| `⌘⌥=` | Update Frames | Update view frames to match constraints |
| `⌘⌥⇧=` | Update Constraints | Update constraints to match frames |
| `⌘⌃=` | Resolve Auto Layout Issues | Fix Auto Layout problems |

## Simulator Shortcuts

### Device Control

| Shortcut | Action | Description |
|----------|---------|-------------|
| `⌘⇧H` | Home | Press home button |
| `⌘⇧H⇧H` | App Switcher | Show multitasking interface |
| `⌘L` | Lock Screen | Lock/unlock device |
| `⌘⇧A` | Siri | Activate Siri |
| `⌘K` | Connect Hardware Keyboard | Toggle hardware keyboard |
| `⌘⇧K` | Toggle Software Keyboard | Show/hide software keyboard |

### Simulation

| Shortcut | Action | Description |
|----------|---------|-------------|
| `⌘1` | 100% Scale | Set simulator to actual size |
| `⌘2` | 75% Scale | Scale simulator to 75% |
| `⌘3` | 50% Scale | Scale simulator to 50% |
| `⌘4` | 33% Scale | Scale simulator to 33% |
| `⌘5` | 25% Scale | Scale simulator to 25% |
| `⌘←` | Rotate Left | Rotate device counterclockwise |
| `⌘→` | Rotate Right | Rotate device clockwise |
| `⌘⇧S` | Screenshot | Take screenshot and save to desktop |

### Testing and Debugging

| Shortcut | Action | Description |
|----------|---------|-------------|
| `⌘⇧M` | Memory Warning | Simulate memory warning |
| `⌘⇧Z` | Shake Gesture | Simulate shake gesture |
| `⌘⇧⌥S` | Slow Animations | Toggle slow animation mode |
| `⌘T` | Touch Bar | Show Touch Bar (if available) |

## Terminal Commands

### Project Navigation

```bash
# Navigate to project directory
cd ~/Developer/Awful.app

# Open project in Xcode
open Awful.xcodeproj
# or
xed .

# Open specific file
open App/View\ Controllers/Posts/PostsPageViewController.swift

# Find files by name
find . -name "*.swift" -type f | grep -i "forums"

# Search for code patterns
grep -r "ForumsClient" --include="*.swift" .

# Count lines of code
find . -name "*.swift" -type f -exec wc -l {} + | sort -n
```

### Build Commands

```bash
# Build project
xcodebuild -scheme Awful -configuration Debug build

# Clean build
xcodebuild -scheme Awful clean

# Run tests
xcodebuild test -scheme Awful -destination 'platform=iOS Simulator,name=iPhone 15'

# Archive for distribution
xcodebuild -scheme Awful -configuration Release archive -archivePath build/Awful.xcarchive

# List available schemes
xcodebuild -list

# List available simulators
xcrun simctl list devices

# Reset simulator
xcrun simctl erase all
```

### Swift Package Manager

```bash
# Update package dependencies
xcodebuild -resolvePackageDependencies

# Reset package cache
rm -rf .swiftpm/xcode/package.xcworkspace

# Build specific package
swift build --package-path AwfulCore

# Test specific package
swift test --package-path AwfulCore

# Generate documentation
swift package --package-path AwfulCore generate-documentation
```

### Version Management

```bash
# Bump version numbers
Scripts/bump --build        # Increment build number
Scripts/bump --minor        # Increment minor version
Scripts/bump --major        # Increment major version

# Create beta build
Scripts/beta

# Create and upload beta
Scripts/beta --upload

# Update app icons
Scripts/app-icons

# Submit to App Store
Scripts/submit
```

## Git Commands

### Basic Workflow

```bash
# Check status
git status

# Stage changes
git add .
git add App/View\ Controllers/Posts/PostsPageViewController.swift

# Commit changes
git commit -m "Add support for forum search functionality"

# Push to remote
git push origin feature/search-implementation

# Pull latest changes
git pull origin main

# Create and switch to new branch
git checkout -b feature/new-feature

# Switch branches
git checkout main
git switch develop
```

### Advanced Git Operations

```bash
# Interactive rebase
git rebase -i HEAD~3

# Squash commits
git reset --soft HEAD~3
git commit -m "Combined commit message"

# Stash changes
git stash
git stash pop
git stash list
git stash apply stash@{0}

# View commit history
git log --oneline --graph
git log --grep="search"
git log --since="1 week ago"

# Show file changes
git diff
git diff --staged
git diff HEAD~1 App/

# Blame/annotate
git blame App/View\ Controllers/Posts/PostsPageViewController.swift
git annotate App/Main/AppDelegate.swift
```

### Branch Management

```bash
# List branches
git branch -a
git branch -r

# Delete branch
git branch -d feature/old-feature
git push origin --delete feature/old-feature

# Merge branch
git checkout main
git merge feature/new-feature

# Cherry-pick commit
git cherry-pick abc123

# View merge conflicts
git status
git diff --name-only --diff-filter=U
```

## Development Workflow

### Daily Development

```bash
# Start development session
cd ~/Developer/Awful.app
git status
git pull origin main
xed .

# Quick build and test cycle
⌘R                          # Build and run
⌘U                          # Run tests
⌘⇧K                         # Clean if needed

# Code navigation
⌘⇧O                         # Quick open file
⌘⌃J                         # Jump to definition
⌘⌃←                         # Go back

# End development session
⌘S                          # Save all
git add .
git commit -m "Descriptive commit message"
git push origin branch-name
```

### Feature Development

```bash
# Create feature branch
git checkout -b feature/forum-search
git push -u origin feature/forum-search

# Development cycle
# 1. Code changes
# 2. Build and test (⌘B, ⌘U)
# 3. Commit changes
git add .
git commit -m "Implement search API integration"

# 4. Regular pushes
git push origin feature/forum-search

# 5. Create pull request
# Use GitHub web interface or:
gh pr create --title "Add forum search functionality" --body "Implementation details..."
```

### Release Process

```bash
# Prepare release
git checkout main
git pull origin main
Scripts/bump --minor
git add .
git commit -m "Bump version to 7.10"
git tag v7.10.0
git push origin main --tags

# Create release build
Scripts/beta --upload

# Deploy to App Store
# Use App Store Connect or:
Scripts/submit
```

## Debugging Shortcuts

### LLDB Commands

```bash
# Print variables
po variable_name
p variable_name
expression variable_name

# Print object description
po self
po thread
po error

# Print view hierarchy
po [[[UIApplication sharedApplication] keyWindow] recursiveDescription]
po view.recursiveDescription

# Set breakpoint
breakpoint set --name viewDidLoad
breakpoint set --file PostsPageViewController.swift --line 42
br s -n "-[NSArray objectAtIndex:]"

# List breakpoints
breakpoint list
br list

# Delete breakpoints
breakpoint delete 1
br del 1

# Continue execution
continue
c

# Step commands
step       # Step into
next       # Step over
finish     # Step out
```

### View Debugging

```bash
# Capture view hierarchy
Xcode: Debug > View Debugging > Capture View Hierarchy

# LLDB view debugging
po [[UIWindow keyWindow] recursiveDescription]
po [view recursiveDescription]

# Find views by class
po [[[UIApplication sharedApplication] keyWindow] subviewsWithClassName:@"UILabel"]

# View frame information
po view.frame
po view.bounds
po view.center
```

### Memory Debugging

```bash
# Enable malloc stack logging
export MallocStackLogging=1

# Memory graph debugging
Xcode: Debug > Memory Graph Hierarchy

# Instruments shortcuts
⌘I                          # Profile with Instruments
# Then select appropriate template:
# - Leaks
# - Allocations
# - Time Profiler
```

## Testing Shortcuts

### Unit Testing

```bash
# Run all tests
⌘U

# Run tests for current file
⌘⌃⌥U

# Run specific test method
# Click diamond in gutter next to test method

# Run tests with coverage
xcodebuild test -scheme Awful -enableCodeCoverage YES

# Test specific class
xcodebuild test -scheme Awful -only-testing:AwfulTests/ForumsClientTests

# Test specific method
xcodebuild test -scheme Awful -only-testing:AwfulTests/ForumsClientTests/testLoginWithValidCredentials
```

### UI Testing

```bash
# Record UI test
# In UI test method, click record button in Xcode

# Run UI tests
xcodebuild test -scheme Awful -only-testing:AwfulUITests

# Debug UI test
# Set breakpoint in UI test
# Use accessor inspector in Xcode
```

### Test Data Management

```bash
# Reset simulator data
xcrun simctl erase all

# Install app on simulator
xcrun simctl install booted path/to/Awful.app

# Launch app on simulator
xcrun simctl launch booted com.awfulapp.Awful

# Take simulator screenshot
xcrun simctl io booted screenshot screenshot.png
```

## Navigation Shortcuts

### Project Navigation

| Context | Shortcut | Action |
|---------|----------|---------|
| Any | `⌘⇧O` | Quick open file/symbol |
| Any | `⌘⇧J` | Reveal in navigator |
| Navigator | `⌘1` | Project navigator |
| Navigator | `⌘2` | Source control navigator |
| Navigator | `⌘3` | Symbol navigator |
| Navigator | `⌘4` | Find navigator |
| Navigator | `⌘5` | Issue navigator |
| Navigator | `⌘6` | Test navigator |
| Navigator | `⌘7` | Debug navigator |
| Navigator | `⌘8` | Breakpoint navigator |
| Navigator | `⌘9` | Report navigator |

### Code Navigation

| Context | Shortcut | Action |
|---------|----------|---------|
| Editor | `⌘⌃J` | Jump to definition |
| Editor | `⌘⌃⇧J` | Jump to declaration |
| Editor | `⌘⌃←` | Go back |
| Editor | `⌘⌃→` | Go forward |
| Editor | `⌘L` | Go to line |
| Editor | `⌘⇧T` | Go to symbol |
| Editor | `⌘F` | Find in file |
| Editor | `⌘G` | Find next |
| Editor | `⌘⇧G` | Find previous |

### Multi-File Navigation

```bash
# Quick file switching
⌘⌃↑                         # Switch between header/implementation
⌘⌃←/→                       # Navigate history
⌘⇧O                         # Quick open

# Tab management
⌘T                          # New tab
⌘W                          # Close tab
⌘⇧}                         # Next tab
⌘⇧{                         # Previous tab
⌘1-9                        # Switch to tab by number
```

This comprehensive keyboard shortcuts reference helps developers work more efficiently with the Awful.app codebase by providing quick access to common development tasks and workflows.