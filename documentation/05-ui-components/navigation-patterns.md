# Navigation Patterns

## Overview

Awful.app implements sophisticated navigation patterns that go beyond standard iOS navigation, including custom gestures, state preservation, and adaptive layouts. These patterns are crucial to the app's user experience and must be carefully preserved during migration.

## Primary Navigation Patterns

### Hierarchical Navigation
- **Forum → Thread → Post**: Core content hierarchy
- **Back Navigation**: Custom back button behavior
- **Breadcrumb Context**: Maintain navigation context
- **Deep Linking**: Support for direct content links
- **State Restoration**: Preserve navigation stack

### Tab-Based Navigation
- **Primary Tabs**: Main app sections
- **Tab State**: Preserve tab-specific state
- **Badge Updates**: Unread count indicators
- **Tab Customization**: User-configurable tabs
- **Context Switching**: Seamless tab transitions

### Modal Navigation
- **Compose Sheets**: Post and message composition
- **Settings Modals**: Configuration interfaces
- **Detail Overlays**: Contextual information display
- **Full-Screen Modals**: Immersive experiences
- **Dismissal Gestures**: Custom dismiss patterns

## Custom Navigation Behaviors

### Swipe Navigation
- **Page Swiping**: Navigate between thread pages
- **Edge Swiping**: Back navigation from screen edges
- **Content Swiping**: Reveal actions on swipe
- **Gesture Coordination**: Multiple gesture handling
- **Velocity Recognition**: Speed-based navigation

### Unpop Navigation
- **Right-Edge Swipe**: Restore previously dismissed views
- **View Stack Management**: Intelligent stack handling
- **State Preservation**: Maintain view state
- **Memory Management**: Efficient view caching
- **Animation Coordination**: Smooth restoration animations

### Contextual Navigation
- **Long Press Menus**: Context-sensitive actions
- **Action Sheets**: Choice presentation
- **Popovers**: iPad-optimized interactions
- **Peek and Pop**: 3D Touch navigation
- **Quick Actions**: Shortcut navigation

## Split View Navigation (iPad)

### Adaptive Layout
- **Master-Detail**: Responsive layout patterns
- **Collapse Behavior**: iPhone adaptation
- **Size Class Handling**: Dynamic layout adjustment
- **Orientation Changes**: Rotation handling
- **External Display**: Multi-screen support

### Sidebar Management
- **Sidebar Toggle**: Show/hide primary content
- **Overlay Mode**: Temporary sidebar display
- **Persistent Mode**: Always-visible sidebar
- **Gesture Control**: Swipe to show/hide
- **State Synchronization**: Consistent state across views

### iOS Bug Workarounds
- **PassthroughViewController**: Container workarounds
- **Layout Fixes**: iOS-specific bug mitigation
- **State Coordination**: Cross-view state management
- **Memory Management**: Efficient view handling
- **Compatibility**: Multi-iOS version support

## State Management

### Navigation State Preservation
- **View Controller State**: Complete state saving
- **Navigation Stack**: Stack restoration
- **Tab State**: Tab-specific state preservation
- **Modal State**: Modal presentation state
- **Gesture State**: In-progress gesture state

### Background Handling
- **State Encoding**: Serialize navigation state
- **State Restoration**: Restore on app launch
- **Deep Link Handling**: Resume from external links
- **Memory Pressure**: Graceful state handling
- **Version Compatibility**: State format evolution

### Cross-Session Persistence
- **User Defaults**: Simple state storage
- **Core Data**: Complex state persistence
- **Keychain**: Secure state storage
- **iCloud**: Cross-device state sync
- **Migration**: State format upgrades

## Gesture Integration

### Navigation Gestures
- **Pan Gestures**: Swipe-based navigation
- **Edge Gestures**: Screen edge interactions
- **Long Press**: Context menu activation
- **Tap Sequences**: Multi-tap navigation
- **Pinch Gestures**: Zoom and scale navigation

### Gesture Coordination
- **Simultaneous Recognition**: Multiple active gestures
- **Gesture Priority**: Conflict resolution
- **State Management**: Gesture state tracking
- **Animation Integration**: Gesture-driven animations
- **Accessibility**: Alternative interaction methods

### Custom Recognizers
- **Thread Navigation**: Page-specific gestures
- **Forum Navigation**: List-specific interactions
- **Compose Gestures**: Editing-specific gestures
- **Search Gestures**: Search-specific interactions
- **Settings Gestures**: Configuration interactions

