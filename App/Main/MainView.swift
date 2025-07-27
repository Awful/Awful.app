import AwfulCore
import AwfulExtensions
import AwfulModelTypes
import AwfulSettings
import AwfulSettingsUI
import AwfulTheming
import SwiftUI
import Combine
import CoreData
import Foundation
import os
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MainCoordinator")
private let navigationLog = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "navigation-gestures")

// MARK: - TabView Flickering Fix
// 
// This implementation fixes the Forums tab flickering issue using a proven architecture:
// 1. LazyView prevents premature TabContentView instantiation
// 2. TabManager provides centralized state management with debounced switching
// 3. Only displayedTab content is created, eliminating simultaneous instantiation

// MARK: - LazyView Wrapper
// Prevents TabContentView instantiation until actually needed
struct LazyView<Content: View>: View {
    let build: () -> Content
    
    init(@ViewBuilder _ content: @escaping () -> Content) {
        self.build = content
    }
    
    var body: Content {
        build()
    }
}

// MARK: - Tab Manager
// Centralized tab state management with debounced switching to prevent flickering
@MainActor
class TabManager: ObservableObject {
    @Published var selectedTab: MainTab = .forums
    @Published var displayedTab: MainTab = .forums
    
    private var tabTransitionDebouncer: Task<Void, Never>?
    
    func selectTab(_ tab: MainTab) {
        selectedTab = tab
        
        // Debounce the displayed tab update to prevent rapid changes
        tabTransitionDebouncer?.cancel()
        tabTransitionDebouncer = Task {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
            if !Task.isCancelled {
                displayedTab = tab
            }
        }
    }
}

// MARK: - Custom Navigation System

/// Custom navigation bar for our views
struct CustomNavigationBar: ViewModifier {
    let title: String
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            HStack {
                // Back button
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .disabled(!canGoBack)
                .opacity(canGoBack ? 1.0 : 0.3)
                
                Spacer()
                
                // Title
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                // Forward button (for unpop)
                Button(action: onForward) {
                    HStack(spacing: 4) {
                        Text("Forward")
                        Image(systemName: "chevron.right")
                    }
                }
                .disabled(!canGoForward)
                .opacity(canGoForward ? 1.0 : 0.3)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .shadow(radius: 1)
            
            content
        }
    }
}

/// Custom navigation bar specifically for forum/thread list views
struct ForumNavigationBar: ViewModifier {
    let title: String
    let canGoBack: Bool
    let onBack: () -> Void
    let onCompose: () -> Void
    @SwiftUI.Environment(\.theme) private var theme
    
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            HStack {
                // Back button using arrowleft asset
                Button(action: onBack) {
                    Image("arrowleft")
                        .foregroundColor(theme[color: "navigationBarTextColor"] ?? .primary)
                }
                .disabled(!canGoBack)
                .opacity(canGoBack ? 1.0 : 0.3)
                
                Spacer()
                
                // Title
                Text(title)
                    .font(.headline)
                    .foregroundColor(theme[color: "navigationBarTextColor"] ?? .primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Compose button using compose asset
                Button(action: onCompose) {
                    Image("compose")
                        .foregroundColor(theme[color: "navigationBarTextColor"] ?? .primary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(theme[uicolor: "navigationBarTintColor"] ?? UIColor.systemBackground))
            .shadow(radius: 1)
            
            content
        }
    }
}

extension View {
    func customNavigationBar(
        title: String,
        canGoBack: Bool,
        canGoForward: Bool,
        onBack: @escaping () -> Void,
        onForward: @escaping () -> Void
    ) -> some View {
        modifier(CustomNavigationBar(
            title: title,
            canGoBack: canGoBack,
            canGoForward: canGoForward,
            onBack: onBack,
            onForward: onForward
        ))
    }
    
    func forumNavigationBar(
        title: String,
        canGoBack: Bool,
        onBack: @escaping () -> Void,
        onCompose: @escaping () -> Void
    ) -> some View {
        modifier(ForumNavigationBar(
            title: title,
            canGoBack: canGoBack,
            onBack: onBack,
            onCompose: onCompose
        ))
    }
}

/// Wrapper that integrates with existing MainCoordinator for gradual migration
struct AwfulCustomNavigationWrapper: View {
    @ObservedObject var coordinator: MainCoordinatorImpl
    @Binding var selectedTab: MainTab
    let hasFavoriteForums: Bool
    @SwiftUI.Environment(\.theme) private var theme
    @EnvironmentObject private var tabManager: TabManager
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    @State private var isEditingBookmarks = false
    @State private var isEditingMessages = false
    @State private var isEditingForums = false
    
    @StateObject private var customNavigationController = AwfulNavigationController()
    @State private var forumsNavigationPath = NavigationPath()
    
    var body: some View {
        // Handle navigation destinations with different layouts for forums vs threads
        Group {
            if let destination = customNavigationController.currentDestination {
                switch destination {
                case .forumsList:
                    // Forums list - show normal TabView with stable identity  
                    TabView(selection: Binding(
                        get: { tabManager.selectedTab },
                        set: { tabManager.selectTab($0) }
                    )) {
                        ForEach(MainTab.allCases(canSendPrivateMessages: canSendPrivateMessages), id: \.rawValue) { tab in
                            Group {
                                if tabManager.displayedTab == tab {
                                    LazyView {
                                        TabContentView(tab: tab, coordinator: coordinator, isEditing: getEditingState(for: tab))
                                    }
                                } else {
                                    // Placeholder view to maintain tab structure
                                    Color.clear
                                        .onAppear {
                                            }
                                }
                            }
                            .tabItem {
                                if let tabBarImage = tab.tabBarImage {
                                    Image(tabBarImage)
                                        .renderingMode(.template)
                                } else {
                                    Image(systemName: tab.systemImage)
                                }
                                Text(tab.title)
                            }
                            .tag(tab)
                        }
                    }
                    .tint(Color(theme[uicolor: "tabBarIconSelectedColor"] ?? UIColor.systemBlue))
                    
                case .forum(_):
                    // Forum (thread list) - keep tab bar visible, show within tab context
                    TabView(selection: Binding(
                        get: { tabManager.selectedTab },
                        set: { tabManager.selectTab($0) }
                    )) {
                        ForEach(MainTab.allCases(canSendPrivateMessages: canSendPrivateMessages)) { tab in
                            Group {
                                if tabManager.displayedTab == tab {
                                    LazyView {
                                        if tab == .forums {
                                            // Show forum view in forums tab with custom navigation container
                                            forumsTabNavigationContent(destination: destination)
                                                .gesture(
                                                    DragGesture()
                                                        .onEnded { value in
                                                            handleNavigationSwipe(value)
                                                        }
                                                )
                                        } else {
                                            // Other tabs show normal content
                                            TabContentView(tab: tab, coordinator: coordinator, isEditing: getEditingState(for: tab))
                                        }
                                    }
                                } else {
                                    // Placeholder view to maintain tab structure
                                    Color.clear
                                        .onAppear {
                                            }
                                }
                            }
                            .tabItem {
                                if let tabBarImage = tab.tabBarImage {
                                    Image(tabBarImage)
                                        .renderingMode(.template)
                                } else {
                                    Image(systemName: tab.systemImage)
                                }
                                Text(tab.title)
                            }
                            .tag(tab)
                        }
                    }
                    .tint(Color(theme[uicolor: "tabBarIconSelectedColor"] ?? UIColor.systemBlue))
                    
                case .thread(_):
                    // Thread (posts page) - hide TabView entirely for immersive experience
                    destinationView(for: destination)
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    handleNavigationSwipe(value)
                                }
                        )
                        .animation(.easeInOut(duration: 0.25), value: customNavigationController.currentIndex)
                }
            } else {
                // Normal TabView when no custom navigation active
                TabView(selection: Binding(
                    get: { tabManager.selectedTab },
                    set: { tabManager.selectTab($0) }
                )) {
                    ForEach(MainTab.allCases(canSendPrivateMessages: canSendPrivateMessages), id: \.rawValue) { tab in
                        Group {
                            if tabManager.displayedTab == tab {
                                LazyView {
                                    if tab == .forums {
                                        // Show forums tab with normal content when no navigation active
                                        forumsTabNavigationContent(destination: nil)
                                    } else {
                                        TabContentView(tab: tab, coordinator: coordinator, isEditing: getEditingState(for: tab))
                                    }
                                }
                            } else {
                                // Placeholder view to maintain tab structure
                                Color.clear
                            }
                        }
                        .tabItem {
                            if let tabBarImage = tab.tabBarImage {
                                Image(tabBarImage)
                                    .renderingMode(.template)
                            } else {
                                Image(systemName: tab.systemImage)
                            }
                            Text(tab.title)
                        }
                        .tag(tab)
                    }
                }
                .tint(Color(theme[uicolor: "tabBarIconSelectedColor"] ?? UIColor.systemBlue))
            }
        }
        .environmentObject(customNavigationController)
        .environmentObject(tabManager)
        .sheet(item: $coordinator.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        .sheet(item: $coordinator.presentedPrivateMessageUser) { user in
            privateMessageSheetContent(for: user)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToForum"))) { notification in
            if let forum = notification.object as? Forum {
                // Handle navigation when on the Forums tab
                if tabManager.selectedTab == .forums {
                    customNavigationController.navigateToForum(forum)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToThread"))) { notification in
            if let threadDest = notification.object as? ThreadDestination {
                // Handle thread navigation for forums and bookmarks tabs
                if tabManager.selectedTab == .forums || tabManager.selectedTab == .bookmarks {
                    customNavigationController.navigateToThread(threadDest.thread, page: threadDest.page)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateBack"))) { _ in
            _ = customNavigationController.goBack()
        }
    }
    
    
    @ViewBuilder
    private func forumsTabNavigationContent(destination: AwfulNavigationDestination?) -> some View {
        ZStack {
            // Base forums view (shown when at root or no destination)
            TabContentView(tab: .forums, coordinator: coordinator, isEditing: getEditingState(for: .forums))
                .opacity((destination == nil || (destination != nil && destination! == .forumsList)) ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: destination)
            
            // Thread list overlay (when navigated to a forum)
            if let destination = destination, case .forum = destination {
                destinationView(for: destination)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.3), value: customNavigationController.currentIndex)
            }
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: AwfulNavigationDestination) -> some View {
        switch destination {
        case .forumsList:
            TabContentView(tab: .forums, coordinator: coordinator, isEditing: getEditingState(for: .forums))
        case .forum(let forum):
            SwiftUIThreadsView(forum: forum, managedObjectContext: AppDelegate.instance.managedObjectContext, coordinator: coordinator)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            
        case .thread(let threadDest):
            // Wrap in NavigationStack to enable .toolbar() and .navigationTitle() modifiers
            NavigationStack {
                SwiftUIPostsPageView(
                    thread: threadDest.thread,
                    author: threadDest.author,
                    page: threadDest.page,
                    coordinator: coordinator,
                    scrollFraction: threadDest.scrollFraction,
                    jumpToPostID: threadDest.jumpToPostID
                )
            }
            .background(Color.clear)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            // Let SwiftUIPostsPageView handle its own navigation - no custom navigation bar override
        }
    }
    
    private func handleNavigationSwipe(_ value: DragGesture.Value) {
        let threshold: CGFloat = 100
        let velocityThreshold: CGFloat = 300
        
        if value.translation.width > threshold && value.velocity.width > velocityThreshold {
            // Swipe right - go back
            if customNavigationController.canGoBack {
                logger.info("🔄 Custom navigation: Swipe back gesture detected")
                _ = customNavigationController.goBack()
            }
        } else if value.translation.width < -threshold && value.velocity.width < -velocityThreshold {
            // Swipe left - go forward (unpop)
            if customNavigationController.canGoForward {
                logger.info("🔄 Custom navigation: Swipe forward gesture detected")
                _ = customNavigationController.goForward()
            }
        }
    }
    
    @ViewBuilder
    private func sheetContent(for sheet: MainCoordinatorImpl.PresentedSheet) -> some View {
        switch sheet {
        case .search:
            SearchHostingControllerWrapper()
        case .compose(_):
            MessageComposeViewRepresentable(coordinator: coordinator, isPresentedInSheet: true)
        }
    }
    
    @ViewBuilder
    private func privateMessageSheetContent(for identifiableUser: IdentifiableUser) -> some View {
        MessageComposeDetailView(coordinator: coordinator)
    }
    
    private func setupCoordinatorIntegration() {
        // If we need to sync with existing navigation state, do it here
        logger.info("🔗 Setting up custom navigation integration")
    }
    
    private func getEditingState(for tab: MainTab) -> Bool {
        switch tab {
        case .forums:
            return isEditingForums
        case .bookmarks:
            return isEditingBookmarks
        case .messages:
            return isEditingMessages
        default:
            return false
        }
    }
}

// MARK: - Identifiable Wrappers

struct IdentifiableUser: Identifiable {
    let id: String
    let user: User
    
    init(user: User) {
        self.id = user.userID
        self.user = user
    }
}

// MARK: - Coordinator Protocol

protocol MainCoordinator: ObservableObject {
    var isTabBarHidden: Bool { get set }
    var path: NavigationPath { get set }
    var sidebarPath: NavigationPath { get set }
    func presentSearch()
    func handleEditAction(for tab: MainTab)
    func presentCompose(for tab: MainTab)
    func navigateToThread(_ thread: AwfulThread)
    func navigateToThread(_ thread: AwfulThread, page: ThreadPage)
    func navigateToThread(_ thread: AwfulThread, page: ThreadPage, author: User?)
    func navigateToThread(_ thread: AwfulThread, page: ThreadPage, author: User?, jumpToPostID: String?)
    func navigateToForum(_ forum: Forum)
    func navigateToPrivateMessage(_ message: PrivateMessage)
    func presentComposeThread(for forum: Forum)
    func shouldHideTabBar(isInSidebar: Bool) -> Bool
    
    // URL Routing methods
    func navigateToTab(_ tab: MainTab)
    func navigateToForumWithID(_ forumID: String) -> Bool
    func navigateToThreadWithID(_ threadID: String, page: ThreadPage, author: User?) -> Bool
    func navigateToPostWithID(_ postID: String) -> Bool
    func navigateToMessageWithID(_ messageID: String) -> Bool
    func presentUserProfile(userID: String)
    func presentRapSheet(userID: String)
    func presentPrivateMessageComposer(for user: User)
    func presentReportPost(_ post: Post)
    func presentSharePost(_ post: Post)
    
    // State Restoration methods
    func saveNavigationState()
    func restoreNavigationState()
    
    // SceneStorage Override methods for bypassing SwiftUI's broken NavigationPath restoration
    func saveNavigationPathsToSceneStorage() -> (navigationPathData: Data, sidebarPathData: Data)
    func restoreNavigationPathsFromSceneStorage(navigationPathData: Data, sidebarPathData: Data, timestamp: Double)
    
    // Scroll Position Management
    func updateScrollPosition(scrollFraction: CGFloat)
    func updateScrollPosition(for threadID: String, page: ThreadPage, author: User?, scrollFraction: CGFloat)
    
    // View State Management
    func saveViewState(for threadID: String, state: [String: Any])
    func getViewState(for threadID: String) -> [String: Any]?
    func clearViewState(for threadID: String)
    func clearAllViewStates()
}

// MARK: - Main Coordinator Implementation

class MainCoordinatorImpl: MainCoordinator, ComposeTextViewControllerDelegate {
    @Published var presentedSheet: PresentedSheet?
    @Published var presentedPrivateMessageUser: IdentifiableUser?
    @Published var isTabBarHidden = false
    @Published var path = NavigationPath() {
        willSet {
            // Log all path changes to debug automatic restoration
            if !self.isRestoringState {
                logger.info("🧭 NavigationPath changing from \(self.path.count) to \(newValue.count) items")
                // Store previous count for intelligent restoration detection
                self.previousPathCount = self.path.count
            }
        }
        didSet {
            // Log the actual change that occurred and check for suppression
            if !self.isRestoringState {
                logger.info("🧭 NavigationPath actually changed to \(self.path.count) items")
                
                // Enhanced logging to debug immediate detection
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    let currentCount = self.path.count
                    let previousCount = self.previousPathCount
                    
                    // Always log the change for debugging
                    logger.info("🔍 DEBUG: NavigationPath changed \(previousCount) → \(currentCount)")
                    
                    if let gestureManager = self.navigationGestureStateManager {
                        let shouldSuppress = gestureManager.shouldSuppressRestoration
                        logger.info("🔍 DEBUG: shouldSuppressRestoration = \(shouldSuppress)")
                        
                        if shouldSuppress {
                            // Critical distinction:
                            // - Legitimate navigation: path decreases (user goes back) ✅ ALLOW
                            // - Unwanted restoration: path increases during suppression (SwiftUI restores) ❌ PREVENT
                            if currentCount > previousCount {
                                logger.warning("🧭 CRITICAL: NavigationPath grew from \(previousCount) to \(currentCount) during user suppression - unwanted restoration!")
                                
                                // FORCE CLEAR: Override SwiftUI's unwanted restoration
                                logger.warning("🛡️ PRECISION FORCE CLEAR: Preventing unwanted restoration")
                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self else { return }
                                    self.path = NavigationPath()
                                    self.navigationHistory.removeAll()
                                }
                            } else {
                                logger.info("🧭 ✅ NavigationPath change is legitimate (from \(previousCount) to \(currentCount)) - allowing user navigation")
                            }
                        } else {
                            logger.info("🔍 No suppression active - normal navigation flow")
                        }
                    }
                }
            }
        }
    }
    @Published var sidebarPath = NavigationPath() {
        willSet {
            // Log all sidebar path changes to debug automatic restoration
            if !self.isRestoringState {
                logger.info("🧭 SidebarPath changing from \(self.sidebarPath.count) to \(newValue.count) items")
            }
        }
    }
    
    // Keep a reference to the current compose view controller for triggering actions
    private weak var currentComposeViewController: ComposeTextViewController?
    
    // Reference to the navigation gesture state manager for suppression checks
    weak var navigationGestureStateManager: NavigationGestureStateManager?
    
    // Force-clear restoration detection system
    private var lastUserNavigationTime = Date.distantPast
    private let restorationDetectionWindow: TimeInterval = 12.0  // Slightly longer than suppression window
    private var previousPathCount = 0  // Track previous path count for intelligent restoration detection
    
    // Track navigation destinations for unpop functionality
    @Published var navigationHistory: [AnyHashable] = []
    @Published var unpopStack: [AnyHashable] = []
    
    // Flag to prevent unpop during state restoration
    @Published var isRestoringState = false
    
    // Flag to prevent scroll position updates during post navigation
    private var isNavigatingToPost = false
    
    // View state storage for comprehensive state restoration
    private var viewStateStorage: [String: [String: Any]] = [:]
    
    // State restoration support
    private let stateManager: NavigationStateManager
    private let managedObjectContext: NSManagedObjectContext
    
    // SceneStorage save callback for immediate updates
    var triggerSceneStorageSave: (() -> Void)?
    
    /// Records user navigation action and timestamp for restoration detection
    func recordUserNavigationAction() {
        self.lastUserNavigationTime = Date()
        logger.info("🧭 Coordinator: User navigation action recorded at \(self.lastUserNavigationTime)")
    }
    
    /// Force-clear navigation stack to override SwiftUI internal restoration
    private func handleForceClearNavigation() {
        logger.warning("🛡️ Coordinator: Force clearing NavigationStack due to unwanted restoration")
        
        // Aggressively clear all navigation state
        path = NavigationPath()
        navigationHistory.removeAll()
        unpopStack.removeAll()
        
        // Also clear sidebar path to be thorough
        sidebarPath = NavigationPath()
        
        logger.info("🛡️ Force clear completed - all navigation paths cleared")
    }
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        self.stateManager = NavigationStateManager(managedObjectContext: managedObjectContext)
        
        // Listen for force-clear commands to override SwiftUI internal restoration
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ForceClearNavigationStack"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleForceClearNavigation()
        }
        
