# Gesture Migration Guide

## Overview

This guide covers migrating Awful.app's custom gesture recognizers and interaction patterns from UIKit to SwiftUI, including swipe actions, long press behaviors, and complex multi-touch interactions.

## Current Gesture System

### UIKit Implementation
```swift
// Current gesture recognizers in posts view
class PostsPageViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupGestureRecognizers()
    }
    
    private func setupGestureRecognizers() {
        // Swipe gestures for page navigation
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(swipeLeft))
        leftSwipe.direction = .left
        webView.addGestureRecognizer(leftSwipe)
        
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(swipeRight))
        rightSwipe.direction = .right
        webView.addGestureRecognizer(rightSwipe)
        
        // Long press for post actions
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressPost))
        longPress.minimumPressDuration = 0.5
        webView.addGestureRecognizer(longPress)
        
        // Pan gesture for revealing actions
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panGesture))
        webView.addGestureRecognizer(pan)
    }
    
    @objc private func swipeLeft(_ gesture: UISwipeGestureRecognizer) {
        navigateToNextPage()
    }
    
    @objc private func swipeRight(_ gesture: UISwipeGestureRecognizer) {
        navigateToPreviousPage()
    }
    
    @objc private func longPressPost(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let location = gesture.location(in: webView)
        showPostActions(at: location)
    }
    
    @objc private func panGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: webView)
        
        switch gesture.state {
        case .began:
            startPanAction()
        case .changed:
            updatePanAction(translation: translation)
        case .ended, .cancelled:
            completePanAction(translation: translation)
        default:
            break
        }
    }
}

// Custom thread cell with swipe actions
class ThreadTableViewCell: UITableViewCell {
    override func awakeFromNib() {
        super.awakeFromNib()
        setupSwipeActions()
    }
    
    private func setupSwipeActions() {
        // Swipe to bookmark
        let bookmarkAction = UIContextualAction(style: .normal, title: "Bookmark") { _, _, completion in
            self.bookmarkThread()
            completion(true)
        }
        bookmarkAction.backgroundColor = .systemBlue
        
        // Swipe to mark read
        let markReadAction = UIContextualAction(style: .normal, title: "Mark Read") { _, _, completion in
            self.markThreadRead()
            completion(true)
        }
        markReadAction.backgroundColor = .systemGreen
        
        let configuration = UISwipeActionsConfiguration(actions: [bookmarkAction, markReadAction])
        configuration.performsFirstActionWithFullSwipe = false
        
        // Only allow trailing swipe actions
        self.swipeActionsConfiguration = configuration
    }
}
```

### Key Gesture Patterns
1. **Page Navigation**: Left/right swipe for page changes
2. **Post Actions**: Long press for context menus
3. **Thread Actions**: Swipe for bookmark/read actions
4. **Pull to Refresh**: Custom refresh gestures
5. **Scroll Interactions**: Enhanced scroll behaviors
6. **Multi-touch**: Pinch to zoom in web view

## SwiftUI Migration Strategy

### Phase 1: Basic Gesture Foundation

Create SwiftUI gesture infrastructure:

```swift
// New GestureManager.swift
@MainActor
class GestureManager: ObservableObject {
    @Published var isPerformingGesture = false
    @Published var currentGestureType: GestureType?
    
    enum GestureType {
        case swipeNavigation
        case longPress
        case pan
        case pinch
    }
    
    func startGesture(_ type: GestureType) {
        currentGestureType = type
        isPerformingGesture = true
    }
    
    func endGesture() {
        currentGestureType = nil
        isPerformingGesture = false
    }
}

// Gesture configuration
struct GestureConfiguration {
    let swipeThreshold: CGFloat = 50
    let longPressMinimumDuration: Double = 0.5
    let panActivationDistance: CGFloat = 20
    let velocityThreshold: CGFloat = 100
    
    static let `default` = GestureConfiguration()
}
```

### Phase 2: Page Navigation Gestures

Convert page swipe navigation:

```swift
// New PageNavigationGesture.swift
struct PageNavigationGesture: ViewModifier {
    let onPreviousPage: () -> Void
    let onNextPage: () -> Void
    let configuration: GestureConfiguration
    
    @StateObject private var gestureManager = GestureManager()
    @State private var dragAmount = CGSize.zero
    @State private var isNavigating = false
    
    func body(content: Content) -> some View {
        content
            .offset(x: dragAmount.width)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        handleDragChanged(value)
                    }
                    .onEnded { value in
                        handleDragEnded(value)
                    }
            )
            .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: dragAmount)
            .environmentObject(gestureManager)
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        guard !isNavigating else { return }
        
        // Only allow horizontal dragging
        if abs(value.translation.x) > abs(value.translation.y) {
            dragAmount = value.translation
            
            if !gestureManager.isPerformingGesture {
                gestureManager.startGesture(.swipeNavigation)
            }
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        defer {
            dragAmount = .zero
            gestureManager.endGesture()
            isNavigating = false
        }
        
        let translation = value.translation.x
        let velocity = value.velocity.x
        
        // Determine if gesture should trigger navigation
        let shouldNavigate = abs(translation) > configuration.swipeThreshold ||
                           abs(velocity) > configuration.velocityThreshold
        
        guard shouldNavigate else { return }
        
        isNavigating = true
        
        if translation > 0 {
            // Swipe right - previous page
            onPreviousPage()
        } else {
            // Swipe left - next page
            onNextPage()
        }
    }
}

extension View {
    func pageNavigationGesture(
        onPreviousPage: @escaping () -> Void,
        onNextPage: @escaping () -> Void,
        configuration: GestureConfiguration = .default
    ) -> some View {
        self.modifier(PageNavigationGesture(
            onPreviousPage: onPreviousPage,
            onNextPage: onNextPage,
            configuration: configuration
        ))
    }
}
```

### Phase 3: Long Press Actions

Implement long press for context actions:

```swift
// New LongPressActions.swift
struct LongPressActionsGesture: ViewModifier {
    let actions: [ContextAction]
    let onActionSelected: (ContextAction) -> Void
    let configuration: GestureConfiguration
    
    @State private var showingActions = false
    @State private var pressLocation = CGPoint.zero
    @StateObject private var gestureManager = GestureManager()
    
    func body(content: Content) -> some View {
        content
            .onLongPressGesture(
                minimumDuration: configuration.longPressMinimumDuration,
                maximumDistance: 10
            ) { location in
                handleLongPress(at: location)
            }
            .overlay(
                LongPressActionMenu(
                    actions: actions,
                    isVisible: showingActions,
                    location: pressLocation,
                    onActionSelected: { action in
                        showingActions = false
                        onActionSelected(action)
                        gestureManager.endGesture()
                    },
                    onDismiss: {
                        showingActions = false
                        gestureManager.endGesture()
                    }
                )
            )
            .environmentObject(gestureManager)
    }
    
    private func handleLongPress(at location: CGPoint) {
        pressLocation = location
        showingActions = true
        gestureManager.startGesture(.longPress)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

struct ContextAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
    let style: ActionStyle
    
    enum ActionStyle {
        case normal
        case destructive
        case cancel
    }
}

struct LongPressActionMenu: View {
    let actions: [ContextAction]
    let isVisible: Bool
    let location: CGPoint
    let onActionSelected: (ContextAction) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                ForEach(actions) { action in
                    ActionButton(action: action) {
                        onActionSelected(action)
                    }
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .position(x: location.x, y: location.y)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVisible)
            .onTapGesture {
                onDismiss()
            }
        }
    }
}

struct ActionButton: View {
    let action: ContextAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: action.icon)
                    .frame(width: 20)
                
                Text(action.title)
                    .font(.body)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .foregroundColor(foregroundColor)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var foregroundColor: Color {
        switch action.style {
        case .normal: return .primary
        case .destructive: return .red
        case .cancel: return .secondary
        }
    }
}

extension View {
    func longPressActions(
        _ actions: [ContextAction],
        onActionSelected: @escaping (ContextAction) -> Void,
        configuration: GestureConfiguration = .default
    ) -> some View {
        self.modifier(LongPressActionsGesture(
            actions: actions,
            onActionSelected: onActionSelected,
            configuration: configuration
        ))
    }
}
```

### Phase 4: Swipe Actions

Implement swipe-to-reveal actions:

```swift
// New SwipeActions.swift
struct SwipeActionsGesture: ViewModifier {
    let leadingActions: [SwipeAction]
    let trailingActions: [SwipeAction]
    let configuration: GestureConfiguration
    
    @State private var offset = CGFloat.zero
    @State private var isShowingActions = false
    @State private var activeActions: [SwipeAction] = []
    @StateObject private var gestureManager = GestureManager()
    
    private let actionWidth: CGFloat = 80
    
    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            // Leading actions
            if offset > 0 {
                SwipeActionView(
                    actions: leadingActions,
                    width: min(offset, CGFloat(leadingActions.count) * actionWidth),
                    onActionTapped: { action in
                        executeAction(action)
                    }
                )
            }
            
            // Main content
            content
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleDragChanged(value)
                        }
                        .onEnded { value in
                            handleDragEnded(value)
                        }
                )
            
            // Trailing actions
            if offset < 0 {
                SwipeActionView(
                    actions: trailingActions,
                    width: min(abs(offset), CGFloat(trailingActions.count) * actionWidth),
                    onActionTapped: { action in
                        executeAction(action)
                    }
                )
            }
        }
        .clipped()
        .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: offset)
        .environmentObject(gestureManager)
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        let translation = value.translation.x
        
        // Determine which actions to show
        if translation > 0 && !leadingActions.isEmpty {
            offset = min(translation, CGFloat(leadingActions.count) * actionWidth)
            activeActions = leadingActions
        } else if translation < 0 && !trailingActions.isEmpty {
            offset = max(translation, -CGFloat(trailingActions.count) * actionWidth)
            activeActions = trailingActions
        }
        
        if !gestureManager.isPerformingGesture && abs(translation) > configuration.panActivationDistance {
            gestureManager.startGesture(.pan)
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let velocity = value.velocity.x
        let translation = value.translation.x
        
        // Determine if actions should remain visible
        let threshold = actionWidth * 0.5
        let shouldStayOpen = abs(translation) > threshold || abs(velocity) > configuration.velocityThreshold
        
        if shouldStayOpen {
            // Snap to action width
            if translation > 0 {
                offset = CGFloat(leadingActions.count) * actionWidth
            } else {
                offset = -CGFloat(trailingActions.count) * actionWidth
            }
            isShowingActions = true
        } else {
            // Snap back to center
            offset = 0
            isShowingActions = false
            activeActions = []
        }
        
        gestureManager.endGesture()
    }
    
    private func executeAction(_ action: SwipeAction) {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Execute action
        action.action()
        
        // Reset state
        offset = 0
        isShowingActions = false
        activeActions = []
    }
}

struct SwipeAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let backgroundColor: Color
    let action: () -> Void
}

struct SwipeActionView: View {
    let actions: [SwipeAction]
    let width: CGFloat
    let onActionTapped: (SwipeAction) -> Void
    
    private let actionWidth: CGFloat = 80
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(actions) { action in
                Button(action: { onActionTapped(action) }) {
                    VStack(spacing: 4) {
                        Image(systemName: action.icon)
                            .font(.system(size: 20, weight: .medium))
                        
                        Text(action.title)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(width: actionWidth, maxHeight: .infinity)
                    .background(action.backgroundColor)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(width: width)
        .clipped()
    }
}

extension View {
    func swipeActions(
        leading: [SwipeAction] = [],
        trailing: [SwipeAction] = [],
        configuration: GestureConfiguration = .default
    ) -> some View {
        self.modifier(SwipeActionsGesture(
            leadingActions: leading,
            trailingActions: trailing,
            configuration: configuration
        ))
    }
}
```

### Phase 5: Enhanced Web View Gestures

Add web view specific gestures:

```swift
// New WebViewGestures.swift
struct WebViewGestureManager: ObservableObject {
    @Published var zoomScale: CGFloat = 1.0
    @Published var contentOffset = CGPoint.zero
    @Published var isZooming = false
    
    func handlePinch(_ gesture: MagnificationGesture.Value) {
        zoomScale = max(0.5, min(3.0, gesture))
    }
    
    func handlePinchEnd() {
        // Snap to standard zoom levels
        if zoomScale < 0.75 {
            zoomScale = 0.5
        } else if zoomScale < 1.25 {
            zoomScale = 1.0
        } else if zoomScale < 2.0 {
            zoomScale = 1.5
        } else {
            zoomScale = 3.0
        }
    }
    
    func resetZoom() {
        zoomScale = 1.0
    }
}

struct WebViewWithGestures: View {
    let thread: Thread
    @Binding var currentPage: Int
    
    @StateObject private var gestureManager = WebViewGestureManager()
    @StateObject private var navigationGestureManager = GestureManager()
    
    var body: some View {
        PostsWebView(
            thread: thread,
            currentPage: $currentPage,
            isLoading: .constant(false)
        )
        .scaleEffect(gestureManager.zoomScale)
        .gesture(
            SimultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        gestureManager.handlePinch(value)
                    }
                    .onEnded { _ in
                        gestureManager.handlePinchEnd()
                    },
                
                DragGesture()
                    .onChanged { value in
                        // Handle content panning when zoomed
                        if gestureManager.zoomScale > 1.0 {
                            gestureManager.contentOffset = value.translation
                        }
                    }
            )
        )
        .pageNavigationGesture(
            onPreviousPage: {
                if currentPage > 1 {
                    currentPage -= 1
                }
            },
            onNextPage: {
                currentPage += 1
            }
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset Zoom") {
                    gestureManager.resetZoom()
                }
                .disabled(gestureManager.zoomScale == 1.0)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: gestureManager.zoomScale)
    }
}
```

## Migration Steps

### Step 1: Basic Gesture Infrastructure (Week 1)
1. **Create GestureManager**: Central gesture coordination
2. **Setup Configuration**: Gesture parameters and thresholds
3. **Create Base Modifiers**: Foundation gesture view modifiers
4. **Test Basic Gestures**: Simple tap and drag recognition

### Step 2: Navigation Gestures (Week 1)
1. **Implement Page Navigation**: Swipe for page changes
2. **Add Visual Feedback**: Drag indicators and animations
3. **Handle Edge Cases**: First/last page constraints
4. **Test Navigation Flow**: Comprehensive gesture testing

### Step 3: Context Actions (Week 2)
1. **Implement Long Press**: Context menu display
2. **Create Action Menus**: Dynamic action presentation
3. **Add Haptic Feedback**: Touch feedback integration
4. **Test Action Execution**: Menu interaction and dismissal

### Step 4: Swipe Actions (Week 2)
1. **Implement Swipe to Reveal**: Sliding action panels
2. **Create Action Buttons**: Individual action components
3. **Add State Management**: Open/closed state handling
4. **Test Action Workflows**: Complete swipe interaction

### Step 5: Advanced Gestures (Week 3)
1. **Add Web View Gestures**: Pinch to zoom integration
2. **Implement Multi-touch**: Complex gesture combinations
3. **Add Accessibility**: VoiceOver gesture alternatives
4. **Test Performance**: Gesture responsiveness optimization

## Custom Gesture Patterns

### Gesture Coordination
```swift
// Coordinate multiple gestures
struct GestureCoordinator: ViewModifier {
    @StateObject private var manager = GestureManager()
    
    func body(content: Content) -> some View {
        content
            .environmentObject(manager)
            .onReceive(manager.$currentGestureType) { gestureType in
                // Coordinate gesture conflicts
                handleGestureTypeChange(gestureType)
            }
    }
    
    private func handleGestureTypeChange(_ gestureType: GestureManager.GestureType?) {
        // Disable conflicting gestures
        // Enable appropriate feedback
        // Coordinate animations
    }
}
```

### Accessibility Integration
```swift
// Provide accessibility alternatives
struct AccessibleGestures: ViewModifier {
    let actions: [ContextAction]
    let onActionSelected: (ContextAction) -> Void
    
    func body(content: Content) -> some View {
        content
            .accessibilityActions {
                ForEach(actions) { action in
                    Button(action.title) {
                        onActionSelected(action)
                    }
                }
            }
    }
}
```

## Risk Mitigation

### High-Risk Areas
1. **Gesture Conflicts**: Multiple simultaneous gestures
2. **Performance**: Complex gesture calculations
3. **Accessibility**: Non-gesture alternatives
4. **Platform Differences**: iOS version compatibility

### Mitigation Strategies
1. **Gesture Prioritization**: Clear gesture hierarchy
2. **Performance Testing**: Continuous responsiveness monitoring
3. **Accessibility Testing**: VoiceOver compatibility validation
4. **Progressive Enhancement**: Graceful degradation

