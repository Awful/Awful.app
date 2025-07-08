# Navigation Migration Guide

## Overview

This guide covers migrating Awful.app's complex navigation system from UIKit to SwiftUI, including split view controllers, tab navigation, modal presentations, and custom navigation behaviors.

## Current Navigation Architecture

### UIKit Implementation
```swift
// Current navigation structure
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        
        // Main split view controller
        let splitViewController = UISplitViewController(style: .doubleColumn)
        splitViewController.delegate = self
        
        // Primary: Forums navigation
        let forumsVC = ForumsTableViewController()
        let forumsNav = UINavigationController(rootViewController: forumsVC)
        
        // Secondary: Initially empty
        let threadsVC = ThreadsTableViewController()
        let threadsNav = UINavigationController(rootViewController: threadsVC)
        
        splitViewController.setViewController(forumsNav, for: .primary)
        splitViewController.setViewController(threadsNav, for: .secondary)
        
        window?.rootViewController = splitViewController
        window?.makeKeyAndVisible()
    }
}

// Current navigation coordinator
class NavigationCoordinator {
    weak var splitViewController: UISplitViewController?
    
    func showThreads(for forum: Forum) {
        let threadsVC = ThreadsTableViewController(forum: forum)
        let nav = UINavigationController(rootViewController: threadsVC)
        splitViewController?.setViewController(nav, for: .secondary)
    }
    
    func showPosts(for thread: Thread) {
        let postsVC = PostsPageViewController(thread: thread)
        let nav = UINavigationController(rootViewController: postsVC)
        splitViewController?.setViewController(nav, for: .secondary)
    }
}
```

### Key Navigation Patterns
1. **Split View**: Forums → Threads → Posts hierarchy
2. **Tab Navigation**: Settings and other sections
3. **Modal Presentations**: Compose, Login, Profile
4. **Custom Transitions**: Animated navigation
5. **Deep Linking**: URL-based navigation
6. **State Restoration**: Navigation state persistence

## SwiftUI Migration Strategy

### Phase 1: Navigation State Management

Create centralized navigation state:

```swift
// New NavigationState.swift
@MainActor
class NavigationState: ObservableObject {
    @Published var selectedForum: Forum?
    @Published var selectedThread: Thread?
    @Published var selectedPost: Post?
    @Published var presentedSheet: PresentedSheet?
    @Published var navigationPath = NavigationPath()
    
    // Tab selection
    @Published var selectedTab: MainTab = .forums
    
    // Split view state
    @Published var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    enum PresentedSheet: Identifiable {
        case compose(thread: Thread? = nil)
        case login
        case profile(user: User)
        case settings
        case privateMessage(message: PrivateMessage)
        
        var id: String {
            switch self {
            case .compose: return "compose"
            case .login: return "login"
            case .profile: return "profile"
            case .settings: return "settings"
            case .privateMessage: return "privateMessage"
            }
        }
    }
    
    enum MainTab: String, CaseIterable {
        case forums = "Forums"
        case bookmarks = "Bookmarks"
        case privateMessages = "Messages"
        case profile = "Profile"
        case settings = "Settings"
        
        var systemImage: String {
            switch self {
            case .forums: return "text.bubble"
            case .bookmarks: return "bookmark"
            case .privateMessages: return "envelope"
            case .profile: return "person"
            case .settings: return "gear"
            }
        }
    }
    
    // Navigation actions
    func selectForum(_ forum: Forum) {
        selectedForum = forum
        selectedThread = nil
        selectedPost = nil
    }
    
    func selectThread(_ thread: Thread) {
        selectedThread = thread
        selectedPost = nil
    }
    
    func selectPost(_ post: Post) {
        selectedPost = post
    }
    
    func presentSheet(_ sheet: PresentedSheet) {
        presentedSheet = sheet
    }
    
    func dismissSheet() {
        presentedSheet = nil
    }
    
    // Deep linking support
    func navigate(to url: URL) {
        // Parse forum URLs and navigate accordingly
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            handleDeepLink(components)
        }
    }
    
    private func handleDeepLink(_ components: URLComponents) {
        // Implementation for deep link handling
        // showthread.php?threadid=123
        // forumdisplay.php?forumid=456
    }
}
```

