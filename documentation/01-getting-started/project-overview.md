# Project Overview

## What is Awful.app?

Awful.app is a native iOS client for the Something Awful Forums, continuously developed and maintained by community volunteers for nearly 20 years. It provides a tailored mobile experience for browsing forums, reading threads, posting messages, and interacting with the SA community.

## Key Features

### Core Functionality
- **Forum Browsing**: Hierarchical forum navigation
- **Thread Reading**: Paginated thread viewing with gesture support  
- **Posting**: Reply to threads, create new threads, quote posts
- **Private Messages**: Send and receive PMs
- **User Profiles**: View user details, post history, rap sheets
- **Bookmarks**: Save and sync thread positions

### Unique Features
- **Custom Themes**: Forum-specific themes (FYAD, YOSPOS, etc.)
- **Smilie Keyboard**: Custom keyboard extension for forum smilies
- **Gesture Navigation**: Swipe between pages, pull to refresh
- **Smart Scrolling**: Remember position, jump to last read
- **Rap Sheets**: View user probations/bans
- **Post Filtering**: Ignore users, filter by keywords

## Technical Architecture

### Technology Stack
- **Language**: Swift (90%) and Objective-C (10% legacy)
- **UI Framework**: UIKit (migrating to SwiftUI)
- **Data Persistence**: Core Data
- **Networking**: URLSession with HTML scraping
- **Dependency Management**: Swift Package Manager
- **Minimum iOS**: 15.0 (moving to 16.1)

### Project Structure

```
Awful.app/
├── App/                    # Main iOS application
│   ├── View Controllers/   # UIKit view controllers
│   ├── Views/             # Custom UI components
│   ├── Composition/       # Text editing components
│   ├── Main/              # App delegate, scene delegate
│   └── Resources/         # Assets, templates, plists
├── AwfulCore/             # Networking and data layer
├── AwfulExtensions/       # Shared Swift/UIKit extensions
├── AwfulTheming/          # Theme system
├── AwfulSettings/         # Settings management
├── Smilies/               # Smilie keyboard package
├── Vendor/                # Third-party dependencies
└── Scripts/               # Build and utility scripts
```

## Core Components

### 1. AwfulCore Package
The heart of the app's data layer:
- **ForumsClient**: Main API client for forum interactions
- **Scraping**: HTML parsing to extract forum data
- **Models**: Core Data entities (Forum, Thread, Post, User)
- **Persistence**: Core Data stack management

### 2. View Layer
Currently UIKit-based with planned SwiftUI migration:
- **PostsPageViewController**: Thread viewing with WebKit
- **ThreadsTableViewController**: Thread listings
- **ForumsTableViewController**: Forum hierarchy
- **MessageViewController**: Private messages

### 3. Theming System
Sophisticated theming with:
- **Themes.plist**: Theme definitions
- **Forum-specific CSS**: Custom styles per forum
- **Dark mode support**: Automatic theme switching
- **Less compilation**: Dynamic stylesheet generation

### 4. Settings System
User preferences with:
- **FOIL package**: Type-safe UserDefaults wrapper
- **Migration system**: Upgrade old preferences
- **Settings UI**: Comprehensive preferences interface

## Data Flow

```
User Action → View Controller → ForumsClient
                                      ↓
                                 HTML Response
                                      ↓
                                HTML Scraping
                                      ↓
                                Core Data Import
                                      ↓
UI Update ← NSFetchedResultsController
```

## Authentication

The app uses cookie-based authentication:
1. User logs in with SA credentials
2. App captures authentication cookie
3. Cookie persists in keychain
4. All requests include cookie
5. Logout clears cookie

## Key Design Decisions

### Why HTML Scraping?
- Something Awful has no official API
- HTML structure has been relatively stable
- HTMLReader (by the app's creator) handles parsing

### Why Core Data?
- Offline browsing support
- Efficient memory usage for large threads
- Sync between devices (future feature)
- Complex relational data model

### Why Custom Themes?
- Forums culture includes unique aesthetics
- Users expect forum-specific experiences
- Preserves desktop forum feel

## Development Philosophy

### Principles
1. **No Feature Regression**: Never remove functionality
2. **Preserve Forum Culture**: Respect SA traditions
3. **Performance Matters**: Smooth scrolling, fast loading
4. **Offline Support**: Cache aggressively
5. **User Privacy**: No analytics, minimal data collection

### Modernization Goals
1. **SwiftUI Migration**: Modern UI framework
2. **iOS 16.1+ Target**: Latest platform features
3. **Async/Await**: Modern concurrency
4. **Improved Testing**: Better coverage
5. **Documentation**: Comprehensive guides

### Contribution Process
1. Fork the repository
2. Create feature branch
3. Submit pull request
4. Maintainer review
5. App Store release by lead maintainer

## Current Challenges

### Technical Debt
- **Legacy Objective-C**: ~10% of codebase
- **UIKit Dependencies**: Tightly coupled views
- **HTML Parsing Fragility**: Site changes break scraping
- **Complex State Management**: View controller coordination

### Modernization Challenges
- **SwiftUI Compatibility**: Preserving custom behaviors
- **Data Migration**: Core Data schema stability
- **Theme System**: CSS to SwiftUI styling
- **Testing Coverage**: Limited automated tests

## Future Vision

### Short Term (Current Focus)
- Migrate to iOS 16.1 minimum
- Begin SwiftUI view replacements
- Improve documentation
- Enhance error handling

### Medium Term
- Complete SwiftUI migration
- Modern navigation (NavigationStack)
- Improved testing suite
- Performance optimizations

### Long Term
- Multi-platform support (iPad optimization)
- Sync between devices
- Enhanced offline support
- Accessibility improvements

## Getting Involved

### How to Help
1. **Report Bugs**: Use GitHub issues
2. **Submit PRs**: Follow contribution guidelines
3. **Test Beta Builds**: Join TestFlight
4. **Document Features**: Improve guides
5. **Modernize Code**: Help with SwiftUI migration

### Resources

- [Contributing Guide](../../CONTRIBUTING.md)
- [Architecture Docs](../02-architecture/)

## Summary

Awful.app is a mature, community-driven iOS application with a rich history and active user base. While it faces modernization challenges, its comprehensive feature set and dedicated community ensure its continued development. The current focus on SwiftUI migration and iOS 16.1+ support will position the app for the future while preserving its unique character and functionality.
