# View Controllers

## Overview

Awful.app's view controllers form the backbone of the user interface, implementing complex navigation patterns and custom behaviors that must be preserved during the SwiftUI migration. Each controller has specific responsibilities and unique features.

## Primary View Controllers

### ForumsTableViewController
- **File**: `App/View Controllers/ForumsTableViewController.swift`
- **Purpose**: Displays the forum hierarchy and navigation
- **Key Features**:
  - Hierarchical forum structure display
  - Bookmarked forums section
  - Forum search functionality
  - Real-time forum statistics
  - Custom cell layouts with forum icons

**Custom Behaviors**:
- Forum-specific theme application
- Lazy loading of forum data
- Pull-to-refresh with custom animations
- Bookmark management
- Search integration

### ThreadsTableViewController
- **File**: `App/View Controllers/ThreadsTableViewController.swift`
- **Purpose**: Lists threads within a selected forum
- **Key Features**:
  - Thread metadata display (title, author, post count)
  - Read/unread status indicators
  - Sticky thread handling
  - Thread filtering and sorting
  - Infinite scroll loading

**Custom Behaviors**:
- Swipe actions for thread management
- Long press context menus
- Thread bookmark toggling
- Author avatar display
- Custom cell animations

### PostsPageViewController
- **File**: `App/View Controllers/PostsPageViewController.swift`
- **Purpose**: Core thread reading interface
- **Key Features**:
  - WebKit-based post rendering
  - Page-based navigation (40 posts per page)
  - Quote and reply functionality
  - Reading position tracking
  - Gesture-based page switching

**Custom Behaviors**:
- Horizontal swipe navigation between pages
- Pull-to-refresh for thread updates
- Custom toolbar with page controls
- Reading position preservation
- Theme-aware web content

### MessageViewController
- **File**: `App/View Controllers/MessageViewController.swift`
- **Purpose**: Private message display and management
- **Key Features**:
  - HTML message rendering
  - Reply and forward functionality
  - Attachment handling
  - Message thread navigation
  - Contact integration

**Custom Behaviors**:
- Unified message thread display
- Custom message composition
- Contact card integration
- Message search functionality
- Privacy controls

## Composition Controllers

### ComposeTextViewController
- **File**: `App/View Controllers/ComposeTextViewController.swift`
- **Purpose**: Text composition for posts and replies
- **Key Features**:
  - Rich text editing with BBCode support
  - Live preview functionality
  - Draft saving and restoration
  - Smilie integration
  - Image upload handling

**Custom Behaviors**:
- Real-time formatting preview
- Auto-save draft functionality
- Smilie keyboard integration
- Image embed handling
- Quote integration

### MessageComposeViewController
- **File**: `App/View Controllers/MessageComposeViewController.swift`
- **Purpose**: Private message composition
- **Key Features**:
  - Recipient selection
  - Subject line editing
  - Rich text message body
  - Attachment support
  - Send confirmation

**Custom Behaviors**:
- Contact auto-completion
- Draft management
- Send validation
- Error handling
- Privacy controls

## Navigation Controllers

### AwfulNavigationController
- **File**: `App/View Controllers/AwfulNavigationController.swift`
- **Purpose**: Custom navigation with theme support
- **Key Features**:
  - Dynamic theme integration
  - Custom navigation bar styling
  - State restoration support
  - Gesture coordination
  - Toolbar customization

**Custom Behaviors**:
- Theme-aware navigation styling
- Custom transition animations
- Right-edge swipe handling
- Toolbar visibility management
- Split view coordination

### AwfulSplitViewController
- **File**: `App/View Controllers/AwfulSplitViewController.swift`
- **Purpose**: iPad split view with custom behaviors
- **Key Features**:
  - Responsive layout handling
  - Custom sidebar behavior
  - State preservation
  - Orientation handling
  - iOS bug workarounds

**Custom Behaviors**:
- Custom collapse/expand behavior
- Sidebar gesture handling
- State restoration
- Orientation lock handling
- iOS 13+ compatibility

## Supporting Controllers