### Phase 2: Main Navigation Structure

Create SwiftUI navigation hierarchy:

```swift
// New MainNavigationView.swift
struct MainNavigationView: View {
    @EnvironmentObject var navigationState: NavigationState
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationSplitView(columnVisibility: $navigationState.columnVisibility) {
            // Sidebar - Forums hierarchy
            SidebarView()
                .navigationSplitViewColumnWidth(min: 320, ideal: 350, max: 400)
        } content: {
            // Content - Threads list
            ContentView()
                .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
        } detail: {
            // Detail - Posts view
            DetailView()
                .navigationSplitViewColumnWidth(min: 400, ideal: 600)
        }
        .sheet(item: $navigationState.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        .onOpenURL { url in
            navigationState.navigate(to: url)
        }
    }
    
    @ViewBuilder
    private func sheetContent(for sheet: NavigationState.PresentedSheet) -> some View {
        switch sheet {
        case .compose(let thread):
            ComposeView(thread: thread)
        case .login:
            LoginView()
        case .profile(let user):
            ProfileView(user: user)
        case .settings:
            SettingsView()
        case .privateMessage(let message):
            PrivateMessageView(message: message)
        }
    }
}
```

### Phase 3: Individual Navigation Views

Create specialized navigation views:

```swift
// New SidebarView.swift
struct SidebarView: View {
    @EnvironmentObject var navigationState: NavigationState
    @StateObject private var forumsViewModel = ForumsViewModel()
    
    var body: some View {
        NavigationStack {
            List(selection: $navigationState.selectedForum) {
                ForEach(forumsViewModel.forums) { forum in
                    ForumRow(forum: forum)
                        .tag(forum)
                }
            }
            .navigationTitle("Forums")
            .refreshable {
                await forumsViewModel.refresh()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        navigationState.presentSheet(.settings)
                    }
                }
            }
        }
        .task {
            await forumsViewModel.loadForums()
        }
    }
}

// New ContentView.swift
struct ContentView: View {
    @EnvironmentObject var navigationState: NavigationState
    @StateObject private var threadsViewModel = ThreadsViewModel()
    
    var body: some View {
        NavigationStack {
            if let forum = navigationState.selectedForum {
                ThreadsListView(forum: forum)
                    .environmentObject(threadsViewModel)
            } else {
                EmptyContentView()
            }
        }
        .onChange(of: navigationState.selectedForum) { forum in
            if let forum = forum {
                threadsViewModel.loadThreads(for: forum)
            }
        }
    }
}

// New DetailView.swift
struct DetailView: View {
    @EnvironmentObject var navigationState: NavigationState
    @StateObject private var postsViewModel = PostsViewModel()
    
    var body: some View {
        NavigationStack {
            if let thread = navigationState.selectedThread {
                PostsView(thread: thread)
                    .environmentObject(postsViewModel)
            } else {
                EmptyDetailView()
            }
        }
        .onChange(of: navigationState.selectedThread) { thread in
            if let thread = thread {
                postsViewModel.loadPosts(for: thread)
            }
        }
    }
}
```

### Phase 4: Tab Navigation

Implement tab-based navigation for iPhone:

```swift
// New TabNavigationView.swift
struct TabNavigationView: View {
    @EnvironmentObject var navigationState: NavigationState
    
    var body: some View {
        TabView(selection: $navigationState.selectedTab) {
            ForEach(NavigationState.MainTab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.rawValue, systemImage: tab.systemImage)
                    }
                    .tag(tab)
            }
        }
        .sheet(item: $navigationState.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
    }
    
    @ViewBuilder
    private func tabContent(for tab: NavigationState.MainTab) -> some View {
        switch tab {
        case .forums:
            ForumsNavigationView()
        case .bookmarks:
            BookmarksView()
        case .privateMessages:
            PrivateMessagesView()
        case .profile:
            ProfileView()
        case .settings:
            SettingsView()
        }
    }
    
    @ViewBuilder
    private func sheetContent(for sheet: NavigationState.PresentedSheet) -> some View {
        // Same as MainNavigationView
    }
}
```

### Phase 5: Responsive Navigation

Adapt navigation based on device:

```swift
// New ResponsiveNavigationView.swift
struct ResponsiveNavigationView: View {
    @EnvironmentObject var navigationState: NavigationState
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad: Split view navigation
            MainNavigationView()
        } else {
            // iPhone: Tab navigation
            TabNavigationView()
        }
    }
}
```

## Migration Steps

### Step 1: Create Navigation Infrastructure (Week 1)
1. **Create NavigationState**: Centralized navigation state management
2. **Setup Environment Objects**: Inject navigation state throughout app
3. **Create Base Navigation Views**: Split view and tab structures
4. **Test Basic Navigation**: Verify view switching works

### Step 2: Migrate Split View Navigation (Week 2)
1. **Convert Forums List**: SwiftUI forums sidebar
2. **Convert Threads List**: SwiftUI threads content view
3. **Convert Posts View**: SwiftUI posts detail view
4. **Implement Selection Logic**: Proper selection handling

### Step 3: Modal Presentations (Week 2)
1. **Convert Compose View**: Modal composition interface
2. **Convert Settings**: Modal settings navigation
3. **Convert Profile Views**: Modal profile presentation
4. **Handle Sheet Dismissal**: Proper modal lifecycle

### Step 4: Advanced Navigation (Week 3)
1. **Deep Linking**: URL-based navigation
2. **State Restoration**: Navigation state persistence
3. **Custom Transitions**: Animated navigation
4. **Accessibility**: VoiceOver navigation

## Custom Navigation Behaviors

### State Restoration
```swift
// Navigation state persistence
extension NavigationState {
    private static let selectedForumKey = "selectedForum"
    private static let selectedThreadKey = "selectedThread"
    
    func saveState() {
        UserDefaults.standard.set(selectedForum?.id, forKey: Self.selectedForumKey)
        UserDefaults.standard.set(selectedThread?.id, forKey: Self.selectedThreadKey)
    }
    
    func restoreState() {
        if let forumId = UserDefaults.standard.string(forKey: Self.selectedForumKey) {
            // Restore forum selection
        }
        if let threadId = UserDefaults.standard.string(forKey: Self.selectedThreadKey) {
            // Restore thread selection
        }
    }
}
```

### Custom Transitions
```swift
// Custom navigation transitions
struct NavigationTransition: ViewModifier {
    let isPresented: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(isPresented ? 1 : 0)
            .scaleEffect(isPresented ? 1 : 0.95)
            .animation(.easeInOut(duration: 0.25), value: isPresented)
    }
}
```

## Risk Mitigation

### High-Risk Areas
1. **Split View Complexity**: Complex iPad navigation patterns
2. **State Management**: Maintaining navigation state consistency
3. **Modal Presentations**: Proper sheet lifecycle management
4. **Deep Linking**: URL parsing and navigation

### Mitigation Strategies
1. **Incremental Migration**: Migrate one navigation pattern at a time
2. **Comprehensive Testing**: Test all navigation flows
3. **State Validation**: Ensure navigation state remains consistent
4. **Fallback Mechanisms**: Handle navigation errors gracefully

## Testing Strategy