        // Listen for page changes from ViewModels to keep navigation state in sync
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ThreadPageDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleThreadPageDidChange(notification)
        }
    }
    
    enum PresentedSheet: Identifiable {
        case search
        case compose(MainTab)
        
        var id: String {
            switch self {
            case .search: return "search"
            case .compose(let tab): return "compose-\(tab.rawValue)"
            }
        }
    }
    
    func presentSearch() {
        presentedSheet = .search
    }
    
    func handleEditAction(for tab: MainTab) {
        // Handle edit actions - for now this could be a no-op since EditButton handles its own state
        // But this gives us a place to coordinate edit state across the app if needed
    }
    
    func presentCompose(for tab: MainTab) {
        presentedSheet = .compose(tab)
    }
    
    func navigateToThread(_ thread: AwfulThread) {
        // Determine which page to show based on thread state:
        // - New thread: go to first page
        // - Thread with unread posts: go to next unread
        // - Thread with all posts seen: go to last page
        let page: ThreadPage
        if !thread.beenSeen {
            page = .first
        } else if thread.anyUnreadPosts {
            page = .nextUnread
        } else {
            page = .last
        }
        navigateToThread(thread, page: page, author: nil)
    }
    
    func navigateToThread(_ thread: AwfulThread, page: ThreadPage) {
        navigateToThread(thread, page: page, author: nil)
    }
    
    func navigateToThread(_ thread: AwfulThread, page: ThreadPage, author: User?) {
        navigateToThread(thread, page: page, author: author, jumpToPostID: nil)
    }
    
    func navigateToThread(_ thread: AwfulThread, page: ThreadPage, author: User?, jumpToPostID: String?) {
        let destination = ThreadDestination(thread: thread, page: page, author: author, jumpToPostID: jumpToPostID)
        logger.info("navigateToThread called - thread: \(thread.title ?? "Unknown"), page: \(String(describing: page)), jumpToPostID: \(jumpToPostID ?? "none")")
        logger.debug("Current path count: \(self.path.count)")
        
        // Clear unpop stack when navigating to new destination
        unpopStack.removeAll()
        
        // Add to navigation history and path
        navigationHistory.append(destination)
        path.append(destination)
        
        logger.debug("Path count after navigation: \(self.path.count)")
        // Always hide tab bar when navigating to posts (immersive mode)
        isTabBarHidden = true
    }
    
    func navigateToThread(_ thread: AwfulThread, author: User?) {
        let page: ThreadPage = .specific(1)
        navigateToThread(thread, page: page, author: author)
    }

    func navigateToForum(_ forum: Forum) {
        print("🔍 MainCoordinator: navigateToForum called for: \(forum.name ?? "unnamed")")
        
        // Check if we're on iPhone or iPad to determine which path to use
        if UIDevice.current.userInterfaceIdiom == .phone {
            // On iPhone, use the main navigation path
            path.append(forum)
            print("🔍 MainCoordinator: iPhone - appended to main path")
        } else {
            // On iPad, use the sidebar path (threads list)
            sidebarPath.append(forum)
            print("🔍 MainCoordinator: iPad - appended to sidebar path")
        }
    }
    
    func navigateToPrivateMessage(_ message: PrivateMessage) {
        let destination = PrivateMessageDestination(message: message)
        
        // Clear unpop stack when navigating to new destination
        unpopStack.removeAll()
        
        // Add to navigation history and path
        navigationHistory.append(destination)
        path.append(destination)
        
        print("🔍 navigateToPrivateMessage: Added message \(message.messageID) to navigation path")
    }
    
    func navigateToComposeMessage() {
        let destination = ComposePrivateMessage()
        
        // Clear unpop stack when navigating to new destination
        unpopStack.removeAll()
        
        // Add to navigation history and path
        navigationHistory.append(destination)
        path.append(destination)
        // Compose messages don't need to hide the tab bar
    }
    
    func presentComposeThread(for forum: Forum) {
        // Present the thread compose controller modally
        let composeVC = ThreadComposeViewController(forum: forum)
        composeVC.delegate = self
        composeVC.restorationIdentifier = "New thread composition"
        
        // Present modally like the UIKit version does
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(composeVC.enclosingNavigationController, animated: true)
        }
    }
    
    func shouldHideTabBar(isInSidebar: Bool) -> Bool {
        if isInSidebar {
            // On iPad sidebar, always show the tab bar
            return false
        } else {
            // On iPhone, hide the tab bar when viewing a thread (posts view)
            let currentlyViewingThread = navigationHistory.last is ThreadDestination && !path.isEmpty
            return currentlyViewingThread
        }
    }
    
    func setCurrentComposeViewController(_ viewController: ComposeTextViewController?) {
        currentComposeViewController = viewController
    }
    
    func submitCurrentComposition() {
        // Trigger the submit action on the current compose view controller
        currentComposeViewController?.perform(#selector(ComposeTextViewController.didTapSubmit))
    }
    
    func cancelCurrentComposition() {
        // Trigger the cancel action on the current compose view controller
        currentComposeViewController?.perform(#selector(ComposeTextViewController.didTapCancel))
    }
    
    func composeTextViewController(_ composeTextViewController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
        if presentedSheet != nil {
            presentedSheet = nil // dismiss sheet on iPhone
        } else {
            if path.count > 0 {
                // Move the last item from history to unpop stack when popping
                if let lastItem = navigationHistory.last, !navigationHistory.isEmpty {
                    unpopStack.append(lastItem)
                    navigationHistory.removeLast()
                }
                path.removeLast() // pop from detail stack on iPad
            }
        }
        
        // Handle thread composition completion
        if let threadComposeVC = composeTextViewController as? ThreadComposeViewController,
           let thread = threadComposeVC.thread,
           success {
            // Navigate to the newly created thread
            navigateToThread(thread)
        }
    }
    
    // MARK: - Enhanced Unpop Support with State Synchronization
    
    /// Navigation state actor for thread-safe operations
    private actor NavigationStateActor {
        private var isNavigating = false
        private var isWebViewRestoring = false
        private let maxHistorySize = 50
        
        func setWebViewRestoring(_ restoring: Bool) {
            isWebViewRestoring = restoring
        }
        
        func isInRestoration() -> Bool {
            return isNavigating || isWebViewRestoring
        }
        
        func performUnpop(unpopStack: inout [AnyHashable], 
                         navigationHistory: inout [AnyHashable]) async throws -> AnyHashable? {
            guard !isNavigating, !unpopStack.isEmpty else { 
                throw NavigationError.navigationInProgress 
            }
            
            isNavigating = true
            defer { isNavigating = false }
            
            let itemToRestore = unpopStack.removeLast()
            navigationHistory.append(itemToRestore)
            
            // Maintain history size limit for memory efficiency
            if navigationHistory.count > maxHistorySize {
                navigationHistory.removeFirst(navigationHistory.count - maxHistorySize)
            }
            
            // Add delay for SwiftUI animation timing coordination
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            return itemToRestore
        }
        
        func handleNavigationPop(navigationHistory: inout [AnyHashable], 
                               unpopStack: inout [AnyHashable], 
                               pathCount: Int) async {
            guard !isNavigating else { return }
            
            let itemsToMoveCount = navigationHistory.count - pathCount
            if itemsToMoveCount > 0 {
                let itemsToMove = Array(navigationHistory.suffix(itemsToMoveCount))
                unpopStack.append(contentsOf: itemsToMove)
                navigationHistory.removeLast(itemsToMoveCount)
            }
        }
    }
    
    private enum NavigationError: Error {
        case navigationInProgress
        case invalidState
    }
    
    private let navigationStateActor = NavigationStateActor()
    
    func performUnpop() {
        let signpostID = OSSignpostID(log: navigationLog)
        os_signpost(.begin, log: navigationLog, name: "Unpop Gesture", 
                    signpostID: signpostID, "Starting unpop operation")
        
        Task { @MainActor in
            do {
                let itemToRestore = try await navigationStateActor.performUnpop(
                    unpopStack: &unpopStack, 
                    navigationHistory: &navigationHistory
                )
                
                guard let item = itemToRestore else { 
                    os_signpost(.end, log: navigationLog, name: "Unpop Gesture", 
                                signpostID: signpostID, "No item to restore")
                    return 
                }
                
                // Update UI on main thread
                path.append(item)
                
                // Hide tab bar if unpop restores a thread destination (immersive mode)
                if item is ThreadDestination {
                    isTabBarHidden = true
                }
                
                os_signpost(.end, log: navigationLog, name: "Unpop Gesture", 
                            signpostID: signpostID, "Successfully restored item")
                logger.info("🔄 Unpop performed successfully, restored item to path. Path count: \(self.path.count)")
                
            } catch NavigationError.navigationInProgress {
                os_signpost(.end, log: navigationLog, name: "Unpop Gesture", 
                            signpostID: signpostID, "Skipped - navigation in progress")
                logger.info("🔄 Unpop skipped - navigation in progress")
            } catch {
                os_signpost(.end, log: navigationLog, name: "Unpop Gesture", 
                            signpostID: signpostID, "Failed: %{public}s", error.localizedDescription)
                logger.error("🔄 Unpop failed: \(error.localizedDescription)")
            }
        }
    }
    
    func handleNavigationPop() {
        // Debounced navigation pop handling to prevent rapid state changes
        Task { @MainActor in
            await navigationStateActor.handleNavigationPop(
                navigationHistory: &navigationHistory,
                unpopStack: &unpopStack,
                pathCount: path.count
            )
            
            logger.info("🔄 Navigation pop handled. Unpop stack count: \(self.unpopStack.count)")
        }
    }
    
    // MARK: - Enhanced Restoration State Management
    
    /// Sets WebView restoration state to coordinate with unpop gestures
    func setWebViewRestorationState(_ restoring: Bool) {
        Task {
            await navigationStateActor.setWebViewRestoring(restoring)
        }
        
        // Update the main restoration flag for backward compatibility
        if restoring {
            isRestoringState = true
        }
        
        logger.info("🔄 WebView restoration state set to: \(restoring)")
    }
    
    /// Check if any restoration is in progress
    func isAnyRestorationInProgress() async -> Bool {
        return await navigationStateActor.isInRestoration() || isRestoringState
    }
    
    // MARK: - URL Routing Implementation
    
    func navigateToTab(_ tab: MainTab) {
        // This would be handled by the MainView by updating selectedTab
        // For now, we'll just print debug info
        print("🔗 MainCoordinator: navigateToTab called - tab: \(tab)")
    }
    
    func navigateToForumWithID(_ forumID: String) -> Bool {
        print("🔗 MainCoordinator: navigateToForumWithID called - forumID: \(forumID)")
        
        // Find the forum in Core Data
        guard let context = AppDelegate.instance?.managedObjectContext else {
            print("❌ AppDelegate.instance or managedObjectContext not available")
            return false
        }
        let request = NSFetchRequest<Forum>(entityName: Forum.entityName)
        request.predicate = NSPredicate(format: "forumID == %@", forumID)
        request.fetchLimit = 1
        
        do {
            let forums = try context.fetch(request)
            guard let forum = forums.first else {
                print("⚠️ Forum with ID \(forumID) not found")
                return false
            }
            
            navigateToForum(forum)
            return true
        } catch {
            print("❌ Error fetching forum: \(error)")
            return false
        }
    }
    
    func navigateToThreadWithID(_ threadID: String, page: ThreadPage, author: User?) -> Bool {
        print("🔗 MainCoordinator: navigateToThreadWithID called - threadID: \(threadID), page: \(page)")
        
        // Find the thread in Core Data
        guard let context = AppDelegate.instance?.managedObjectContext else {
            print("❌ AppDelegate.instance or managedObjectContext not available")
            return false
        }
        let request = NSFetchRequest<AwfulThread>(entityName: AwfulThread.entityName)
        request.predicate = NSPredicate(format: "threadID == %@", threadID)
        request.fetchLimit = 1
        
        do {
            let threads = try context.fetch(request)
            guard let thread = threads.first else {
                print("⚠️ Thread with ID \(threadID) not found")
                return false
            }
            
            navigateToThread(thread, page: page, author: author)
            return true
        } catch {
            print("❌ Error fetching thread: \(error)")
            return false
        }
    }
    
    func navigateToPostWithID(_ postID: String) -> Bool {
        print("🔗 MainCoordinator: navigateToPostWithID called - postID: \(postID)")
        
        // Find the post in Core Data to get its thread
        guard let context = AppDelegate.instance?.managedObjectContext else {
            print("❌ AppDelegate.instance or managedObjectContext not available")
            return false
        }
        let request = NSFetchRequest<Post>(entityName: Post.entityName)
        request.predicate = NSPredicate(format: "postID == %@", postID)
        request.fetchLimit = 1
        
        do {
            let posts = try context.fetch(request)
            print("🔍 Core Data query found \(posts.count) posts for postID: \(postID)")
            
            if let post = posts.first,
               let thread = post.thread,
               post.page > 0 {
                print("📋 Found post in cache: page=\(post.page), thread=\(thread.title ?? "Unknown")")
                // Post exists in cache - check if we're already on the same thread and page
                let targetPage = ThreadPage.specific(post.page)
                
                // Check if we're already on the same thread and page
                if let currentDestination = navigationHistory.last as? ThreadDestination,
                   currentDestination.thread.threadID == thread.threadID,
                   currentDestination.page == targetPage {
                    // Same thread and page - trigger navigation with jumpToPostID
                    print("📍 Already on correct page (\(post.page)), navigating with jumpToPostID")
                    
                    // The SwiftUI system will handle scrolling to the post via jumpToPostID
                    navigationHistory.append(ThreadDestination(
                        thread: thread, 
                        page: targetPage, 
                        author: nil, 
                        jumpToPostID: postID
                    ))
                    return true
                } else {
                    // Different thread or page - navigate to it
                    print("📍 Found cached post on page \(post.page), navigating to thread")
                    isNavigatingToPost = true
                    navigateToThread(thread, page: .specific(post.page), author: nil, jumpToPostID: postID)
                    
                    // Reset the flag after a delay to allow post jumping to complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.isNavigatingToPost = false
                    }
                    return true
                }
            }
            
            // Post not found in cache - fetch from server
            print("🔍 Post not in cache, fetching from server...")
            isNavigatingToPost = true // Set flag immediately to prevent scroll interference
            
            Task { @MainActor in
                do {
                    print("🌐 Calling ForumsClient.shared.locatePost for postID: \(postID)")
                    let (post, page) = try await ForumsClient.shared.locatePost(id: postID, updateLastReadPost: false)
                    guard let thread = post.thread else {
                        print("❌ Located post has no thread")
                        self.isNavigatingToPost = false
                        return
                    }
                    
                    print("📍 Located post on page \(page), navigating to thread: \(thread.title ?? "Unknown")")
                    self.navigateToThread(thread, page: page, author: nil, jumpToPostID: postID)
                    
                    // Reset the flag after a delay to allow post jumping to complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.isNavigatingToPost = false
                    }
                } catch {
                    print("❌ Error locating post: \(error)")
                    self.isNavigatingToPost = false
                }
            }
            
            return true
        } catch {
            print("❌ Error fetching post: \(error)")
            return false
        }
    }
    
    func navigateToMessageWithID(_ messageID: String) -> Bool {
        print("🔗 MainCoordinator: navigateToMessageWithID called - messageID: \(messageID)")
        
        // Find the message in Core Data
        guard let context = AppDelegate.instance?.managedObjectContext else {
            print("❌ AppDelegate.instance or managedObjectContext not available")
            return false
        }
        let request = NSFetchRequest<PrivateMessage>(entityName: PrivateMessage.entityName)
        request.predicate = NSPredicate(format: "messageID == %@", messageID)
        request.fetchLimit = 1
        
        do {
            let messages = try context.fetch(request)
            guard let message = messages.first else {
                print("⚠️ Message with ID \(messageID) not found")
                return false
            }
            
            navigateToPrivateMessage(message)
            return true
        } catch {
            print("❌ Error fetching message: \(error)")
            return false
        }
    }
    
    func presentUserProfile(userID: String) {
        print("🔗 MainCoordinator: presentUserProfile called - userID: \(userID)")
        
        // Find the user in Core Data
        guard let context = AppDelegate.instance?.managedObjectContext else {
            print("❌ AppDelegate.instance or managedObjectContext not available")
            return
        }
        let request = NSFetchRequest<User>(entityName: User.entityName)
        request.predicate = NSPredicate(format: "userID == %@", userID)
        request.fetchLimit = 1
        
        do {
            let users = try context.fetch(request)
            guard let user = users.first else {
                print("⚠️ User with ID \(userID) not found")
                return
            }
            
            // Present user profile modally
            let profileVC = ProfileViewController(user: user)
            profileVC.restorationIdentifier = "Profile"
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(profileVC.enclosingNavigationController, animated: true)
            }
        } catch {
            print("❌ Error fetching user: \(error)")
        }
    }
    
    func presentRapSheet(userID: String) {
        print("🔗 MainCoordinator: presentRapSheet called - userID: \(userID)")
        
        // Find the user in Core Data
        guard let context = AppDelegate.instance?.managedObjectContext else {
            print("❌ AppDelegate.instance or managedObjectContext not available")
            return
        }
        let request = NSFetchRequest<User>(entityName: User.entityName)
        request.predicate = NSPredicate(format: "userID == %@", userID)
        request.fetchLimit = 1
        
        do {
            let users = try context.fetch(request)
            guard let user = users.first else {
                print("⚠️ User with ID \(userID) not found")
                return
            }
            
            // Present rap sheet modally
            let rapSheetVC = RapSheetViewController(user: user)
            rapSheetVC.restorationIdentifier = "Rap sheet"
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(rapSheetVC.enclosingNavigationController, animated: true)
            }
        } catch {
            print("❌ Error fetching user: \(error)")
        }
    }
    
    func presentPrivateMessageComposer(for user: User) {
        print("🔗 MainCoordinator: presentPrivateMessageComposer called - user: \(user.username ?? "Unknown")")
        
        // Present message composer using SwiftUI sheet system (same as ReplyWorkspaceView)
        presentedPrivateMessageUser = IdentifiableUser(user: user)
    }
    
    func presentReportPost(_ post: Post) {
        print("🔗 MainCoordinator: presentReportPost called - post: \(post.postID)")
        
        // Present the report post controller modally
        let reportVC = ReportPostViewController(post: post)
        let navController = UINavigationController(rootViewController: reportVC)
        
        // Get the currently presented view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("❌ Could not find root view controller")
            return
        }
        
        // Find the topmost view controller
        var topViewController = rootViewController
        while let presentedViewController = topViewController.presentedViewController {
            topViewController = presentedViewController
        }
        
        topViewController.present(navController, animated: true)
    }
    
    func presentSharePost(_ post: Post) {
        print("🔗 MainCoordinator: presentSharePost called - post: \(post.postID)")
        
        // Create the post URL
        guard var components = URLComponents(url: ForumsClient.shared.baseURL!, resolvingAgainstBaseURL: true) else {
            print("❌ Could not create URL components")
            return
        }
        
        components.path = "/showthread.php"
        components.queryItems = [
            URLQueryItem(name: "threadid", value: post.thread?.threadID),
            URLQueryItem(name: "postid", value: post.postID)
        ]
        
        guard let url = components.url else {
            print("❌ Could not create post URL")
            return
        }
        
        // Create activity view controller
        let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // Get the currently presented view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("❌ Could not find root view controller")
            return
        }
        
        // Find the topmost view controller
        var topViewController = rootViewController
        while let presentedViewController = topViewController.presentedViewController {
            topViewController = presentedViewController
        }
        
        // Set up popover for iPad
        if let popover = activityController.popoverPresentationController {
            popover.sourceView = topViewController.view
            popover.sourceRect = CGRect(origin: topViewController.view.center, size: CGSize(width: 1, height: 1))
        }
        
        topViewController.present(activityController, animated: true)
    }
    
    // MARK: - Scroll Position Management
    
    func updateScrollPosition(scrollFraction: CGFloat) {
        // Skip scroll position updates during post navigation to prevent interference
        guard !isNavigatingToPost else {
            print("🚫 Skipping scroll position update during post navigation")
            return
        }
        
        // Update the navigation history WITHOUT rebuilding the NavigationPath
        // This prevents automatic navigation while preserving scroll positions
        if let lastIndex = navigationHistory.lastIndex(where: { $0 is ThreadDestination }),
           let threadDestination = navigationHistory[lastIndex] as? ThreadDestination {
            
            // Create a new ThreadDestination with the updated scroll position
            print("🔧 updateScrollPosition (first method): Original jumpToPostID: \(threadDestination.jumpToPostID ?? "none"), preserving in updated destination")
            let updatedDestination = ThreadDestination(
                thread: threadDestination.thread,
                page: threadDestination.page,
                author: threadDestination.author,
                scrollFraction: scrollFraction,
                jumpToPostID: threadDestination.jumpToPostID // Preserve the jumpToPostID from original destination
            )
            
            // Replace the item in navigation history directly
            navigationHistory[lastIndex] = updatedDestination
            
            // IMPORTANT: Also update the NavigationPath so navigation state saves the correct page
            // Since NavigationPath doesn't support direct element access, we need to rebuild it
            // by removing the old item and appending the new one
            
            // Check if we need to update the last item in the path (most common case)
            if path.count > 0 {
                // Remove the last item and append the updated one
                // This assumes the thread being updated is the last item in the path
                path.removeLast()
                path.append(updatedDestination)
            }
            
            logger.info("Updated scroll position to \(scrollFraction) for thread: \(threadDestination.thread.title ?? "Unknown")")
        } else {
            logger.info("⚠️ MainCoordinator: No ThreadDestination found in navigation history to update scroll position")
        }
    }
    
    func updateScrollPosition(for threadID: String, page: ThreadPage, author: User?, scrollFraction: CGFloat) {
        // Skip scroll position updates during post navigation to prevent interference
        guard !isNavigatingToPost else {
            print("🚫 Skipping scroll position update during post navigation")
            return
        }
        
        // Find the ThreadDestination in navigation history WITHOUT rebuilding NavigationPath
        // This prevents automatic navigation while preserving scroll positions
        
        // First try exact match (threadID, page, author)
        var matchIndex = navigationHistory.firstIndex(where: { item in
            guard let threadDestination = item as? ThreadDestination else { return false }
            return threadDestination.thread.threadID == threadID &&
                   threadDestination.page == page &&
                   threadDestination.author == author
        })
        
        // If no exact match, try to find by threadID and author only (page might have changed)
        if matchIndex == nil {
            matchIndex = navigationHistory.firstIndex(where: { item in
                guard let threadDestination = item as? ThreadDestination else { return false }
                return threadDestination.thread.threadID == threadID &&
                       threadDestination.author == author
            })
        }
        
        // If still no match, try threadID only
        if matchIndex == nil {
            matchIndex = navigationHistory.firstIndex(where: { item in
                guard let threadDestination = item as? ThreadDestination else { return false }
                return threadDestination.thread.threadID == threadID
            })
        }
        
        if let index = matchIndex,
           let threadDestination = navigationHistory[index] as? ThreadDestination {
            
            // Preserve the saved scroll fraction if we're updating due to page change
            // Only use the new scroll fraction if it's different from the saved one
            let savedScrollFraction = threadDestination.scrollFraction
            let finalScrollFraction: CGFloat?
            
            if let saved = savedScrollFraction, scrollFraction == 0.0 {
                // If we have a saved scroll fraction and new one is 0, preserve the saved one
                finalScrollFraction = saved
                logger.info("Preserving saved scroll fraction \(saved) for thread \(threadDestination.thread.title ?? "Unknown")")
            } else {
                // Use the new scroll fraction
                finalScrollFraction = scrollFraction > 0 ? scrollFraction : savedScrollFraction
            }
            
            // Create a new ThreadDestination with the updated scroll position and current page
            print("🔧 updateScrollPosition: Original jumpToPostID: \(threadDestination.jumpToPostID ?? "none"), preserving in updated destination")
            let updatedDestination = ThreadDestination(
                thread: threadDestination.thread,
                page: page, // Use the current page, not the saved one
                author: author, // Use the current author, not the saved one
                scrollFraction: finalScrollFraction,
                jumpToPostID: threadDestination.jumpToPostID // Preserve the jumpToPostID from original destination
            )
            
            // Replace the item in navigation history directly
            navigationHistory[index] = updatedDestination
            
            // IMPORTANT: Also update the NavigationPath so navigation state saves the correct page
            // Since NavigationPath doesn't support direct element access, we need to rebuild it
            // by removing the old item and appending the new one
            
            // Check if we need to update the last item in the path (most common case)
            if path.count > 0 {
                // Remove the last item and append the updated one
                // This assumes the thread being updated is the last item in the path
                path.removeLast()
                path.append(updatedDestination)
            }
            
            logger.info("Updated scroll position to \(scrollFraction) for thread: \(threadDestination.thread.title ?? "Unknown") (threadID: \(threadID))")
            
            // Immediately save updated navigation state to SceneStorage to prevent stale restoration
            DispatchQueue.main.async {
                self.triggerSceneStorageSave?()
            }
        } else {
            logger.info("⚠️ MainCoordinator: No ThreadDestination found in navigation history for threadID: \(threadID), page: \(String(describing: page))")
        }
    }
    
    // MARK: - Helper Methods
    
    // MARK: - State Restoration Implementation
    
    func saveNavigationState() {
        logger.info("Saving navigation state")
        
        // Convert navigation history to saveable format
        let navigationDestinations = navigationHistory.compactMap { NavigationDestination.from($0) }
        let unpopDestinations = unpopStack.compactMap { NavigationDestination.from($0) }
        
        // Convert main navigation path (we can't directly access NavigationPath contents)
        // For now, we'll use the navigationHistory as a proxy
        let mainNavDestinations = navigationDestinations
        
        // Convert sidebar path (similar approach)
        let sidebarDestinations: [NavigationDestination] = [] // TODO: Track sidebar navigation
        
        // Convert presented sheet
        let sheetState: PresentedSheetState?
        switch presentedSheet {
        case .search:
            sheetState = .search
        case .compose(let tab):
            sheetState = .compose(tab.rawValue)
        case .none:
            sheetState = nil
        }
        
        // Create navigation state (tab selection handled by @SceneStorage)
        let navigationState = NavigationState(
            selectedTab: "forums", // This is now handled by @SceneStorage
            isTabBarHidden: isTabBarHidden,
            mainNavigationPath: mainNavDestinations,
            sidebarNavigationPath: sidebarDestinations,
            presentedSheet: sheetState,
            navigationHistory: navigationDestinations,
            unpopStack: unpopDestinations,
            editStates: EditStates(
                isEditingBookmarks: false, // These are now handled by @SceneStorage
                isEditingMessages: false,
                isEditingForums: false
            ),
            interfaceVersion: NavigationState.currentInterfaceVersion
        )
        
        stateManager.saveNavigationState(navigationState)
    }
    
    func restoreNavigationState() {
        logger.info("Restoring navigation state")
        
        // Validate Core Data context is ready
        guard managedObjectContext.persistentStoreCoordinator != nil else {
            print("🔄 Core Data not ready for state restoration")
            return
        }
        
        guard let savedState = stateManager.restoreNavigationState() else {
            print("🔄 No saved navigation state to restore")
            return
        }
        
        // Set flag to prevent unpop system from reacting to path changes
        isRestoringState = true
        
        // Restore basic properties
        isTabBarHidden = savedState.isTabBarHidden
        
        // Restore navigation history
        navigationHistory = savedState.navigationHistory.compactMap { destination in
            destination.toNavigationObject(context: managedObjectContext)
        }
        
        // Restore unpop stack
        unpopStack = savedState.unpopStack.compactMap { destination in
            destination.toNavigationObject(context: managedObjectContext)
        }
        
        // Restore main navigation path
        path = NavigationPath()
        for destination in savedState.mainNavigationPath {
            if let navObject = destination.toNavigationObject(context: managedObjectContext) {
                path.append(navObject)
            }
        }
        
        // Restore sidebar navigation path
        sidebarPath = NavigationPath()
        for destination in savedState.sidebarNavigationPath {
            if let navObject = destination.toNavigationObject(context: managedObjectContext) {
                sidebarPath.append(navObject)
            }
        }
        
        // Restore presented sheet
        if let sheetState = savedState.presentedSheet {
            switch sheetState {
            case .search:
                presentedSheet = .search
            case .compose(let tabRawValue):
                if let tab = MainTab(rawValue: tabRawValue) {
                    presentedSheet = .compose(tab)
                }
            }
        }
        
        // Tab selection is now handled by @SceneStorage in MainView
        // No need to manually restore tab selection
        
        // Clear the restoration flag after a brief delay to ensure all path changes are processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isRestoringState = false
        }
        
        print("✅ Navigation state restored successfully")
    }
    
    // MARK: - SceneStorage Override for Navigation Restoration
    
    /// Saves navigation paths to Data for SceneStorage, bypassing SwiftUI's broken NavigationPath restoration
    func saveNavigationPathsToSceneStorage() -> (navigationPathData: Data, sidebarPathData: Data) {
        logger.info("🏪 Saving navigation paths to SceneStorage to bypass SwiftUI restoration bugs")
        
        // Convert navigation history to our own NavigationDestination format
        let mainNavDestinations = navigationHistory.compactMap { NavigationDestination.from($0) }
        let sidebarDestinations: [NavigationDestination] = [] // TODO: Track sidebar if needed
        
        // Debug: Log what pages we're saving
        for (index, destination) in mainNavDestinations.enumerated() {
            if case .thread(let threadID, let page, _, _) = destination {
                let pageDescription = String(describing: page)
                logger.info("🏪 SceneStorage Save [Index \(index)]: ThreadID \(threadID) with page \(pageDescription)")
            }
        }
        
        // Encode to Data
        var navigationData = Data()
        var sidebarData = Data()
        
        do {
            navigationData = try JSONEncoder().encode(mainNavDestinations)
            sidebarData = try JSONEncoder().encode(sidebarDestinations)
            logger.info("🏪 Successfully encoded \(mainNavDestinations.count) navigation destinations to SceneStorage")
        } catch {
            logger.error("❌ Failed to encode navigation paths for SceneStorage: \(error)")
        }
        
        return (navigationData, sidebarData)
    }
    
    /// Restores navigation paths from SceneStorage Data, bypassing SwiftUI's broken NavigationPath restoration
    func restoreNavigationPathsFromSceneStorage(navigationPathData: Data, sidebarPathData: Data, timestamp: Double) {
        logger.info("🏪 Restoring navigation paths from SceneStorage (timestamp: \(timestamp))")
        
        // Validate Core Data context is ready
        guard managedObjectContext.persistentStoreCoordinator != nil else {
            logger.warning("🔄 Core Data not ready for SceneStorage navigation restoration")
            return
        }
        
        // Check if the saved data is recent enough (within last 24 hours)
        let currentTime = Date().timeIntervalSince1970
        let maxAge: TimeInterval = 24 * 60 * 60 // 24 hours
        guard timestamp > 0 && (currentTime - timestamp) < maxAge else {
            logger.info("🏪 SceneStorage navigation data too old or invalid, skipping restoration")
            return
        }
        
        // Decode navigation destinations
        guard !navigationPathData.isEmpty else {
            logger.info("🏪 No navigation path data to restore from SceneStorage")
            return
        }
        
        do {
            let savedDestinations = try JSONDecoder().decode([NavigationDestination].self, from: navigationPathData)
            logger.info("🏪 Successfully decoded \(savedDestinations.count) navigation destinations from SceneStorage")
            
            // CRITICAL: Check if we're already displaying the correct content
            // If navigation state matches what's currently shown, skip restoration to prevent unnecessary navigation
            if navigationHistory.count == savedDestinations.count {
                var isIdenticalState = true
                
                for (index, savedDest) in savedDestinations.enumerated() {
                    if index < navigationHistory.count {
                        let currentObject = navigationHistory[index]
                        let savedObject = savedDest.toNavigationObject(context: managedObjectContext, viewStateStorage: viewStateStorage)
                        
                        // Compare ThreadDestinations specifically
                        if let currentThread = currentObject as? ThreadDestination,
                           let savedThread = savedObject as? ThreadDestination {
                            if currentThread.thread.threadID != savedThread.thread.threadID ||
                               currentThread.page != savedThread.page {
                                isIdenticalState = false
                                break
                            }
                        } else if currentObject != savedObject {
                            isIdenticalState = false
                            break
                        }
                    } else {
                        isIdenticalState = false
                        break
                    }
                }
                
                if isIdenticalState {
                    logger.info("🏪 Navigation state is already correct - skipping restoration to prevent unnecessary navigation")
                    return
                }
            }
            
            // Set flag to prevent unpop system from reacting to path changes
            isRestoringState = true
            
            // Clear current navigation state
            path = NavigationPath()
            navigationHistory.removeAll()
            
            // Rebuild NavigationPath with saved destinations
            for destination in savedDestinations {
                if let navObject = destination.toNavigationObject(context: managedObjectContext, viewStateStorage: viewStateStorage) {
                    path.append(navObject)
                    navigationHistory.append(navObject)
                    logger.info("🏪 Restored navigation destination successfully")
                } else {
                    logger.warning("⚠️ Failed to convert destination to navigation object")
                }
            }
            
            // Clear the restoration flag after processing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isRestoringState = false
            }
            
            logger.info("✅ SceneStorage navigation restoration completed with \(self.navigationHistory.count) destinations")
        } catch {
            logger.error("❌ Failed to decode navigation paths from SceneStorage: \(error)")
        }
    }
    
    // MARK: - Page Change Handling
    
    /// Handles notification when a thread's page changes (e.g., nextUnread -> specific(15))
    private func handleThreadPageDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let threadID = userInfo["threadID"] as? String,
              let newPage = userInfo["newPage"] as? ThreadPage else {
            logger.warning("⚠️ Invalid ThreadPageDidChange notification")
            return
        }
        
        let author = userInfo["author"] as? User
        
        logger.info("🔄 ThreadPageDidChange: threadID=\(threadID), newPage=\(String(describing: newPage))")
        
        // Update navigation state immediately to prevent stale nextUnread from being saved
        updateScrollPosition(for: threadID, page: newPage, author: author, scrollFraction: 0.0)
    }
    
    // MARK: - View State Management
    
    /// Saves comprehensive view state for a thread
    func saveViewState(for threadID: String, state: [String: Any]) {
        viewStateStorage[threadID] = state
        
        // Also persist to UserDefaults for app lifecycle restoration
        let key = "viewState_\(threadID)"
        UserDefaults.standard.set(state, forKey: key)
        
        print("💾 saveViewState: Saved state for thread \(threadID)")
    }
    
    /// Retrieves saved view state for a thread
    func getViewState(for threadID: String) -> [String: Any]? {
        // First try in-memory storage
        if let state = viewStateStorage[threadID] {
            print("📱 getViewState: Retrieved in-memory state for thread \(threadID)")
            return state
        }
        
        // Fall back to UserDefaults for app lifecycle restoration
        let key = "viewState_\(threadID)"
        if let state = UserDefaults.standard.object(forKey: key) as? [String: Any] {
            print("📱 getViewState: Retrieved persisted state for thread \(threadID)")
            // Cache in memory for future access
            viewStateStorage[threadID] = state
            return state
        }
        
        print("📱 getViewState: No saved state found for thread \(threadID)")
        return nil
    }
    
    /// Clears view state for a thread (useful for cleanup)
    func clearViewState(for threadID: String) {
        viewStateStorage.removeValue(forKey: threadID)
        let key = "viewState_\(threadID)"
        UserDefaults.standard.removeObject(forKey: key)
        print("🗑️ clearViewState: Cleared state for thread \(threadID)")
    }
    
    /// Clears all view states (useful for app reset or memory cleanup)
    func clearAllViewStates() {
        let threadIDs = Array(viewStateStorage.keys)
        viewStateStorage.removeAll()
        
        // Clear from UserDefaults
        for threadID in threadIDs {
            let key = "viewState_\(threadID)"
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        print("🗑️ clearAllViewStates: Cleared all view states")
    }
}

