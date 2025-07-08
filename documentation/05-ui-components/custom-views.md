# Custom Views

## Overview

Awful.app includes numerous custom UIView subclasses that provide specialized functionality beyond standard UIKit components. These views implement unique behaviors and visual styles that are integral to the app's user experience.

## Core Custom Views

### RenderView
- **File**: `App/View Controllers/PostsPageViewController.swift`
- **Purpose**: WebKit-based post content rendering
- **Key Features**:
  - HTML post content display
  - CSS theme integration
  - JavaScript interaction handling
  - Image loading optimization
  - Accessibility support

**Custom Behaviors**:
- Dynamic CSS injection for themes
- Custom scrolling behavior
- Touch handling for quotes and links
- Image zoom functionality
- Text selection enhancement

### LoadingView
- **File**: `App/Views/LoadingView.swift`
- **Purpose**: Themed loading animations
- **Key Features**:
  - Lottie animation integration
  - Theme-aware color adaptation
  - Multiple animation styles
  - Progress indication
  - Cancellation support

**Custom Behaviors**:
- Automatic theme color updates
- Animation style switching
- Performance optimization
- Memory management
- Accessibility announcements

### ThreadTagPickerView
- **File**: `App/Views/ThreadTagPickerView.swift`
- **Purpose**: Thread tag selection interface
- **Key Features**:
  - Visual tag representation
  - Touch-based selection
  - Theme integration
  - Animation support
  - Multi-selection capability

**Custom Behaviors**:
- Custom layout algorithms
- Touch area optimization
- Selection feedback
- Animation coordination
- State persistence

## Navigation Enhancement Views

### UnpoppingViewHandler
- **File**: `App/Views/UnpoppingViewHandler.swift`
- **Purpose**: Right-edge swipe to restore view controllers
- **Key Features**:
  - Edge gesture recognition
  - View controller restoration
  - Animation coordination
  - State management
  - Memory optimization

**Custom Behaviors**:
- Custom edge detection
- Smooth restoration animations
- Stack management
- Memory cleanup
- Gesture conflict resolution

### PassthroughViewController
- **File**: `App/View Controllers/PassthroughViewController.swift`
- **Purpose**: Container for iOS split view bug workarounds
- **Key Features**:
  - Transparent event passing
  - Layout bug fixes
  - State coordination
  - Memory management
  - iOS version compatibility

**Custom Behaviors**:
- Event forwarding
- Layout correction
- State synchronization
- Bug mitigation
- Version compatibility

## Input and Interaction Views

### SmilieCollectionView
- **File**: `Smilies/SmilieCollectionViewController.swift`
- **Purpose**: Custom emoticon selection interface
- **Key Features**:
  - Grid-based smilie display
  - Category organization
  - Search functionality
  - Recent smilie tracking
  - Performance optimization

**Custom Behaviors**:
- Custom cell sizing
- Efficient image loading
- Search highlighting
- Category switching
- Memory management

### ComposeTextView
- **File**: `App/Views/ComposeTextView.swift`
- **Purpose**: Enhanced text editing for composition
- **Key Features**:
  - Rich text editing support
  - BBCode integration
  - Placeholder handling
  - Auto-correction management
  - Accessibility enhancement

**Custom Behaviors**:
- Custom text processing
- Format preservation
- Selection handling
- Keyboard coordination
- Undo/redo support

## Visual Enhancement Views

### AwfulRefreshControl
- **File**: `App/Views/AwfulRefreshControl.swift`
- **Purpose**: Custom animated refresh control
- **Key Features**:
  - Multiple animation styles (Frog, Ghost)
  - Theme integration
  - Performance optimization
  - Custom timing
  - Haptic feedback

**Custom Behaviors**:
- Custom animation sequences
- Theme-aware coloring
- Performance monitoring
- Memory optimization
- Gesture coordination

### GradientView
- **File**: `App/Views/GradientView.swift`
- **Purpose**: Gradient backgrounds and effects
- **Key Features**:
  - Dynamic gradient creation
  - Theme color integration
  - Animation support
  - Performance optimization
  - Accessibility handling

**Custom Behaviors**:
- Real-time color updates
- Smooth transitions
- Layer management
- Memory efficiency
- Theme synchronization

## Layout and Container Views

### AwfulSplitView
- **File**: `App/Views/AwfulSplitView.swift`
- **Purpose**: Custom split view implementation
- **Key Features**:
  - Responsive layout handling
  - Custom divider styling
  - Gesture coordination
  - State preservation
  - iOS bug workarounds