### Unit Tests
```swift
// NavigationStateTests.swift
class NavigationStateTests: XCTestCase {
    var navigationState: NavigationState!
    
    override func setUp() {
        navigationState = NavigationState()
    }
    
    func testForumSelection() {
        let forum = Forum(id: "1", name: "Test Forum")
        navigationState.selectForum(forum)
        
        XCTAssertEqual(navigationState.selectedForum, forum)
        XCTAssertNil(navigationState.selectedThread)
    }
    
    func testThreadSelection() {
        let thread = Thread(id: "1", title: "Test Thread")
        navigationState.selectThread(thread)
        
        XCTAssertEqual(navigationState.selectedThread, thread)
        XCTAssertNil(navigationState.selectedPost)
    }
    
    func testSheetPresentation() {
        navigationState.presentSheet(.settings)
        
        XCTAssertNotNil(navigationState.presentedSheet)
        XCTAssertEqual(navigationState.presentedSheet?.id, "settings")
    }
}
```

### Integration Tests
```swift
// NavigationIntegrationTests.swift
class NavigationIntegrationTests: XCTestCase {
    func testSplitViewNavigation() {
        // Test complete navigation flow
        // Forum selection → Thread selection → Post viewing
    }
    
    func testModalPresentation() {
        // Test modal presentation and dismissal
        // Settings modal → Navigation → Dismissal
    }
    
    func testDeepLinking() {
        // Test URL-based navigation
        // Parse forum URL → Navigate to correct view
    }
}
```

## Performance Considerations

### Memory Management
- Use `@StateObject` for view models that own their data
- Use `@ObservedObject` for view models passed from parent
- Implement proper cleanup in view models

### Navigation Efficiency
- Lazy load navigation destinations
- Implement proper view recycling
- Use `NavigationPath` for efficient navigation stack

### State Management
- Minimize `@Published` properties to reduce unnecessary updates
- Use `@State` for local view state
- Implement proper state validation

## Timeline Estimation

### Conservative Estimate: 3 weeks
- **Week 1**: Navigation infrastructure and state management
- **Week 2**: Split view and tab navigation
- **Week 3**: Modal presentations and advanced features

### Aggressive Estimate: 2 weeks
- Assumes familiarity with SwiftUI navigation
- Minimal testing delays
- No major architectural changes

## Dependencies

### Internal Dependencies
- NavigationState: Central navigation management
- ViewModels: Data layer for navigation views
- ThemeManager: Navigation styling

### External Dependencies
- SwiftUI: Navigation framework
- Combine: Reactive state management
- Foundation: Core functionality

## Success Criteria

### Functional Requirements
- [ ] All navigation flows work identically to UIKit version
- [ ] Split view navigation works correctly on iPad
- [ ] Tab navigation works correctly on iPhone
- [ ] Modal presentations work properly
- [ ] Deep linking navigates correctly
- [ ] State restoration works across app launches

### Technical Requirements
- [ ] Navigation state properly managed with ObservableObject
- [ ] No memory leaks in navigation flow
- [ ] Proper view lifecycle management
- [ ] Efficient navigation performance
- [ ] Thread-safe navigation operations

### User Experience Requirements
- [ ] Smooth navigation transitions
- [ ] Consistent navigation behavior
- [ ] Proper back button behavior
- [ ] Accessible navigation for VoiceOver
- [ ] Responsive design across devices

## Migration Checklist

### Pre-Migration
- [ ] Review current navigation architecture
- [ ] Identify all navigation patterns
- [ ] Document current user flows
- [ ] Prepare test scenarios

### During Migration
- [ ] Create NavigationState
- [ ] Convert split view navigation
- [ ] Convert tab navigation
- [ ] Implement modal presentations
- [ ] Add deep linking support

### Post-Migration
- [ ] Verify all navigation flows
- [ ] Test on multiple devices
- [ ] Validate state restoration
- [ ] Update documentation
- [ ] Deploy to beta testing

This migration guide provides a comprehensive approach to converting the complex navigation system while maintaining all existing functionality and user experience.