## Accessibility Navigation

### VoiceOver Integration
- **Navigation Order**: Logical reading sequence
- **Action Descriptions**: Clear action labeling
- **Status Updates**: Navigation change announcements
- **Custom Actions**: Gesture alternatives
- **Focus Management**: Intelligent focus handling

### Alternative Navigation
- **Keyboard Navigation**: Full keyboard support
- **Switch Control**: External switch integration
- **Voice Control**: Voice-based navigation
- **Button Configuration**: Alternative interaction methods
- **Timing Adjustments**: Customizable interaction timing

### Accessibility Enhancements
- **Large Touch Targets**: Accessible button sizing
- **High Contrast**: Enhanced visual navigation
- **Reduced Motion**: Motion-sensitive alternatives
- **Custom Descriptions**: Context-specific labeling
- **Navigation Shortcuts**: Efficient navigation paths

## Performance Optimization

### Navigation Performance
- **Lazy Loading**: Load views on demand
- **Memory Management**: Efficient view lifecycle
- **Animation Performance**: Smooth transitions
- **State Caching**: Intelligent state storage
- **Background Processing**: Off-main-thread work

### Memory Management
- **View Controller Lifecycle**: Proper cleanup
- **Image Management**: Efficient image handling
- **Data Cleanup**: Memory pressure handling
- **Cache Management**: Intelligent caching strategies
- **Weak References**: Prevent retain cycles

### Network Optimization
- **Background Loading**: Preload content
- **Cache Strategy**: Efficient data caching
- **Request Coordination**: Batch network requests
- **Error Handling**: Graceful failure handling
- **Retry Logic**: Smart retry mechanisms

## Migration Considerations

### SwiftUI Navigation
1. **NavigationView**: Replace UINavigationController
2. **NavigationLink**: Replace push segues
3. **Sheet/FullScreenCover**: Replace modal presentation
4. **TabView**: Replace UITabBarController
5. **NavigationStack**: iOS 16+ navigation

### Behavioral Preservation
- **Exact Gesture Behavior**: Maintain custom gestures
- **State Restoration**: Preserve restoration logic
- **Performance Characteristics**: Maintain responsiveness
- **Accessibility Features**: Keep accessibility support
- **Custom Animations**: Preserve transition animations

### Migration Strategy
1. **Phase 1**: Wrap existing navigation in UIViewControllerRepresentable
2. **Phase 2**: Implement SwiftUI equivalents
3. **Phase 3**: Optimize with SwiftUI features
4. **Phase 4**: Remove UIKit dependencies

## Implementation Guidelines

### Navigation Architecture
- **Coordinator Pattern**: Centralized navigation logic
- **Dependency Injection**: Proper navigation dependencies
- **Protocol-Based**: Flexible navigation interfaces
- **State Machines**: Complex navigation state management
- **Error Handling**: Comprehensive error recovery

### Code Organization
- **Navigation Controllers**: Centralized navigation logic
- **Route Definitions**: Type-safe navigation routes
- **State Management**: Consistent state handling
- **Animation Coordination**: Smooth transition management
- **Testing Support**: Testable navigation code

## Testing Considerations

### Navigation Testing
- **Flow Testing**: Complete user journey verification
- **State Testing**: Navigation state validation
- **Gesture Testing**: Custom gesture verification
- **Performance Testing**: Navigation performance measurement
- **Accessibility Testing**: Alternative navigation verification

### Automated Testing
- **UI Testing**: Automated navigation flow testing
- **Unit Testing**: Navigation logic verification
- **Integration Testing**: Cross-component navigation
- **Performance Testing**: Navigation performance benchmarks
- **Regression Testing**: Prevent navigation regressions

## Known Issues and Workarounds

### iOS-Specific Issues
- **Split View Bugs**: iPad split view issues
- **Navigation Bar**: iOS version inconsistencies
- **Modal Presentation**: iOS 13+ modal changes
- **Safe Area**: Safe area handling variations
- **Keyboard Handling**: Keyboard avoidance issues

### Workaround Strategies
- **Version Detection**: iOS version-specific code
- **Feature Detection**: Capability-based implementation
- **Fallback Patterns**: Alternative implementations
- **Bug Reporting**: Track and report iOS bugs
- **Community Solutions**: Leverage community fixes