struct MainView: View {
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @SwiftUI.Environment(\.theme) private var theme
    
    // Use TabManager for proper tab state management
    @StateObject private var tabManager = TabManager()
    @SceneStorage("isEditingBookmarks") private var isEditingBookmarks = false
    @SceneStorage("isEditingMessages") private var isEditingMessages = false
    @SceneStorage("isEditingForums") private var isEditingForums = false
    
    // MARK: - SceneStorage Override for Navigation Restoration
    // These bypass SwiftUI's broken NavigationPath restoration system
    @SceneStorage("navigationPathData") private var navigationPathData: Data = Data()
    @SceneStorage("sidebarPathData") private var sidebarPathData: Data = Data()
    @SceneStorage("navigationStateTimestamp") private var navigationStateTimestamp: Double = 0
    
    @StateObject private var coordinator: MainCoordinatorImpl = {
        guard let appDelegate = AppDelegate.instance else {
            fatalError("AppDelegate.instance not available during coordinator initialization")
        }
        return MainCoordinatorImpl(managedObjectContext: appDelegate.managedObjectContext)
    }()
    @StateObject private var navigationGestureStateManager = NavigationGestureStateManager()
    @State private var hasFavoriteForums = false
    
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    
    // Add observer for favorite forums count changes
    @State private var favoriteForumCountObserver: ManagedObjectCountObserver?
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .onAppear {
            // Initialize tabManager with SceneStorage restored tab
            if let sceneStorageTab = UserDefaults.standard.object(forKey: "selectedTab") as? String,
               let restoredTab = MainTab(rawValue: sceneStorageTab) {
                tabManager.selectTab(restoredTab)
            }
            
            guard let appDelegate = AppDelegate.instance else {
                return
            }
            
            appDelegate.mainCoordinator = coordinator
            
            // Set up SceneStorage save callback for immediate updates
            coordinator.triggerSceneStorageSave = {
                // Trigger a save by posting a notification that MainView can observe
                NotificationCenter.default.post(name: Notification.Name("TriggerSceneStorageSave"), object: nil)
            }
            
            // Set up navigation state manager reference
            coordinator.navigationGestureStateManager = navigationGestureStateManager
            
            configureGlobalAppearance(theme: theme)
            updateStatusBarStyle(theme: theme)
            checkPrivateMessagePrivileges()
            checkFavoriteForums()
            
            // Delay state restoration to ensure Core Data is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Check if restoration should be suppressed due to recent user actions or Forums tab selection
                if !navigationGestureStateManager.shouldSuppressRestoration && tabManager.selectedTab != .forums {
                    // Use SceneStorage override instead of broken SwiftUI NavigationPath restoration
                    coordinator.restoreNavigationPathsFromSceneStorage(
                        navigationPathData: navigationPathData,
                        sidebarPathData: sidebarPathData,
                        timestamp: navigationStateTimestamp
                    )
                }
            }
        }
        .onDisappear {
            // Save navigation state to SceneStorage when view disappears
            saveNavigationStateToSceneStorage()
        }
        .onChange(of: theme) { newTheme in
            configureGlobalAppearance(theme: newTheme)
            updateStatusBarStyle(theme: newTheme)
        }
        .preferredColorScheme(theme[string: "statusBarBackground"] == "dark" ? .dark : .light)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CanSendPrivateMessagesDidChange"))) { _ in
            checkPrivateMessagePrivileges()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FavoriteForumsCountDidChange"))) { notification in
            if let count = notification.userInfo?["count"] as? Int {
                hasFavoriteForums = count > 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToTab"))) { notification in
            if let tab = notification.object as? MainTab {
                tabManager.selectTab(tab)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RestoreTabSelection"))) { notification in
            if let tab = notification.object as? MainTab {
                tabManager.selectTab(tab)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // Save state to SceneStorage when app enters background
            saveNavigationStateToSceneStorage()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Restore state from SceneStorage when app enters foreground with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Check if restoration should be suppressed due to recent user actions or Forums tab selection
                if !navigationGestureStateManager.shouldSuppressRestoration && tabManager.selectedTab != .forums {
                    coordinator.restoreNavigationPathsFromSceneStorage(
                        navigationPathData: navigationPathData,
                        sidebarPathData: sidebarPathData,
                        timestamp: navigationStateTimestamp
                    )
                } else {
                    print("🧭 Skipping foreground navigation restoration due to recent user action")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TriggerSceneStorageSave"))) { _ in
            // Save navigation state to SceneStorage when triggered by coordinator updates
            saveNavigationStateToSceneStorage()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UserNavigationActionDetected"))) { _ in
            // Clear SceneStorage navigation data when user manually navigates
            // This prevents SwiftUI's automatic restoration from interfering with user actions
            logger.info("🧭 Clearing SceneStorage navigation data due to user action")
            
            // Clear the stored navigation data so SwiftUI can't restore from it
            navigationPathData = Data()
            sidebarPathData = Data()
            navigationStateTimestamp = 0
            
            // Also clear the coordinator's unpop stack to prevent it from triggering restoration
            coordinator.unpopStack.removeAll()
            
            logger.info("🧭 SceneStorage navigation data cleared successfully")
            
            // DISABLED: Delayed force-clear is too aggressive - rely only on immediate detection
            // The immediate detection in the NavigationPath didSet should be sufficient
            // DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            //     if navigationGestureStateManager.shouldSuppressRestoration {
            //         logger.info("🛡️ Delayed check: Verifying no unwanted restoration occurred")
            //         if !coordinator.path.isEmpty {
            //             logger.warning("🛡️ DELAYED PRECISION CLEAR: Found unexpected navigation during suppression")
            //             coordinator.path = NavigationPath()
            //             coordinator.navigationHistory.removeAll()
            //         } else {
            //             logger.info("🛡️ ✅ No unwanted restoration detected - user navigation successful")
            //         }
            //     }
            // }
        }
    }
    
    // MARK: - iPad Layout
    private var iPadLayout: some View {
        iPadMainView(
            coordinator: coordinator,
            selectedTab: Binding(
                get: { tabManager.selectedTab },
                set: { tabManager.selectTab($0) }
            ),
            isEditingBookmarks: isEditingBookmarks,
            isEditingMessages: isEditingMessages,
            isEditingForums: isEditingForums,
            hasFavoriteForums: hasFavoriteForums,
            canSendPrivateMessages: canSendPrivateMessages
        )
        .environmentObject(tabManager)
        .sheet(item: $coordinator.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        .sheet(item: $coordinator.presentedPrivateMessageUser) { user in
            privateMessageSheetContent(for: user)
        }
    }

    // MARK: - iPhone Layout  
    private var iPhoneLayout: some View {
        Group {
            // Use custom navigation system instead of problematic NavigationStack
            AwfulCustomNavigationWrapper(
                coordinator: coordinator,
                selectedTab: Binding(
                    get: { tabManager.selectedTab },
                    set: { tabManager.selectTab($0) }
                ),
                hasFavoriteForums: hasFavoriteForums
            )
            .environmentObject(tabManager)
            .sheet(item: $coordinator.presentedSheet) { sheet in
                sheetContent(for: sheet)
            }
            .sheet(item: $coordinator.presentedPrivateMessageUser) { user in
                privateMessageSheetContent(for: user)
            }
        }
    }
    
    @ViewBuilder
    private func sheetContent(for sheet: MainCoordinatorImpl.PresentedSheet) -> some View {
        switch sheet {
        case .search:
            SearchHostingControllerWrapper()
        case .compose(_):
            MessageComposeViewRepresentable(coordinator: coordinator, isPresentedInSheet: true)
        }
    }
    
    @ViewBuilder
    private func privateMessageSheetContent(for identifiableUser: IdentifiableUser) -> some View {
        let composeVC: MessageComposeViewController = {
            let vc = MessageComposeViewController(recipient: identifiableUser.user)
            // Don't set delegate - let it handle its own dismissal
            print("🔗 MainView: Created MessageComposeViewController without delegate")
            return vc
        }()
        
        MessageComposeView(
            messageComposeViewController: composeVC,
            onDismiss: {
                coordinator.presentedPrivateMessageUser = nil
            }
        )
        .environment(\.theme, theme)
    }
    
    
    private func updateStatusBarStyle(theme: Theme) {
        // Update status bar style based on theme
        let statusBarBackground = theme[string: "statusBarBackground"] ?? "dark"
        let shouldUseLightContent = statusBarBackground == "dark"
        
        // Update the global status bar style
        StatusBarStyleManager.shared.updateStyle(lightContent: shouldUseLightContent)
    }

    
    private func configureGlobalAppearance(theme: Theme) {
        // Use the provided theme
        let currentTheme = theme
        
        // Configure navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = currentTheme[uicolor: "navigationBarTintColor"] ?? UIColor.systemBackground
        navAppearance.shadowColor = currentTheme[uicolor: "bottomBarTopBorderColor"]
        
        let textColor = currentTheme[uicolor: "navigationBarTextColor"] ?? UIColor.label
        navAppearance.titleTextAttributes = [
            .foregroundColor: textColor,
            .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: textColor,
            .font: UIFont.preferredFontForTextStyle(.largeTitle, fontName: nil, sizeAdjustment: 0, weight: .semibold)
        ]
        
        // Configure back button to use arrow image instead of text
        let backImage = UIImage(named: "back")?.withRenderingMode(.alwaysTemplate)
        navAppearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
        
        // Hide back button text completely by making it transparent and zero-sized
        navAppearance.backButtonAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.clear,
            .font: UIFont.systemFont(ofSize: 0)
        ]
        navAppearance.backButtonAppearance.highlighted.titleTextAttributes = [
            .foregroundColor: UIColor.clear,
            .font: UIFont.systemFont(ofSize: 0)
        ]
        navAppearance.backButtonAppearance.disabled.titleTextAttributes = [
            .foregroundColor: UIColor.clear,
            .font: UIFont.systemFont(ofSize: 0)
        ]
        navAppearance.backButtonAppearance.focused.titleTextAttributes = [
            .foregroundColor: UIColor.clear,
            .font: UIFont.systemFont(ofSize: 0)
        ]
        
        // Also set the title position to be off-screen to ensure it doesn't show
        navAppearance.backButtonAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: -1000, vertical: 0)
        navAppearance.backButtonAppearance.highlighted.titlePositionAdjustment = UIOffset(horizontal: -1000, vertical: 0)
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = currentTheme[uicolor: "navigationBarTextColor"] ?? UIColor.label
        UINavigationBar.appearance().isTranslucent = false
        UINavigationBar.appearance().compactScrollEdgeAppearance = navAppearance
        
        // Force all bar button items to use theme color
        UIBarButtonItem.appearance().tintColor = currentTheme[uicolor: "navigationBarTextColor"] ?? UIColor.label
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UINavigationBar.self]).tintColor = currentTheme[uicolor: "navigationBarTextColor"] ?? UIColor.label
        
        // Force update all existing navigation bars
        DispatchQueue.main.async {
            for window in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }) {
                for view in window.subviews {
                    if let navBar = view as? UINavigationBar {
                        navBar.standardAppearance = navAppearance
                        navBar.scrollEdgeAppearance = navAppearance
                        navBar.compactAppearance = navAppearance
                        navBar.tintColor = currentTheme[uicolor: "navigationBarTextColor"] ?? UIColor.label
                        navBar.setNeedsLayout()
                    }
                }
            }
        }
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = currentTheme[uicolor: "tabBarBackgroundColor"]
        tabBarAppearance.shadowColor = currentTheme[uicolor: "tabBarTopBorderColor"]
        
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithOpaqueBackground()
        toolbarAppearance.backgroundColor = currentTheme[uicolor: "tabBarBackgroundColor"]
        
        UIToolbar.appearance().standardAppearance = toolbarAppearance

        UIToolbar.appearance().scrollEdgeAppearance = toolbarAppearance
        
        // For selected and unselected items
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = currentTheme[uicolor: "tabBarIconNormalColor"]
        itemAppearance.selected.iconColor = currentTheme[uicolor: "tabBarIconSelectedColor"]
        
        // Handle tab bar labels based on theme setting
        if currentTheme[bool: "showRootTabBarLabel"] == false {
            // Hide labels by making them transparent and adjusting icon position
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.clear]
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        } else {
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: currentTheme[uicolor: "tabBarIconSelectedColor"]!]
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: currentTheme[uicolor: "tabBarIconNormalColor"]!]
        }
        
        tabBarAppearance.inlineLayoutAppearance = itemAppearance
        tabBarAppearance.stackedLayoutAppearance = itemAppearance
        tabBarAppearance.compactInlineLayoutAppearance = itemAppearance
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = currentTheme[uicolor: "tabBarIconSelectedColor"]
        UITabBar.appearance().isTranslucent = currentTheme[bool: "tabBarIsTranslucent"] ?? true
        
        // Force immediate update of all visible tab bars and navigation bars
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                // Force update of all tab bars in the window hierarchy
                func updateTabBars(in view: UIView) {
                    if let tabBar = view as? UITabBar {
                        tabBar.standardAppearance = tabBarAppearance
                        tabBar.scrollEdgeAppearance = tabBarAppearance
                        tabBar.tintColor = currentTheme[uicolor: "tabBarIconSelectedColor"]
                        tabBar.setNeedsLayout()
                        tabBar.setNeedsDisplay()
                    }
                    view.subviews.forEach(updateTabBars)
                }
                updateTabBars(in: window)
                
                // Force update of all navigation bars in the window hierarchy
                window.subviews.forEach { view in
                    if let navigationBar = view as? UINavigationBar {
                        navigationBar.standardAppearance = navAppearance
                        navigationBar.scrollEdgeAppearance = navAppearance
                        navigationBar.compactAppearance = navAppearance
                        navigationBar.tintColor = textColor
                        navigationBar.setNeedsLayout()
                    }
                }
                
                // Also search deeper in the view hierarchy
                func updateNavigationBars(in view: UIView) {
                    if let navigationBar = view as? UINavigationBar {
                        navigationBar.standardAppearance = navAppearance
                        navigationBar.scrollEdgeAppearance = navAppearance
                        navigationBar.compactAppearance = navAppearance
                        navigationBar.tintColor = textColor
                        navigationBar.setNeedsLayout()
                    }
                    view.subviews.forEach(updateNavigationBars)
                }
                
                updateNavigationBars(in: window)
            }
        }
    }
    
    private func checkPrivateMessagePrivileges() {
        // Only check if we're logged in and don't already have PM privileges
        guard ForumsClient.shared.isLoggedIn && !canSendPrivateMessages else { return }
        
        Task<Void, Never>.detached(priority: .utility) {
            do {
                // Try to fetch the current user's profile to check PM privileges
                if let userID = FoilDefaultStorageOptional(Settings.userID).wrappedValue {
                    let profile = try await ForumsClient.shared.profileUser(.userID(userID))
                    let canReceivePMs = profile.user.canReceivePrivateMessages
                    
                    await MainActor.run {
                        let currentValue = UserDefaults.standard.bool(forKey: Settings.canSendPrivateMessages.key)
                        if canReceivePMs != currentValue {
                            UserDefaults.standard.set(canReceivePMs, forKey: Settings.canSendPrivateMessages.key)
                            print("🔍 Updated canSendPrivateMessages to: \(canReceivePMs)")
                            // Notify SwiftUI views that the setting has changed
                            NotificationCenter.default.post(name: Notification.Name("CanSendPrivateMessagesDidChange"), object: nil)
                        }
                    }
                } else if let username = FoilDefaultStorageOptional(Settings.username).wrappedValue {
                    let profile = try await ForumsClient.shared.profileUser(.username(username))
                    let canReceivePMs = profile.user.canReceivePrivateMessages
                    
                    await MainActor.run {
                        let currentValue = UserDefaults.standard.bool(forKey: Settings.canSendPrivateMessages.key)
                        if canReceivePMs != currentValue {
                            UserDefaults.standard.set(canReceivePMs, forKey: Settings.canSendPrivateMessages.key)
                            print("🔍 Updated canSendPrivateMessages to: \(canReceivePMs)")
                            // Notify SwiftUI views that the setting has changed
                            NotificationCenter.default.post(name: Notification.Name("CanSendPrivateMessagesDidChange"), object: nil)
                        }
                    }
                }
            } catch {
                print("⚠️ Failed to check private message privileges: \(error)")
            }
        }
    }
    
    private func checkFavoriteForums() {
        // Set up observer for favorite forums count changes
        guard let context = AppDelegate.instance?.managedObjectContext else {
            print("❌ AppDelegate.instance or managedObjectContext not available for checkFavoriteForums")
            return
        }
        
        favoriteForumCountObserver = ManagedObjectCountObserver(
            context: context,
            entityName: ForumMetadata.entityName,
            predicate: NSPredicate(format: "%K == YES", #keyPath(ForumMetadata.favorite)),
            didChange: { favoriteCount in
                // Update hasFavoriteForums state when favorite forums count changes
                NotificationCenter.default.post(
                    name: Notification.Name("FavoriteForumsCountDidChange"), 
                    object: nil, 
                    userInfo: ["count": favoriteCount]
                )
            }
        )
        
        // Set initial state
        hasFavoriteForums = favoriteForumCountObserver?.count ?? 0 > 0
    }
    
    // MARK: - SceneStorage Helper
    
    /// Saves navigation state to SceneStorage to bypass SwiftUI's broken NavigationPath restoration
    private func saveNavigationStateToSceneStorage() {
        let (navData, sidebarData) = coordinator.saveNavigationPathsToSceneStorage()
        navigationPathData = navData
        sidebarPathData = sidebarData
        navigationStateTimestamp = Date().timeIntervalSince1970
    }
}