### SettingsViewController
- **File**: `App/View Controllers/SettingsViewController.swift`
- **Purpose**: App settings and preferences
- **Key Features**:
  - Hierarchical settings display
  - Real-time preference updates
  - Theme selection
  - Account management
  - Debug options

### UserProfileViewController
- **File**: `App/View Controllers/UserProfileViewController.swift`
- **Purpose**: User profile display and interaction
- **Key Features**:
  - User information display
  - Post history browsing
  - Contact management
  - Social features
  - Privacy controls

### SearchViewController
- **File**: `App/View Controllers/SearchViewController.swift`
- **Purpose**: Global search functionality
- **Key Features**:
  - Multi-scope search
  - Result categorization
  - Search history
  - Filter options
  - Real-time suggestions

## State Management

### View Controller State
- **State Restoration**: All controllers support iOS state restoration
- **Background Handling**: Proper state handling during backgrounding
- **Memory Management**: Efficient memory usage and cleanup
- **Data Coordination**: Core Data integration and observation

### Navigation State
- **Navigation Stack**: Proper back navigation handling
- **Modal Presentation**: Sheet and popover management
- **Tab Coordination**: Tab bar state synchronization
- **Split View State**: Master/detail coordination

## Accessibility Integration

### VoiceOver Support
- **Navigation**: Logical reading order for all controllers
- **Actions**: Accessible action descriptions
- **Content**: Proper content labeling
- **Status**: State change announcements

### Dynamic Type
- **Font Scaling**: Respect system font sizing
- **Layout Adaptation**: UI adjustment for larger fonts
- **Content Scaling**: Proportional content sizing
- **Button Sizing**: Accessible touch targets

## Migration Strategy

### SwiftUI Conversion Approach
1. **Phase 1**: Wrap in UIViewControllerRepresentable
2. **Phase 2**: Create SwiftUI equivalents
3. **Phase 3**: Enhance with SwiftUI features
4. **Phase 4**: Remove UIKit dependencies

### Critical Behaviors to Preserve
- Exact navigation patterns and gestures
- State restoration and persistence
- Theme integration and real-time updates
- Performance characteristics
- Accessibility features

## Performance Considerations

### Memory Management
- **View Controller Lifecycle**: Proper viewDidLoad/viewWillAppear handling
- **Data Loading**: Efficient data fetching and caching
- **Image Handling**: Lazy image loading and memory management
- **Background Processing**: Efficient background task handling

### Rendering Performance
- **Cell Reuse**: Efficient table view cell reuse
- **Layout Optimization**: Auto Layout performance
- **Animation Performance**: Smooth transitions and animations
- **WebView Performance**: Efficient web content rendering

## Testing Considerations

### Unit Testing
- **Controller Logic**: Business logic testing
- **State Management**: State transition testing
- **Data Integration**: Core Data interaction testing
- **Navigation**: Navigation flow testing

### UI Testing
- **User Flows**: Complete user journey testing
- **Gesture Recognition**: Custom gesture testing
- **Accessibility**: VoiceOver and accessibility testing
- **Performance**: Memory and rendering performance testing

## Migration Risks

### High-Risk Areas
- **Custom Navigation**: Complex navigation patterns
- **WebView Integration**: Post rendering complexity
- **Gesture Systems**: Custom gesture recognizers
- **State Restoration**: iOS state restoration system

### Mitigation Strategies
- **Progressive Migration**: Migrate one controller at a time
- **Behavior Testing**: Extensive testing of migrated behavior
- **Rollback Planning**: Ability to revert problematic migrations
- **Performance Monitoring**: Continuous performance measurement

## Implementation Guidelines

### Code Organization
- **Single Responsibility**: Each controller has clear purpose
- **Dependency Injection**: Proper dependency management
- **Protocol Conformance**: Consistent protocol adoption
- **Error Handling**: Comprehensive error management

### Documentation Requirements
- **Behavior Documentation**: Document all custom behaviors
- **Migration Notes**: Track migration status and issues
- **Testing Guidelines**: Maintain testing standards
- **Performance Baselines**: Establish performance benchmarks