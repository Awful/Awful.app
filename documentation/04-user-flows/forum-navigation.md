# Forum Navigation Flow

## Overview

The forum navigation system in Awful.app provides hierarchical browsing of Something Awful's forum structure. This flow must maintain the app's unique navigation patterns and state management during the SwiftUI migration.

## Navigation Hierarchy

```
Forums Root
├── Forum Categories
│   ├── Individual Forums
│   │   ├── Thread Lists
│   │   │   └── Thread Detail
│   │   └── Subforums (if applicable)
│   └── Bookmarked Threads
└── Private Messages
```

## Core Components

### ForumsTableViewController
- **Purpose**: Displays the main forum hierarchy
- **Key Features**:
  - Hierarchical forum structure
  - Forum icons and descriptions
  - Last post indicators
  - Favorite forums section
  - Search functionality

### ThreadsTableViewController
- **Purpose**: Shows threads within a specific forum
- **Key Features**:
  - Thread titles and metadata
  - Author information
  - Post count and last post time
  - Read/unread indicators
  - Sticky thread handling
  - Pull-to-refresh functionality

## Navigation Patterns

### Primary Navigation
1. **Forum Selection**: User taps on a forum from the hierarchy
2. **Thread Loading**: App fetches thread list from selected forum
3. **Thread Selection**: User taps on a thread to view posts
4. **Back Navigation**: Standard iOS back button behavior

### Secondary Navigation
- **Search**: Global search across forums and threads
- **Bookmarks**: Quick access to bookmarked threads
- **Recently Viewed**: History of visited forums and threads
- **Favorites**: User-curated list of frequently accessed forums

## State Management

### Forum State
- Current forum selection
- Thread list cache
- Read/unread status
- Last refresh timestamp
- Scroll position preservation

### Navigation State
- Navigation stack depth
- Previous forum context
- Search query state
- Filter preferences

## Custom Behaviors

### Forum-Specific Features
- **Forum Icons**: Custom icons for each forum
- **Theme Integration**: Forum-specific color schemes
- **Moderator Indicators**: Special badges for moderated content
- **Star/Bookmark System**: User-managed favorites

### Performance Optimizations
- **Lazy Loading**: Threads loaded on demand
- **Background Refresh**: Periodic content updates
- **Cache Management**: Intelligent data caching
- **Memory Management**: Efficient view controller lifecycle

## User Experience Patterns

### Visual Indicators
- **Unread Badges**: New content indicators
- **Activity Indicators**: Loading states
- **Error States**: Network and data error handling
- **Empty States**: No content messaging

### Interaction Patterns
- **Pull to Refresh**: Manual content updates
- **Swipe Actions**: Quick access to common operations
- **Long Press**: Context menus for advanced options
- **Search Integration**: Inline search functionality

## Migration Considerations

### SwiftUI Conversion
1. **NavigationView/NavigationStack**: Replace UINavigationController
2. **List/LazyVStack**: Replace UITableView
3. **@StateObject/@ObservableObject**: Replace delegation patterns
4. **@Environment**: Replace shared state management

### Behavioral Preservation
- Maintain exact navigation timing
- Preserve state across app launches
- Keep performance characteristics
- Maintain accessibility support

## Implementation Notes

### Key Files
- `ForumsTableViewController.swift`
- `ThreadsTableViewController.swift`
- `ForumsClient.swift` (data fetching)
- `Forum.swift` (Core Data model)

### Dependencies
- Core Data for persistence
- Forums Client for network requests
- Theming system for visual consistency
- Settings system for user preferences

## Testing Scenarios

### Basic Navigation
1. Launch app and navigate to forum
2. Select thread and verify loading
3. Navigate back to forum list
4. Verify state preservation

### Edge Cases
- Network connectivity issues
- Empty forum handling
- Large thread lists
- Memory pressure scenarios

### Performance Testing
- Navigation timing
- Memory usage patterns
- Cache effectiveness
- Background refresh behavior