enum MainTab: String, CaseIterable, Identifiable {
    case forums = "Forums"
    case bookmarks = "Bookmarks"
    case messages = "Messages"
    case lepers = "Lepers"
    case settings = "Settings"
    
    var title: String {
        switch self {
        case .forums: return "Forums"
        case .bookmarks: return "Bookmarks"
        case .messages: return "Messages"
        case .lepers: return "Lepers"
        case .settings: return "Settings"
        }
    }
    
    var systemImage: String {
        switch self {
        case .forums: return "list.bullet"
        case .bookmarks: return "bookmark"
        case .messages: return "envelope"
        case .lepers: return "exclamationmark.triangle"
        case .settings: return "gear"
        }
    }
    
    // Original image assets from the UIKit implementation with proper template rendering
    var tabBarImage: String? {
        switch self {
        case .forums: return "forum-list"
        case .bookmarks: return "bookmarks"
        case .messages: return "pm-icon"
        case .lepers: return "lepers"
        case .settings: return "cog"
        }
    }
    
    var id: String { rawValue }
    
    static func allCases(canSendPrivateMessages: Bool) -> [MainTab] {
        var tabs: [MainTab] = [.forums, .bookmarks]
        
        if canSendPrivateMessages {
            tabs.append(.messages)
        }
        tabs.append(contentsOf: [.lepers, .settings])
        return tabs
    }
}

