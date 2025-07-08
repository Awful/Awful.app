# System Overview

## High-Level Architecture

Awful.app follows a layered architecture with clear separation between presentation, business logic, and data layers.

```
┌─────────────────────────────────────────────────┐
│                 Presentation Layer               │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │
│  │ UIKit Views │  │ SwiftUI     │  │ Theming  │ │
│  │ (Current)   │  │ (Future)    │  │ System   │ │
│  └─────────────┘  └─────────────┘  └──────────┘ │
└─────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────┐
│                Business Logic Layer             │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │
│  │ View        │  │ Forums      │  │ Settings │ │
│  │ Controllers │  │ Client      │  │ Manager  │ │
│  └─────────────┘  └─────────────┘  └──────────┘ │
└─────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────┐
│                   Data Layer                    │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │
│  │ Core Data   │  │ HTML        │  │ Keychain │ │
│  │ Stack       │  │ Scraping    │  │ Storage  │ │
│  └─────────────┘  └─────────────┘  └──────────┘ │
└─────────────────────────────────────────────────┘
```

## Core Components

### 1. App Container
- **Entry Point**: `AppDelegate` and `SceneDelegate`
- **Navigation**: `UINavigationController` hierarchy
- **Lifecycle**: App state management
- **Future**: SwiftUI `App` struct

### 2. View Controllers (UIKit)
- **ForumsTableViewController**: Forum hierarchy navigation
- **ThreadsTableViewController**: Thread listings
- **PostsPageViewController**: Thread viewing with pages
- **MessageViewController**: Private message display
- **Composition Controllers**: Text editing and posting

### 3. AwfulCore Package
- **ForumsClient**: Main API client
- **Scraping Engine**: HTML parsing
- **Core Data Models**: Persistent entities
- **Network Layer**: HTTP requests and responses

### 4. Supporting Packages
- **AwfulExtensions**: Shared utilities
- **AwfulTheming**: Theme system
- **AwfulSettings**: User preferences
- **Smilies**: Keyboard extension

## Data Flow Patterns

### Read Operations
```
View Controller → ForumsClient → Network Request → HTML Response
       ↑                                              ↓
   UI Update ← Core Data Query ← Background Import ← Scraping
```

### Write Operations
```
User Action → View Controller → ForumsClient → POST Request
                                     ↓
                              Success Response
                                     ↓
                              Core Data Update
                                     ↓
                              UI Refresh
```

## Package Dependencies

### External Dependencies
- **Nuke**: Image loading and caching
- **HTMLReader**: HTML parsing (custom fork)
- **Stencil**: Template rendering for posts
- **Lottie**: Animation support
- **FLAnimatedImage**: GIF support

### Internal Package Graph
```
App
├── AwfulCore
│   ├── AwfulExtensions
│   ├── AwfulModelTypes
│   └── AwfulScraping
├── AwfulSettings
│   └── AwfulExtensions
├── AwfulTheming
│   └── LessStylesheet
├── AwfulSettingsUI
│   ├── AwfulSettings
│   └── AwfulExtensions
└── Smilies
    └── AwfulExtensions
```

## Threading Model

### Main Thread
- All UI updates
- View controller lifecycle
- User interaction handling
- Core Data main context

### Background Threads
- Network requests
- HTML parsing
- Core Data imports
- Image processing

### Coordination
- `NSFetchedResultsController` for data binding
- `NotificationCenter` for cross-component communication
- `DispatchQueue` for thread coordination

## Memory Management

### View Controllers
- Weak references to avoid retain cycles
- Proper cleanup in `deinit`
- Core Data context management

### Core Data
- Separate contexts for background/main
- Batch operations for large imports
- Faulting for memory efficiency

### Images
- Nuke for aggressive caching
- Automatic memory pressure handling
- Lazy loading in table views

## Error Handling

### Network Errors
- Retry logic with exponential backoff
- User-friendly error messages
- Offline mode graceful degradation

### Core Data Errors
- Automatic recovery attempts
- Data validation
- Migration error handling

### UI Errors
- Alert presentation
- Progress indicators
- Fallback content

## Security Architecture

### Authentication
- Cookie-based session management
- Keychain storage for credentials
- Automatic session refresh

### Data Protection
- No analytics or tracking
- Local data encryption
- Secure network communication

## Performance Considerations

### Lazy Loading
- Images loaded on demand
- Core Data faulting
- Progressive content loading

### Caching Strategy
- Aggressive local caching
- Image cache management
- HTML response caching

### Memory Optimization
- View controller recycling
- Image decompression
- Background processing

## Future Architecture (SwiftUI)

### Planned Changes
- SwiftUI views replacing UIKit
- Observation framework for state
- NavigationStack for navigation
- Modern concurrency patterns

### Migration Strategy
- Gradual replacement of view controllers
- Hybrid UIKit/SwiftUI during transition
- Preserve Core Data layer
- Maintain API compatibility

### Benefits
- Simplified state management
- Better performance
- More maintainable code
- Native iOS 16+ features

## Architectural Debt

### Current Issues
- Tight coupling between views and data
- Complex view controller hierarchy
- Limited testability
- Objective-C legacy code

### Planned Improvements
- Dependency injection
- Protocol-based abstractions
- Comprehensive testing
- Swift modernization

## Design Patterns Used

### Model-View-Controller (MVC)
- Clear separation of concerns
- View controllers as coordinators
- Models as Core Data entities

### Singleton Pattern
- `ForumsClient.shared`
- `AwfulSettings.shared`
- Theme manager

### Observer Pattern
- `NSFetchedResultsController`
- `NotificationCenter`
- Core Data change notifications

### Factory Pattern
- View controller creation
- Core Data entity creation
- Theme instantiation

## Integration Points

### External Services
- Something Awful Forums (HTML scraping)
- Imgur (image uploads)
- TestFlight (beta distribution)

### iOS System Integration
- Share extensions
- Keyboard extensions
- Background app refresh
- Push notifications (future)

### Third-Party Libraries
- Minimal dependencies
- Swift Package Manager
- Vendor directory for legacy code

## Scalability Considerations

### Data Growth
- Core Data optimizations
- Cleanup strategies
- Storage limits

### User Growth
- Performance monitoring
- Error tracking
- Resource usage

### Feature Growth
- Modular architecture
- Plugin system (future)
- Extension points