## Testing Strategy

### Unit Tests
```swift
// GestureManagerTests.swift
class GestureManagerTests: XCTestCase {
    var gestureManager: GestureManager!
    
    override func setUp() {
        gestureManager = GestureManager()
    }
    
    func testGestureStart() {
        gestureManager.startGesture(.swipeNavigation)
        
        XCTAssertTrue(gestureManager.isPerformingGesture)
        XCTAssertEqual(gestureManager.currentGestureType, .swipeNavigation)
    }
    
    func testGestureEnd() {
        gestureManager.startGesture(.longPress)
        gestureManager.endGesture()
        
        XCTAssertFalse(gestureManager.isPerformingGesture)
        XCTAssertNil(gestureManager.currentGestureType)
    }
}
```

### Integration Tests
```swift
// GestureIntegrationTests.swift
class GestureIntegrationTests: XCTestCase {
    func testPageNavigationGesture() {
        // Test complete page navigation flow
        // Swipe gesture → Page change → Animation completion
    }
    
    func testLongPressContextMenu() {
        // Test long press action menu
        // Long press → Menu display → Action selection
    }
    
    func testSwipeActions() {
        // Test swipe action revelation
        // Swipe → Actions display → Action execution
    }
}
```

### Accessibility Tests
```swift
// GestureAccessibilityTests.swift
class GestureAccessibilityTests: XCTestCase {
    func testVoiceOverAlternatives() {
        // Test VoiceOver action alternatives
        // Verify all gesture actions accessible via VoiceOver
    }
    
    func testCustomActions() {
        // Test custom accessibility actions
        // Verify action announcements and execution
    }
}
```

## Performance Considerations

### Gesture Recognition
- Use appropriate gesture recognition thresholds
- Minimize gesture state calculations
- Implement efficient hit testing
- Avoid unnecessary gesture updates

### Animation Performance
- Use appropriate animation curves
- Minimize view hierarchy changes
- Implement efficient transform calculations
- Cache gesture-related computations

### Memory Management
- Clean up gesture recognizers properly
- Avoid retain cycles in gesture closures
- Implement proper gesture state reset
- Monitor memory usage during gestures

## Timeline Estimation

### Conservative Estimate: 3 weeks
- **Week 1**: Basic infrastructure and navigation gestures
- **Week 2**: Context actions and swipe actions
- **Week 3**: Advanced gestures and optimization

### Aggressive Estimate: 2 weeks
- Assumes simple gesture requirements
- Minimal custom gesture behavior
- No complex multi-touch interactions

## Dependencies

### Internal Dependencies
- GestureManager: Central gesture coordination
- GestureConfiguration: Gesture parameters
- Theme System: Visual feedback styling

### External Dependencies
- SwiftUI: Gesture framework
- UIKit: Advanced gesture support
- Combine: Reactive gesture events

## Success Criteria

### Functional Requirements
- [ ] All gesture interactions work identically
- [ ] Page navigation gestures work smoothly
- [ ] Context menus appear correctly
- [ ] Swipe actions reveal properly
- [ ] Multi-touch gestures work correctly

### Technical Requirements
- [ ] No gesture conflicts or interference
- [ ] Smooth gesture animations
- [ ] Proper gesture state management
- [ ] Efficient gesture recognition
- [ ] Thread-safe gesture operations

### Accessibility Requirements
- [ ] VoiceOver alternatives for all gestures
- [ ] Custom accessibility actions work
- [ ] Proper gesture announcements
- [ ] Keyboard navigation alternatives
- [ ] Reduced motion support

## Migration Checklist

### Pre-Migration
- [ ] Review all current gesture behaviors
- [ ] Identify gesture interaction patterns
- [ ] Document gesture requirements
- [ ] Prepare accessibility alternatives

### During Migration
- [ ] Create gesture infrastructure
- [ ] Implement navigation gestures
- [ ] Add context action gestures
- [ ] Create swipe action gestures
- [ ] Add advanced gesture support

### Post-Migration
- [ ] Verify all gesture functionality
- [ ] Test gesture performance
- [ ] Validate accessibility support
- [ ] Update documentation
- [ ] Deploy to beta testing

This migration guide provides a comprehensive approach to converting all gesture interactions while maintaining responsiveness and accessibility.