// MARK: - Detail View

private struct DetailView: View {
    @EnvironmentObject var coordinator: MainCoordinatorImpl

    var body: some View {
        // Show a placeholder view until something is selected to be shown in detail
        VStack {
            Spacer()
            Text("Select an item from the sidebar")
                .foregroundColor(.secondary)
                .font(.title2)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.defaultTheme()[color: "backgroundColor"]!)
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ThreadDestination.self) { destination in
            Group {
                let _ = print("🔵 DetailView: navigationDestination triggered for thread: \(destination.thread.title ?? "Unknown"), scrollFraction: \(destination.scrollFraction?.description ?? "none"), jumpToPostID: \(destination.jumpToPostID ?? "none")")
                PostsViewWrapper(
                    thread: destination.thread,
                    author: destination.author,
                    page: destination.page,
                    scrollFraction: destination.scrollFraction,
                    jumpToPostID: destination.jumpToPostID,
                    coordinator: coordinator
                )
            }
        }
        .navigationDestination(for: Forum.self) { forum in
            Group {
                let _ = print("🔵 NavigationDestination triggered for Forum: \(forum.name ?? "unnamed")")
                if let managedObjectContext = AppDelegate.instance?.managedObjectContext {
                    SwiftUIThreadsView(
                        forum: forum,
                        managedObjectContext: managedObjectContext,
                        coordinator: coordinator
                    )
                } else {
                    Text("Error: Managed Object Context not available")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationDestination(for: ComposePrivateMessage.self) { _ in
            MessageComposeDetailView(coordinator: coordinator)
        }
    }
}

// Replacement for TabContentView to use standard SwiftUI navigation
struct TabContentView: View {
    let tab: MainTab
    let coordinator: any MainCoordinator
    let isEditing: Bool
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    @SwiftUI.Environment(\.theme) private var theme

    var body: some View {
        contentView
            .background(theme[color: "backgroundColor"]!)
    }
    
    @ViewBuilder
    private var contentView: some View {
        if coordinator is MainCoordinatorImpl {
            // Use NavigationStack only for tabs that need standard SwiftUI navigation
            // Forums tab uses custom navigation, so no NavigationStack needed
            Group {
                if tab == .forums {
                    // Forums tab uses custom navigation - no NavigationStack
                    tabContent
                } else if tab == .messages {
                    // Messages tab uses modal presentation - no NavigationStack needed
                    tabContent
                } else {
                    // Other tabs don't need NavigationStack - no empty toolbar space
                    tabContent
                }
            }
        } else {
            Text("Error: Invalid coordinator type")
                .foregroundColor(.red)
        }
    }
    
    @ViewBuilder
    private var tabContent: some View {
        Group {
                    switch tab {
                    case .forums:
                        if let managedObjectContext = AppDelegate.instance?.managedObjectContext {
                            SwiftUIForumsView(
                                managedObjectContext: managedObjectContext,
                                coordinator: coordinator,
                                isEditing: isEditing
                            )
                        } else {
                            Text("Error: Managed Object Context not available")
                                .foregroundColor(.red)
                                .font(.headline)
                        }
                    case .bookmarks:
                        if let managedObjectContext = AppDelegate.instance?.managedObjectContext {
                            SwiftUIBookmarksView(
                                managedObjectContext: managedObjectContext,
                                coordinator: coordinator
                            )
                        } else {
                            Text("Error: Managed Object Context not available")
                                .foregroundColor(.red)
                                .font(.headline)
                        }
                    case .messages:
                        SwiftUIMessagesView(isEditing: isEditing, coordinator: coordinator)
                    case .lepers:
                        SwiftUILepersView(coordinator: coordinator)
                    case .settings:
                        SwiftUISettingsView()
                    }
                }
    }
}

// MARK: - UIViewControllerRepresentable wrappers for existing UIKit view controllers

struct ForumsViewRepresentable: View {
    var isEditing: Bool
    let coordinator: any MainCoordinator

    var body: some View {
        Group {
            if let managedObjectContext = AppDelegate.instance?.managedObjectContext {
                SwiftUIForumsView(managedObjectContext: managedObjectContext, coordinator: coordinator, isEditing: isEditing)
            } else {
                Text("Error: Could not access managed object context")
                    .foregroundColor(.red)
            }
        }
    }
}


struct ThreadDestination: Hashable {
    let thread: AwfulThread
    let page: ThreadPage
    let author: User?
    let scrollFraction: CGFloat?
    let jumpToPostID: String?
    
    init(thread: AwfulThread, page: ThreadPage, author: User?, scrollFraction: CGFloat? = nil, jumpToPostID: String? = nil) {
        self.thread = thread
        self.page = page
        self.author = author
        self.scrollFraction = scrollFraction
        self.jumpToPostID = jumpToPostID
        print("🔵 ThreadDestination: Created for thread: \(thread.title ?? "Unknown"), page: \(page), scrollFraction: \(scrollFraction?.description ?? "none"), jumpToPostID: \(jumpToPostID ?? "none")")
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(thread)
        hasher.combine(page)
        hasher.combine(author)
        hasher.combine(scrollFraction)
        hasher.combine(jumpToPostID)
    }
    
    static func == (lhs: ThreadDestination, rhs: ThreadDestination) -> Bool {
        return lhs.thread == rhs.thread &&
               lhs.page == rhs.page &&
               lhs.author == rhs.author &&
               lhs.scrollFraction == rhs.scrollFraction &&
               lhs.jumpToPostID == rhs.jumpToPostID
    }
}

struct PrivateMessageDestination: Hashable {
    let message: PrivateMessage
    
    init(message: PrivateMessage) {
        self.message = message
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(message.messageID)
    }
    
    static func == (lhs: PrivateMessageDestination, rhs: PrivateMessageDestination) -> Bool {
        return lhs.message.messageID == rhs.message.messageID
    }
}

struct SwiftUIMessagesView: View {
    var isEditing: Bool
    let coordinator: any MainCoordinator
    @SwiftUI.Environment(\.theme) private var theme
    
    init(isEditing: Bool, coordinator: any MainCoordinator) {
        self.isEditing = isEditing
        self.coordinator = coordinator
    }
    
    var body: some View {
        Group {
            if let managedObjectContext = AppDelegate.instance?.managedObjectContext {
                SwiftUIMessageListView(
                    managedObjectContext: managedObjectContext,
                    coordinator: coordinator
                )
            } else {
                Text("Error: Managed Object Context not available")
                    .foregroundColor(.red)
                    .font(.headline)
            }
        }
        .themed()
    }
}

struct MessagesViewRepresentable: UIViewControllerRepresentable {
    var isEditing: Bool
    let coordinator: any MainCoordinator

    func makeUIViewController(context: Context) -> UIViewController {
        guard let managedObjectContext = AppDelegate.instance?.managedObjectContext else {
            fatalError("AppDelegate.instance or managedObjectContext not available")
        }
        let messagesVC = MessageListViewController(managedObjectContext: managedObjectContext)
        messagesVC.coordinator = coordinator
        
        // Embed in a navigation controller to support push navigation
        let navController = UINavigationController(rootViewController: messagesVC)
        
        // Hide navigation bar initially for the messages list (we use custom header)
        // But it will be shown when MessageViewController is pushed
        navController.setNavigationBarHidden(true, animated: false)
        
        let wrapper = SwiftUICompatibleViewController(wrapping: navController)
        wrapper.restorationIdentifier = "Messages"
        
        return wrapper
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let wrapper = uiViewController as? SwiftUICompatibleViewController else { return }
        
        // Try to find the navigation controller through the child view controllers
        if let navController = wrapper.children.first as? UINavigationController,
           let messagesVC = navController.viewControllers.first as? MessageListViewController {
            print("🔵 MessagesViewRepresentable: Setting editing state to \(isEditing)")
            messagesVC.setEditing(isEditing, animated: true)
        } else {
            // Fallback: let the wrapper handle it (it forwards setEditing calls)
            print("🔵 MessagesViewRepresentable: Using wrapper setEditing fallback")
            wrapper.setEditing(isEditing, animated: true)
        }
    }
}

struct SwiftUILepersView: View {
    let coordinator: any MainCoordinator
    @SwiftUI.Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationHeaderView(title: "Lepers")
            
            // UIKit Lepers view
            LepersViewRepresentable(coordinator: coordinator)
        }
        .themed()
    }
}