**Custom Behaviors**:
- Custom resize handling
- Gesture recognition
- State management
- Layout coordination
- Bug mitigation

### FlexibleToolbar
- **File**: `App/Views/FlexibleToolbar.swift`
- **Purpose**: Adaptive toolbar with custom layouts
- **Key Features**:
  - Dynamic item placement
  - Size class adaptation
  - Theme integration
  - Animation support
  - Accessibility optimization

**Custom Behaviors**:
- Intelligent item layout
- Responsive design
- Theme updates
- Animation coordination
- Accessibility support

## Accessibility-Enhanced Views

### AccessibleTableViewCell
- **File**: `App/Views/AccessibleTableViewCell.swift`
- **Purpose**: Enhanced table view cell with accessibility
- **Key Features**:
  - VoiceOver optimization
  - Dynamic Type support
  - Custom trait handling
  - Action accessibility
  - Navigation enhancement

**Custom Behaviors**:
- Accessibility element grouping
- Custom action descriptions
- Dynamic layout adaptation
- Voice-over navigation
- Gesture coordination

### AccessibleWebView
- **File**: `App/Views/AccessibleWebView.swift`
- **Purpose**: Web view with enhanced accessibility
- **Key Features**:
  - VoiceOver integration
  - Content accessibility
  - Navigation assistance
  - Custom gesture handling
  - Screen reader optimization

**Custom Behaviors**:
- Content structure announcement
- Navigation assistance
- Custom gesture recognition
- Reading order optimization
- Interactive element identification

## Performance Optimization Views

### LazyImageView
- **File**: `App/Views/LazyImageView.swift`
- **Purpose**: Efficient image loading and display
- **Key Features**:
  - Lazy loading implementation
  - Memory management
  - Placeholder handling
  - Error state display
  - Performance monitoring

**Custom Behaviors**:
- Intelligent loading timing
- Memory pressure handling
- Cache coordination
- Performance optimization
- Error recovery

### VirtualizedListView
- **File**: `App/Views/VirtualizedListView.swift`
- **Purpose**: Efficient large list rendering
- **Key Features**:
  - Virtual scrolling
  - Cell recycling
  - Performance monitoring
  - Memory optimization
  - Smooth scrolling

**Custom Behaviors**:
- Viewport calculation
- Cell lifecycle management
- Memory optimization
- Performance monitoring
- Smooth scrolling

## Migration Considerations

### SwiftUI Conversion Strategy
1. **Direct Conversion**: Simple views to SwiftUI Views
2. **UIViewRepresentable**: Complex views wrapped initially
3. **Behavior Preservation**: Maintain exact functionality
4. **Performance Optimization**: Leverage SwiftUI benefits

### Critical Behaviors to Preserve
- Custom drawing and animations
- Touch handling and gestures
- Accessibility features
- Performance characteristics
- Theme integration

## Implementation Guidelines

### View Design Principles
- **Single Responsibility**: Each view has clear purpose
- **Composability**: Views work well together
- **Performance**: Efficient rendering and memory usage
- **Accessibility**: Full accessibility support
- **Theming**: Dynamic theme adaptation

### Code Organization
- **Separation of Concerns**: UI logic separated from business logic
- **Protocol Conformance**: Consistent interface adoption
- **Error Handling**: Graceful error management
- **Testing Support**: Testable view implementations

## Testing Considerations

### Visual Testing
- **Snapshot Testing**: Visual regression testing
- **Theme Testing**: Verify theme adaptation
- **Layout Testing**: Responsive layout verification
- **Animation Testing**: Animation behavior verification

### Interaction Testing
- **Gesture Testing**: Custom gesture verification
- **Accessibility Testing**: VoiceOver compatibility
- **Performance Testing**: Rendering performance measurement
- **Memory Testing**: Memory usage validation

## Migration Risks

### High-Risk Views
- **RenderView**: Complex WebKit integration
- **Custom Gesture Views**: Intricate touch handling
- **Performance-Critical Views**: Optimization requirements
- **Accessibility Views**: Complex accessibility features

### Mitigation Strategies
- **Progressive Migration**: One view at a time
- **Behavior Testing**: Comprehensive testing
- **Performance Monitoring**: Continuous measurement
- **Rollback Planning**: Quick reversion capability