# UI Components Documentation

## Overview

This section documents Awful.app's UI components, their custom behaviors, and migration considerations for SwiftUI. Understanding these components is essential for preserving the app's unique user experience.

## Contents

- [View Controllers](./view-controllers.md) - Primary UIKit view controllers
- [Custom Views](./custom-views.md) - Specialized UI components
- [Navigation Patterns](./navigation-patterns.md) - Custom navigation behaviors
- [Table View Components](./table-view-components.md) - Custom cells and headers
- [Web View Integration](./web-view-integration.md) - Post rendering and interaction
- [Input Components](./input-components.md) - Composition and text editing
- [Animation Components](./animation-components.md) - Lottie and custom animations
- [Gesture Handling](./gesture-handling.md) - Custom gesture recognizers
- [SwiftUI Migration Plan](./swiftui-migration-plan.md) - Component-by-component migration strategy

## Key UI Components

### Primary View Controllers
- **ForumsTableViewController**: Forum hierarchy navigation
- **ThreadsTableViewController**: Thread listings with custom cells
- **PostsPageViewController**: Thread viewing with web content
- **MessageViewController**: Private message display
- **Composition Controllers**: Text editing and posting

### Custom Components
- **RenderView**: WebKit-based post rendering
- **AwfulSplitViewController**: Custom split view with iOS bug workarounds
- **RefreshControl**: Custom animated refresh (Frog/Ghost modes)
- **ThreadTagPickerView**: Tag selection with custom layout
- **LoadingView**: Themed loading animations

### Navigation Components
- **UnpoppingViewHandler**: Right-edge swipe to restore views
- **AwfulNavigationController**: Custom navigation with theme support
- **PassthroughViewController**: Container for split view bug fixes

## Custom Behaviors to Preserve

### 🔄 Gesture Navigation
- **Swipe between pages**: Thread page navigation
- **Pull to refresh**: Custom animations
- **Right edge swipe**: "Unpop" previous view controllers
- **Long press menus**: Context-sensitive actions

### 🎨 Dynamic Theming
- **Real-time updates**: All components respond to theme changes
- **Forum-specific themes**: Components adapt to forum context
- **CSS integration**: Web content matches native UI

### 📱 Adaptive Layout
- **Split view behavior**: Responsive sidebar/detail layout
- **Orientation handling**: Custom rotation behaviors
- **Size class adaptation**: iPhone/iPad optimization

### ⚙️ State Preservation
- **View controller restoration**: Complete state saving/loading
- **Composition drafts**: Auto-save and restore text
- **Scroll positions**: Remember reading positions

## Migration Priority

### High Priority (Core Functionality)
1. **PostsPageViewController**: Critical for thread reading
2. **ForumsTableViewController**: Primary navigation
3. **ThreadsTableViewController**: Thread browsing
4. **Authentication components**: Login/logout flows

### Medium Priority (Enhanced Features)
1. **Composition controllers**: Text editing
2. **Settings views**: Preferences management
3. **Profile views**: User information display
4. **Search components**: Content discovery

### Low Priority (Nice to Have)
1. **Animation components**: Loading states
2. **Gesture enhancements**: Advanced interactions
3. **Accessibility improvements**: VoiceOver optimization

## SwiftUI Migration Considerations

### Component Wrapping Strategy
1. **Phase 1**: Wrap existing UIKit components in UIViewControllerRepresentable
2. **Phase 2**: Create SwiftUI equivalents with identical behavior
3. **Phase 3**: Enhance with SwiftUI-native features

### Behavior Preservation
- All custom gestures must work identically
- Theme switching must be seamless
- State restoration must be maintained
- Performance characteristics must be preserved

### Enhancement Opportunities
- Modern navigation (NavigationStack)
- SwiftUI animations
- Improved accessibility
- Better state management