struct LepersViewRepresentable: UIViewControllerRepresentable {
    let coordinator: any MainCoordinator

    func makeUIViewController(context: Context) -> UIViewController {
        let lepersVC = RapSheetViewController()
        let wrapper = SwiftUICompatibleViewController(wrapping: lepersVC)
        wrapper.restorationIdentifier = "Leper's Colony"
        return wrapper
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Theme changes are handled automatically by the wrapper's observer
    }
}

struct SwiftUISettingsView: View {
    @SwiftUI.Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationHeaderView(title: "Settings")
            
            // Pure SwiftUI Settings view
            PureSwiftUISettingsView()
        }
        .themed()
    }
}

struct PureSwiftUISettingsView: View {
    
    var body: some View {
        Group {
            if let currentUser = getCurrentUser() {
                LoggedInSettingsSwiftUI(currentUser: currentUser)
            } else {
                Text("Not Logged In")
            }
        }
    }
    
    private func getCurrentUser() -> User? {
        guard let managedObjectContext = AppDelegate.instance?.managedObjectContext else {
            return nil
        }
        
        return managedObjectContext.performAndWait {
            guard let userID = UserDefaults.standard.value(for: Settings.userID) else {
                return nil
            }
            return User.objectForKey(objectKey: UserKey(
                userID: userID,
                username: UserDefaults.standard.value(for: Settings.username)
            ), in: managedObjectContext)
        }
    }
}

