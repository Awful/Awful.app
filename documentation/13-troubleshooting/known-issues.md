# Known Issues

## Overview

This document tracks known issues, limitations, and workarounds in the Awful app, particularly during the SwiftUI migration process.

## SwiftUI Migration Issues

### 1. Navigation Stack Compatibility
**Issue**: iOS 16+ NavigationStack features not available on older iOS versions
**Workaround**: Use conditional compilation for iOS 16+ features, fallback to NavigationView
```swift
if #available(iOS 16.0, *) {
    NavigationStack { /* content */ }
} else {
    NavigationView { /* content */ }
}
```

### 2. WebKit Integration
**Issue**: WKWebView integration in SwiftUI requires UIViewRepresentable wrapper
**Impact**: Post content display, HTML rendering
**Status**: Implemented UIViewRepresentable wrapper for WebView

### 3. Core Data @FetchRequest Performance
**Issue**: Large datasets can cause UI freezing with @FetchRequest
**Workaround**: Use pagination, lazy loading, or background context updates
```swift
@FetchRequest(
    entity: Post.entity(),
    sortDescriptors: [NSSortDescriptor(keyPath: \Post.index, ascending: true)],
    predicate: NSPredicate(format: "thread == %@", thread),
    animation: .default
) var posts: FetchedResults<Post>
```

## Core Data Issues

### 1. Context Threading
**Issue**: Main context updates on background threads cause crashes
**Workaround**: Always update main context on main thread
```swift
DispatchQueue.main.async {
    // Core Data updates here
}
```

### 2. Fetch Request Predicates
**Issue**: Complex predicates with forum/thread relationships cause slow queries
**Workaround**: Use compound predicates, index key paths
```swift
let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
    NSPredicate(format: "forum.category != nil"),
    NSPredicate(format: "isHidden == NO")
])
```

### 3. Migration Failures
**Issue**: Core Data model migrations fail with large datasets
**Workaround**: Implement progressive migration, backup strategies
**Status**: Monitoring in production

## Networking Issues

### 1. Something Awful Authentication
**Issue**: Session cookies expire unexpectedly
**Workaround**: Implement automatic re-authentication
**Status**: Implemented in ForumsClient

### 2. HTML Parsing Failures
**Issue**: Forum HTML structure changes break scraping
**Workaround**: Defensive parsing, fallback handling
**Status**: Ongoing maintenance required

### 3. Image Loading Performance
**Issue**: Large images cause memory pressure
**Workaround**: Use Nuke framework for image caching, lazy loading
**Status**: Implemented

## UI/UX Issues

### 1. Dark Mode Transitions
**Issue**: Theme switching causes visual glitches
**Workaround**: Implement smooth theme transitions
**Status**: Partially resolved

### 2. Accessibility Support
**Issue**: Custom components lack proper accessibility labels
**Workaround**: Add accessibility modifiers to SwiftUI views
**Status**: In progress

### 3. iPad Layout Issues
**Issue**: Some views don't adapt properly to iPad screen sizes
**Workaround**: Use adaptive layouts, size classes
**Status**: Requires testing

## Performance Issues

### 1. Memory Usage
**Issue**: Large forum threads cause memory spikes
**Workaround**: Implement pagination, view recycling
**Status**: Monitoring

### 2. Scroll Performance
**Issue**: Complex post views cause stuttering
**Workaround**: Optimize view hierarchy, use LazyVStack
**Status**: In progress

### 3. App Launch Time
**Issue**: Core Data stack initialization delays app launch
**Workaround**: Lazy initialization, background setup
**Status**: Optimized

## Build Issues

### 1. Xcode Version Compatibility
**Issue**: SwiftUI features require specific Xcode versions
**Workaround**: Use feature flags, conditional compilation
**Status**: Documented in build requirements

### 2. Swift Package Manager
**Issue**: SPM dependency resolution conflicts
**Workaround**: Pin specific versions, use Package.resolved
**Status**: Stable

### 3. Code Signing
**Issue**: App Group entitlements for Smilie keyboard
**Workaround**: Proper configuration in Local.xcconfig
**Status**: Documented

## Testing Issues

### 1. SwiftUI Testing Limitations
**Issue**: Limited testing APIs for SwiftUI views
**Workaround**: Use UIHostingController for testing
**Status**: Implementing test patterns

### 2. Core Data Testing
**Issue**: In-memory store setup for tests
**Workaround**: Use NSInMemoryStoreType for test contexts
**Status**: Implemented

### 3. Async Testing
**Issue**: Testing async operations in SwiftUI
**Workaround**: Use expectation-based testing
**Status**: Patterns established

## Device-Specific Issues

### 1. iPhone 14 Pro Dynamic Island
**Issue**: Status bar height changes affect layout
**Workaround**: Use safe area insets properly
**Status**: Tested

### 2. iPad Pro M1 Performance
**Issue**: Overly aggressive optimization causes UI lag
**Workaround**: Profile and optimize view updates
**Status**: Monitoring

### 3. Older Device Support
**Issue**: iOS 15 compatibility for some SwiftUI features
**Workaround**: Use availability checks, fallback implementations
**Status**: Documented

## Third-Party Library Issues

### 1. Lottie Animation Performance
**Issue**: Complex animations affect scroll performance
**Workaround**: Limit animation complexity, use static images when appropriate
**Status**: Case-by-case basis

### 2. HTMLReader Updates
**Issue**: HTML parsing library updates break compatibility
**Workaround**: Pin library versions, test thoroughly
**Status**: Stable

### 3. Nuke Image Caching
**Issue**: Memory cache not clearing properly
**Workaround**: Configure cache limits, implement manual clearing
**Status**: Configured

## Workaround Patterns

### 1. Conditional Compilation
```swift
#if os(iOS)
    // iOS-specific code
#elseif os(macOS)
    // macOS-specific code
#endif
```

### 2. Feature Flags
```swift
struct FeatureFlags {
    static let enableSwiftUIThreads = true
    static let enableNewNavigation = false
}
```

### 3. Graceful Degradation
```swift
func loadContent() {
    if #available(iOS 16.0, *) {
        // Use new API
    } else {
        // Fallback implementation
    }
}
```

## Monitoring and Reporting

### 1. Crash Reporting
- Use Xcode Organizer for crash logs
- Monitor memory usage patterns
- Track performance regressions

### 2. User Feedback
- Monitor App Store reviews
- Track support requests
- Gather beta tester feedback

### 3. Analytics
- Track feature usage
- Monitor performance metrics
- Identify common failure patterns

## Resolution Status

| Issue | Priority | Status | Target Release |
|-------|----------|--------|----------------|
| Navigation Stack | High | In Progress | 7.10 |
| WebKit Integration | High | Complete | 7.9 |
| Core Data Performance | Medium | Monitoring | 7.11 |
| Accessibility | Medium | In Progress | 7.12 |
| iPad Layout | Low | Planning | 8.0 |

## Getting Help

### 1. Internal Documentation
- Check architecture documentation
- Review migration guides
- Consult troubleshooting guides

### 2. External Resources
- Apple Developer Documentation
- SwiftUI forums
- Stack Overflow

### 3. Team Communication
- Create GitHub issues for bugs
- Discuss in team meetings
- Document solutions for future reference