struct LoggedInSettingsSwiftUI: View {
    @ObservedObject var currentUser: User
    
    var body: some View {
        Group {
            if let managedObjectContext = AppDelegate.instance?.managedObjectContext {
                SettingsView(
                    appIconDataSource: makeMainViewAppIconDataSource(),
                    avatarURL: currentUser.avatarURL,
                    canOpenURL: UIApplication.shared.canOpenURL(_:),
                    currentUsername: currentUser.username ?? "",
                    emptyCache: { AppDelegate.instance.emptyCache() },
                    goToAwfulThread: { AppDelegate.instance.open(route: .threadPage(threadID: "3837546", page: .nextUnread, .seen)) },
                    hasRegularSizeClassInLandscape: UIDevice.current.userInterfaceIdiom == .pad || UIScreen.main.scale > 2,
                    isMac: ProcessInfo.processInfo.isMacCatalystApp,
                    isPad: UIDevice.current.userInterfaceIdiom == .pad,
                    logOut: { AppDelegate.instance.logOut() }
                )
                .environment(\.managedObjectContext, managedObjectContext)
            } else {
                Text("Error: Could not access managed object context")
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - App Icon Support

/// See the `README.md` section "Alternate App Icons" for more info.
private let mainViewAppIcons: [AppIconDataSource.AppIcon] = [
    .init(accessibilityLabel: "rated_five", imageName: "rated_five"),
    .init(accessibilityLabel: "rated_five_pride", imageName: "rated_five_pride"),
    .init(accessibilityLabel: "rated_five_trans", imageName: "rated_five_trans"),
    .init(accessibilityLabel: "v", imageName: "v"),
    .init(accessibilityLabel: "ghost_blue", imageName: "ghost_blue"),
    .init(accessibilityLabel: "froggo", imageName: "froggo"),
    .init(accessibilityLabel: "froggo_purple", imageName: "froggo_purple"),
    .init(accessibilityLabel: "staredog", imageName: "staredog"),
    .init(accessibilityLabel: "staredog_tongue", imageName: "staredog_tongue"),
    .init(accessibilityLabel: "five", imageName: "five"),
    .init(accessibilityLabel: "greenface", imageName: "greenface"),
    .init(accessibilityLabel: "riker", imageName: "riker"),
    .init(accessibilityLabel: "smith", imageName: "smith"),
]

@MainActor private func makeMainViewAppIconDataSource() -> AppIconDataSource {
    let selectedIconName = UIApplication.shared.alternateIconName
    let selected = mainViewAppIcons.first { "\($0.imageName)_appicon" == selectedIconName } ?? mainViewAppIcons.first!
    return AppIconDataSource(
        appIcons: mainViewAppIcons,
        imageLoader: { Image("\($0.imageName)_appicon_preview", bundle: .main) },
        selected: selected,
        setter: {
            let iconName = $0 == mainViewAppIcons.first ? nil : "\($0.imageName)_appicon"
            try await UIApplication.shared.setAlternateIconName(iconName)
        }
    )
}

// MARK: - Detail Navigation Destinations



struct PostsViewWrapper: View {
    let thread: AwfulThread
    let author: User?
    let page: ThreadPage
    let scrollFraction: CGFloat?
    let jumpToPostID: String?
    var coordinator: (any MainCoordinator)?
    @StateObject private var viewModel = PostsViewModel()
    @SwiftUI.Environment(\.theme) private var theme
    @State private var title: String
    
    private var navigationTintColor: Color {
        Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label)
    }
    
    init(thread: AwfulThread, author: User?, page: ThreadPage, scrollFraction: CGFloat? = nil, jumpToPostID: String? = nil, coordinator: (any MainCoordinator)?) {
        self.thread = thread
        self.author = author
        self.page = page
        self.scrollFraction = scrollFraction
        self.jumpToPostID = jumpToPostID
        self.coordinator = coordinator
        _title = State(initialValue: thread.title ?? "")
    }
    
    var body: some View {
        // Always use SwiftUI posts view
        NavigationStack {
            SwiftUIPostsPageView(
                thread: thread,
                author: author,
                page: page,
                coordinator: coordinator,
                scrollFraction: scrollFraction,
                jumpToPostID: jumpToPostID
            )
        }
        .background(Color.clear)
    }
}

struct PostsViewControllerRepresentable: UIViewControllerRepresentable {
    let thread: AwfulThread
    let page: ThreadPage
    let author: User?
    var coordinator: (any MainCoordinator)?
    @ObservedObject var viewModel: PostsViewModel
    
    func makeUIViewController(context: Context) -> PostsPageViewController {
        let vc = PostsPageViewController(thread: thread, author: author)
        vc.coordinator = coordinator
        
        print("🔵 PostsViewControllerRepresentable: Creating with page: \(page)")
        
        // Set up the view model connection before loading the page
        // This ensures the initial page state is properly captured
        viewModel.setViewController(vc)
        
        // Load the page after the view model is connected
        vc.loadPage(page, updatingCache: true, updatingLastReadPost: true)
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: PostsPageViewController, context: Context) {
        // Keep the view controller updated with the latest state from SwiftUI
        uiViewController.coordinator = coordinator
    }
}

struct MessageViewRepresentable: UIViewControllerRepresentable {
    let message: PrivateMessage
    let coordinator: any MainCoordinator

    func makeUIViewController(context: Context) -> UIViewController {
        let messageVC = MessageViewController(privateMessage: message)
        let wrapper = SwiftUICompatibleViewController(wrapping: messageVC)
        wrapper.restorationIdentifier = "Message"
        return wrapper
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Theme changes are handled automatically by the wrapper's observer
    }
}

struct ComposePrivateMessage: Hashable, Identifiable {
    var id: String { "compose-pm" }
}

struct MessageComposeViewRepresentable: UIViewControllerRepresentable {
    let coordinator: MainCoordinatorImpl
    let isPresentedInSheet: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        let composeVC = MessageComposeViewController()
        composeVC.delegate = coordinator
        
        if isPresentedInSheet {
            return composeVC.enclosingNavigationController
        } else {
            // Register the compose view controller with the coordinator for toolbar interactions
            coordinator.setCurrentComposeViewController(composeVC)
            let wrapper = SwiftUICompatibleViewController(wrapping: composeVC)
            wrapper.restorationIdentifier = "Compose"
            return wrapper
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - Sheet Safe Navigation Controller
class SheetSafeNavigationController: UINavigationController {
    var onDismissAttempt: (() -> Void)?
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        // Prevent UIKit dismissal, call SwiftUI dismissal instead
        print("🔗 SheetSafeNavigationController: Preventing UIKit dismissal, calling SwiftUI onDismiss")
        onDismissAttempt?()
        completion?()
    }
}

// MARK: - MessageComposeView
struct MessageComposeView: UIViewControllerRepresentable {
    let messageComposeViewController: MessageComposeViewController
    let onDismiss: () -> Void
    
    @SwiftUI.Environment(\.theme) private var theme
    
    func makeUIViewController(context: Context) -> UIViewController {
        // Create a custom navigation controller that prevents dismiss
        let navController = SheetSafeNavigationController(rootViewController: messageComposeViewController)
        navController.modalPresentationStyle = messageComposeViewController.enclosingNavigationController.modalPresentationStyle
        navController.onDismissAttempt = onDismiss
        
        // Apply theme to the navigation controller and its content (exactly like ReplyWorkspaceView)
        applyTheme(to: navController)
        
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update theme if needed
        applyTheme(to: uiViewController)
    }
    
    private func applyTheme(to viewController: UIViewController) {
        // Apply theme to navigation controller (exactly like ReplyWorkspaceView)
        if let navController = viewController as? UINavigationController {
            navController.view.backgroundColor = theme[uicolor: "backgroundColor"]
            navController.navigationBar.barTintColor = theme[uicolor: "navigationBarTintColor"]
            navController.navigationBar.tintColor = theme[uicolor: "navigationBarTextColor"]
            navController.navigationBar.titleTextAttributes = [
                .foregroundColor: theme[uicolor: "navigationBarTextColor"] ?? UIColor.label
            ]
            
            // Apply theme to the message compose view controller
            if let composeVC = navController.topViewController as? MessageComposeViewController {
                composeVC.themeDidChange()
            }
        }
        
        // Apply theme if it's a themed view controller
        if let themedViewController = viewController as? ViewController {
            themedViewController.themeDidChange()
        }
    }
}

// MARK: - Search Hosting Controller

struct SearchHostingControllerWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let searchViewController = SearchHostingController() // Use the existing class from SearchView.swift
        searchViewController.restorationIdentifier = "Search view"
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            searchViewController.modalPresentationStyle = .pageSheet
        } else {
            searchViewController.modalPresentationStyle = .fullScreen
        }
        
        return searchViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

class StatusBarStyleManager: ObservableObject {
    static let shared = StatusBarStyleManager()
    
    @Published var shouldUseLightContent = false
    
    private init() {}
    
    func updateStyle(lightContent: Bool) {
        shouldUseLightContent = lightContent
        // Status bar style is now handled by SwiftUI's preferredColorScheme
        // No need for custom view controller wrapping
    }
}


// MARK: - SwiftUI Compatible View Controllers

/// A container view controller that wraps UIKit view controllers and maintains clear backgrounds for SwiftUI integration
private class SwiftUICompatibleViewController: UIViewController {
    private let wrappedViewController: UIViewController
    
    init(wrapping viewController: UIViewController) {
        self.wrappedViewController = viewController
        super.init(nibName: nil, bundle: nil)
        
        // Configure the wrapped view controller for SwiftUI integration
        viewController.configureForSwiftUINavigationStack()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        // Create a container view
        view = UIView()
        view.backgroundColor = .clear
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Properly add the wrapped view controller as a child
        addChild(wrappedViewController)
        view.addSubview(wrappedViewController.view)
        wrappedViewController.view.frame = view.bounds
        wrappedViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wrappedViewController.didMove(toParent: self)
        
        
        // Initial background setup
        wrappedViewController.maintainSwiftUICompatibleBackground()
    }
    
    
    // Forward restoration identifier
    override var restorationIdentifier: String? {
        get { wrappedViewController.restorationIdentifier }
        set { wrappedViewController.restorationIdentifier = newValue }
    }
    
    // Forward editing methods for table view controllers
    override func setEditing(_ editing: Bool, animated: Bool) {
        print("🔵 SwiftUICompatibleViewController: setEditing(\(editing)) called, forwarding to \(type(of: wrappedViewController))")
        super.setEditing(editing, animated: animated)
        wrappedViewController.setEditing(editing, animated: animated)
        print("🔵 SwiftUICompatibleViewController: Wrapped controller isEditing = \(wrappedViewController.isEditing)")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UIKit Integration Helpers

/// Extension to configure UIKit view controllers for proper SwiftUI NavigationStack integration
private extension UIViewController {
    
    /// Configures the view controller to work properly within SwiftUI NavigationStack
    /// This prevents the white bar issue by ensuring proper layout and background handling
    func configureForSwiftUINavigationStack() {
        // Allow the view to extend under navigation bars
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = .all
        additionalSafeAreaInsets = .zero
        
        // Use modern content inset adjustment behavior instead of deprecated property
        if let scrollView = findScrollView() {
            scrollView.contentInsetAdjustmentBehavior = .automatic
        }
        
        // Set transparent background to let SwiftUI background show through
        view.backgroundColor = .clear
        
        // If this is a table view controller, also configure the table view
        if let tableViewController = self as? UITableViewController {
            tableViewController.tableView.backgroundColor = .clear
            tableViewController.tableView.contentInsetAdjustmentBehavior = .automatic
        }
    }
    
    /// Helper method to find the main scroll view in the view hierarchy
    private func findScrollView() -> UIScrollView? {
        // Check if the main view is a scroll view
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        
        // Recursively search for scroll views in subviews
        return view.subviews.compactMap { $0 as? UIScrollView }.first
    }
    
    /// Ensures the background remains clear after theme changes
    /// This must be called AFTER the original themeDidChange() to override theme-based background colors
    func maintainClearBackground() {
        maintainSwiftUICompatibleBackground()
    }
    
    /// Maintains clear backgrounds for SwiftUI compatibility
    func maintainSwiftUICompatibleBackground() {
        // Force clear background to override any theme-based background colors
        view.backgroundColor = .clear
        
        // Also maintain clear background for table views and their components
        if let tableViewController = self as? UITableViewController {
            tableViewController.tableView.backgroundColor = .clear
            
            // Also clear any footer view backgrounds that might show white
            tableViewController.tableView.tableFooterView?.backgroundColor = .clear
            
            // Handle pull-to-refresh views that might have theme backgrounds
            for subview in tableViewController.tableView.subviews {
                if subview.className.contains("Refresh") {
                    subview.backgroundColor = .clear
                }
            }
        }
        
        // Clear any scroll view backgrounds
        if let scrollView = findScrollView() {
            scrollView.backgroundColor = .clear
        }
    }
}

// MARK: - Helper Extensions

private extension NSObject {
    var className: String {
        return String(describing: type(of: self))
    }
}

// MARK: - Detail Navigation Destinations

struct MessageComposeDetailView: View {
    let coordinator: MainCoordinatorImpl
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.theme) private var theme
    @State private var navigationTintColor = Color.blue // Initialize with default, update in onAppear
    
    var body: some View {
        MessageComposeViewRepresentable(coordinator: coordinator, isPresentedInSheet: false)
            .navigationTitle("Private Message")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        coordinator.cancelCurrentComposition()
                    }
                    .foregroundColor(navigationTintColor)
                    .foregroundColor(navigationTintColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        coordinator.submitCurrentComposition()
                    }
                    .foregroundColor(navigationTintColor)
                    .foregroundColor(navigationTintColor)
                }
            }
            .onAppear {
                updateNavigationTintColor()
            }
    }
    
    private func updateNavigationTintColor() {
        navigationTintColor = Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label)
    }
}

// MARK: - iPad Main View
struct iPadMainView: View {
    @ObservedObject var coordinator: MainCoordinatorImpl
    @Binding var selectedTab: MainTab
    let isEditingBookmarks: Bool
    let isEditingMessages: Bool
    let isEditingForums: Bool
    let hasFavoriteForums: Bool
    let canSendPrivateMessages: Bool
    @SwiftUI.Environment(\.theme) private var theme
    
    // Computed property for navigation tint color based on theme
    private var navigationTintColor: Color {
        Color(theme[uicolor: "navigationBarTextColor"] ?? .label)
    }

    var body: some View {
        NavigationSplitView {
            TabView(selection: $selectedTab) {
                ForEach(MainTab.allCases(canSendPrivateMessages: canSendPrivateMessages)) { tab in
                    TabContentView(tab: tab, coordinator: coordinator, isEditing: getEditingState(for: tab))
                        .tabItem {
                            if let tabBarImage = tab.tabBarImage {
                                Image(tabBarImage)
                                    .renderingMode(.template)
                            } else {
                                Image(systemName: tab.systemImage)
                            }
                            Text(tab.title)
                        }
                        .tag(tab)
                }
            }
            .tint(Color(theme[uicolor: "tabBarIconSelectedColor"] ?? UIColor.systemBlue))
            .onChange(of: selectedTab) { newTab in
                // Detect Forums tab tap while already selected - reset to forums list
                if newTab == .forums && selectedTab == .forums {
                    // For iPad, we might need different navigation reset logic
                    // This depends on how iPad navigation should work
                }
            }
        } detail: {
            NavigationStack(path: $coordinator.path) {
                DetailView()
                    .environmentObject(coordinator)
                    .navigationDestination(for: ThreadDestination.self) { destination in
                        Group {
                            let _ = logger.info("iPad DetailView: navigationDestination triggered for thread: \(destination.thread.title ?? "Unknown"), jumpToPostID: \(destination.jumpToPostID ?? "none")")
                            PostsViewWrapper(
                                thread: destination.thread,
                                author: destination.author,
                                page: destination.page,
                                scrollFraction: destination.scrollFraction,
                                jumpToPostID: destination.jumpToPostID,
                                coordinator: coordinator
                            )
                        }
                    }
                    .navigationDestination(for: Forum.self) { forum in
                        Group {
                            let _ = print("🔵 iPad NavigationDestination triggered for Forum: \(forum.name ?? "unnamed")")
                            if let managedObjectContext = AppDelegate.instance?.managedObjectContext {
                                SwiftUIThreadsView(
                                    forum: forum,
                                    managedObjectContext: managedObjectContext,
                                    coordinator: coordinator
                                )
                            } else {
                                Text("Error: Managed Object Context not available")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .navigationDestination(for: PrivateMessageDestination.self) { destination in
                        Group {
                            let _ = print("🔵 iPad NavigationDestination triggered for PrivateMessage: \(destination.message.messageID)")
                            if let managedObjectContext = AppDelegate.instance?.managedObjectContext {
                                SwiftUIMessageView(
                                    message: destination.message,
                                    managedObjectContext: managedObjectContext,
                                    coordinator: coordinator
                                )
                            } else {
                                Text("Error: Managed Object Context not available")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .navigationDestination(for: ComposePrivateMessage.self) { _ in
                        MessageComposeDetailView(coordinator: coordinator)
                    }
            }
            .unpopEnabled(coordinator: coordinator)
        }
        .tint(navigationTintColor)
    }
    
    private func getEditingState(for tab: MainTab) -> Bool {
        switch tab {
        case .forums:
            return isEditingForums
        case .bookmarks:
            return isEditingBookmarks
        case .messages:
            return isEditingMessages
        default:
            return false
        }
    }
}

// MARK: - Missing View Implementations

// PrivateMessageViewWrapper removed - using pure UIKit navigation now
