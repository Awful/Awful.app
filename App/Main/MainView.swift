import AwfulCore
import AwfulExtensions
import AwfulModelTypes
import AwfulSettings
import AwfulTheming
import SwiftUI
import Combine
import CoreData
import Foundation

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
    
    // State Restoration methods
    func saveNavigationState()
    func restoreNavigationState()
    
    // Scroll Position Management
    func updateScrollPosition(scrollFraction: CGFloat)
    func updateScrollPosition(for threadID: String, page: ThreadPage, author: User?, scrollFraction: CGFloat)
}

// MARK: - Main Coordinator Implementation

class MainCoordinatorImpl: MainCoordinator, ComposeTextViewControllerDelegate {
    @Published var presentedSheet: PresentedSheet?
    @Published var isTabBarHidden = false
    @Published var path = NavigationPath()
    @Published var sidebarPath = NavigationPath()
    
    // Keep a reference to the current compose view controller for triggering actions
    private weak var currentComposeViewController: ComposeTextViewController?
    
    // Track navigation destinations for unpop functionality
    @Published var navigationHistory: [AnyHashable] = []
    @Published var unpopStack: [AnyHashable] = []
    
    // State restoration support
    private let stateManager: NavigationStateManager
    private let managedObjectContext: NSManagedObjectContext
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        self.stateManager = NavigationStateManager(managedObjectContext: managedObjectContext)
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
        let destination = ThreadDestination(thread: thread, page: page, author: author)
        print("🔵 MainCoordinator: navigateToThread called - thread: \(thread.title ?? "Unknown"), page: \(page)")
        print("🔵 MainCoordinator: Current path count: \(path.count)")
        
        // Clear unpop stack when navigating to new destination
        unpopStack.removeAll()
        
        // Add to navigation history and path
        navigationHistory.append(destination)
        path.append(destination)
        print("🔵 MainCoordinator: Path count after append: \(path.count)")
        isTabBarHidden = true
    }
    
    func navigateToThread(_ thread: AwfulThread, author: User?) {
        let page: ThreadPage = .specific(1)
        navigateToThread(thread, page: page, author: author)
    }

    func navigateToForum(_ forum: Forum) {
        // Navigate to forum in sidebar (threads list)
        sidebarPath.append(forum)
        // Don't set isTabBarHidden = true here, as we want to stay in sidebar
    }
    
    func navigateToPrivateMessage(_ message: PrivateMessage) {
        // Clear unpop stack when navigating to new destination
        unpopStack.removeAll()
        
        // Add to navigation history and path
        navigationHistory.append(message)
        path.append(message)
        isTabBarHidden = true
    }
    
    func navigateToComposeMessage() {
        let destination = ComposePrivateMessage()
        
        // Clear unpop stack when navigating to new destination
        unpopStack.removeAll()
        
        // Add to navigation history and path
        navigationHistory.append(destination)
        path.append(destination)
        isTabBarHidden = true
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
            // On iPhone, hide the tab bar when showing detail view
            return isTabBarHidden
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
    
    // MARK: - Unpop Support
    
    func performUnpop() {
        guard !unpopStack.isEmpty else { return }
        
        let itemToRestore = unpopStack.removeLast()
        navigationHistory.append(itemToRestore)
        path.append(itemToRestore)
        isTabBarHidden = true
        
        print("🔄 Unpop performed, restored item to path. Path count: \(path.count)")
    }
    
    func handleNavigationPop() {
        // Called when a navigation pop occurs (e.g., back button pressed)
        // Only move items if we have them in history and the history is longer than current path
        let itemsToMoveCount = navigationHistory.count - path.count
        if itemsToMoveCount > 0 {
            let itemsToMove = Array(navigationHistory.suffix(itemsToMoveCount))
            unpopStack.append(contentsOf: itemsToMove)
            navigationHistory.removeLast(itemsToMoveCount)
            print("🔄 Navigation pop detected, moved \(itemsToMove.count) item(s) to unpop stack. Unpop stack count: \(unpopStack.count)")
        }
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
            guard let post = posts.first,
                  let thread = post.thread else {
                print("⚠️ Post with ID \(postID) not found or has no thread")
                return false
            }
            
            // Navigate to the thread with the specific post
            // For now, we'll navigate to the first page where the post might be
            // In a more complete implementation, we'd calculate the exact page
            navigateToThread(thread, page: .specific(1), author: nil)
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
    
    // MARK: - Scroll Position Management
    
    func updateScrollPosition(scrollFraction: CGFloat) {
        // Update the navigation history with the new scroll position
        if let lastIndex = navigationHistory.lastIndex(where: { $0 is ThreadDestination }),
           let threadDestination = navigationHistory[lastIndex] as? ThreadDestination {
            
            // Create a new ThreadDestination with the updated scroll position
            let updatedDestination = ThreadDestination(
                thread: threadDestination.thread,
                page: threadDestination.page,
                author: threadDestination.author,
                scrollFraction: scrollFraction
            )
            
            // Replace the item in navigation history
            navigationHistory[lastIndex] = updatedDestination
            
            // Update the NavigationPath by rebuilding it
            // NavigationPath doesn't allow direct modification, so we need to rebuild it
            let existingItems = Array(navigationHistory.prefix(upTo: lastIndex))
            let remainingItems = Array(navigationHistory.suffix(from: lastIndex + 1))
            
            // Rebuild the path
            path = NavigationPath()
            for item in existingItems {
                path.append(item)
            }
            path.append(updatedDestination)
            for item in remainingItems {
                path.append(item)
            }
            
            print("🔄 MainCoordinator: Updated scroll position to \(scrollFraction) for thread: \(threadDestination.thread.title ?? "Unknown")")
        } else {
            print("⚠️ MainCoordinator: No ThreadDestination found in navigation history to update scroll position")
        }
    }
    
    func updateScrollPosition(for threadID: String, page: ThreadPage, author: User?, scrollFraction: CGFloat) {
        // Find the ThreadDestination in navigation history matching the criteria
        if let index = navigationHistory.firstIndex(where: { item in
            guard let threadDestination = item as? ThreadDestination else { return false }
            return threadDestination.thread.threadID == threadID &&
                   threadDestination.page == page &&
                   threadDestination.author == author
        }),
           let threadDestination = navigationHistory[index] as? ThreadDestination {
            
            // Create a new ThreadDestination with the updated scroll position
            let updatedDestination = ThreadDestination(
                thread: threadDestination.thread,
                page: threadDestination.page,
                author: threadDestination.author,
                scrollFraction: scrollFraction
            )
            
            // Replace the item in navigation history
            navigationHistory[index] = updatedDestination
            
            // Update the NavigationPath by rebuilding it
            // NavigationPath doesn't allow direct modification, so we need to rebuild it
            let existingItems = Array(navigationHistory.prefix(upTo: index))
            let remainingItems = Array(navigationHistory.suffix(from: index + 1))
            
            // Rebuild the path
            path = NavigationPath()
            for item in existingItems {
                path.append(item)
            }
            path.append(updatedDestination)
            for item in remainingItems {
                path.append(item)
            }
            
            print("🔄 MainCoordinator: Updated scroll position to \(scrollFraction) for thread: \(threadDestination.thread.title ?? "Unknown") (threadID: \(threadID))")
        } else {
            print("⚠️ MainCoordinator: No ThreadDestination found in navigation history for threadID: \(threadID), page: \(page)")
        }
    }
    
    // MARK: - State Restoration Implementation
    
    func saveNavigationState() {
        print("💾 MainCoordinator: Saving navigation state")
        
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
        print("🔄 MainCoordinator: Restoring navigation state")
        
        // Validate Core Data context is ready
        guard managedObjectContext.persistentStoreCoordinator != nil else {
            print("🔄 Core Data not ready for state restoration")
            return
        }
        
        guard let savedState = stateManager.restoreNavigationState() else {
            print("🔄 No saved navigation state to restore")
            return
        }
        
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
        
        print("✅ Navigation state restored successfully")
    }
}

struct MainView: View {
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @SwiftUI.Environment(\.theme) private var theme
    
    // Use @SceneStorage for simple state restoration
    @SceneStorage("selectedTab") private var selectedTab: MainTab = .forums
    @SceneStorage("isEditingBookmarks") private var isEditingBookmarks = false
    @SceneStorage("isEditingMessages") private var isEditingMessages = false
    @SceneStorage("isEditingForums") private var isEditingForums = false
    
    @StateObject private var coordinator: MainCoordinatorImpl = {
        guard let appDelegate = AppDelegate.instance else {
            fatalError("AppDelegate.instance not available during coordinator initialization")
        }
        return MainCoordinatorImpl(managedObjectContext: appDelegate.managedObjectContext)
    }()
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
            guard let appDelegate = AppDelegate.instance else {
                print("❌ AppDelegate.instance not available in onAppear")
                return
            }
            
            appDelegate.mainCoordinator = coordinator
            configureGlobalAppearance(theme: theme)
            updateStatusBarStyle(theme: theme)
            checkPrivateMessagePrivileges()
            checkFavoriteForums()
            
            // Delay state restoration to ensure Core Data is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                coordinator.restoreNavigationState()
            }
        }
        .onDisappear {
            // Save navigation state when view disappears
            coordinator.saveNavigationState()
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
                selectedTab = tab
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RestoreTabSelection"))) { notification in
            if let tab = notification.object as? MainTab {
                selectedTab = tab
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // Save state when app enters background
            coordinator.saveNavigationState()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Restore state when app enters foreground with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                coordinator.restoreNavigationState()
            }
        }
    }
    
    // MARK: - iPad Layout
    private var iPadLayout: some View {
        iPadMainView(
            coordinator: coordinator,
            selectedTab: $selectedTab,
            isEditingBookmarks: isEditingBookmarks,
            isEditingMessages: isEditingMessages,
            isEditingForums: isEditingForums,
            hasFavoriteForums: hasFavoriteForums,
            canSendPrivateMessages: canSendPrivateMessages
        )
        .sheet(item: $coordinator.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
    }

    // MARK: - iPhone Layout  
    private var iPhoneLayout: some View {
        Group {
            iPhoneMainView(
                coordinator: coordinator,
                selectedTab: $selectedTab,
                hasFavoriteForums: hasFavoriteForums
            )
            .sheet(item: $coordinator.presentedSheet) { sheet in
                sheetContent(for: sheet)
            }
        }
        .toolbarBackground(theme[color: "tabBarBackgroundColor"]!, for: .bottomBar)
        .toolbarBackground(.visible, for: .bottomBar)
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
        itemAppearance.normal.iconColor = currentTheme[uicolor: "tabBarIconColor"]
        
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
        
        // Force immediate update of all visible navigation bars
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
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
}

// MARK: - Custom Tab Bar Implementation

private struct CustomTabBarContainer: View {
    @Binding private var selectedTab: MainTab
    @ObservedObject var coordinator: MainCoordinatorImpl
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    let isInSidebar: Bool
    @Binding var isEditingBookmarks: Bool
    @Binding var isEditingMessages: Bool
    @Binding var isEditingForums: Bool
    let hasFavoriteForums: Bool
    
    // Get the current selected tab value
    private var selectedTabValue: MainTab {
        selectedTab
    }
    
    // Create a binding that works with both internal and external state
    private var selectedTabBinding: Binding<MainTab> {
        $selectedTab
    }
    
    init(coordinator: MainCoordinatorImpl, isInSidebar: Bool, selectedTab: Binding<MainTab>, isEditingBookmarks: Binding<Bool>, isEditingMessages: Binding<Bool>, isEditingForums: Binding<Bool>, hasFavoriteForums: Bool) {
        self.coordinator = coordinator
        self.isInSidebar = isInSidebar
        self._selectedTab = selectedTab
        self._isEditingBookmarks = isEditingBookmarks
        self._isEditingMessages = isEditingMessages
        self._isEditingForums = isEditingForums
        self.hasFavoriteForums = hasFavoriteForums
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(MainTab.allCases(canSendPrivateMessages: canSendPrivateMessages)) { tab in
                    TabContentView(tab: tab, coordinator: coordinator, isEditing: getEditingState(for: tab))
                        .opacity(selectedTabValue == tab ? 1 : 0)
                }
            }

            // Show/hide tab bar based on platform and context
            if !coordinator.shouldHideTabBar(isInSidebar: isInSidebar) {
                CustomTabBar(selectedTab: selectedTabBinding, canSendPrivateMessages: canSendPrivateMessages)
            }
        }
        .sheet(item: $coordinator.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CanSendPrivateMessagesDidChange"))) { _ in
            // Handle the notification without triggering state changes during view updates
            // The @FoilDefaultStorage property will automatically update the view
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

private struct CustomTabBar: View {
    @Binding var selectedTab: MainTab
    let canSendPrivateMessages: Bool
    @SwiftUI.Environment(\.theme) private var theme
    
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(theme[color: "bottomBarTopBorderColor"] ?? Color.clear)
            
            HStack {
                ForEach(MainTab.allCases(canSendPrivateMessages: canSendPrivateMessages)) { tab in
                    Spacer()
                    Button(action: {
                        selectedTab = tab
                    }) {
                        VStack(spacing: 4) {
                            Image(tab.tabBarImage!)
                                .renderingMode(.template)
                            if theme[bool: "showRootTabBarLabel"] == true {
                                Text(tab.title)
                                    .font(.caption2)
                            }
                        }
                        .foregroundColor(selectedTab == tab ? theme[color: "tabBarIconSelectedColor"] : theme[color: "tabBarIconNormalColor"])
                    }
                    Spacer()
                }
            }
            .padding(.top, 5)
            .background(theme[color: "tabBarBackgroundColor"]!.ignoresSafeArea(edges: .bottom))
        }
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
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationDestination(for: ThreadDestination.self) { destination in
            Group {
                let _ = print("🔵 DetailView: navigationDestination triggered for thread: \(destination.thread.title ?? "Unknown"), scrollFraction: \(destination.scrollFraction?.description ?? "none")")
                PostsViewWrapper(
                    thread: destination.thread,
                    author: destination.author,
                    page: destination.page,
                    coordinator: coordinator,
                    scrollFraction: destination.scrollFraction
                )
            }
        }
        .navigationDestination(for: Forum.self) { forum in
            ThreadsViewWrapper(forum: forum, coordinator: coordinator)
        }
        .navigationDestination(for: PrivateMessage.self) { message in
            PrivateMessageViewWrapper(message: message, coordinator: coordinator)
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
            .onAppear {
                print("🔵 TabContentView: \(tab.rawValue) appeared with isEditing = \(isEditing)")
            }
            .onChange(of: isEditing) { newValue in
                print("🔵 TabContentView: \(tab.rawValue) editing state changed to \(newValue)")
            }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch tab {
        case .forums:
            ForumsViewRepresentable(isEditing: isEditing, coordinator: coordinator)
        case .bookmarks:
            BookmarksViewRepresentable(isEditing: isEditing, coordinator: coordinator)
        case .messages:
            MessagesViewRepresentable(isEditing: isEditing, coordinator: coordinator)
        case .lepers:
            LepersViewRepresentable(coordinator: coordinator)
        case .settings:
            SettingsViewRepresentable()
        }
    }
}

// MARK: - UIViewControllerRepresentable wrappers for existing UIKit view controllers

struct ForumsViewRepresentable: UIViewControllerRepresentable {
    var isEditing: Bool
    let coordinator: any MainCoordinator

    func makeUIViewController(context: Context) -> UIViewController {
        guard let managedObjectContext = AppDelegate.instance?.managedObjectContext else {
            fatalError("AppDelegate.instance or managedObjectContext not available")
        }
        let forumsVC = ForumsTableViewController(managedObjectContext: managedObjectContext)
        forumsVC.coordinator = coordinator
        let wrapper = SwiftUICompatibleViewController(wrapping: forumsVC)
        wrapper.restorationIdentifier = "Forum list"
        return wrapper
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let wrapper = uiViewController as? SwiftUICompatibleViewController else { return }
        print("🔵 ForumsViewRepresentable: Setting editing state to \(isEditing)")
        wrapper.setEditing(isEditing, animated: true)
    }
}

struct BookmarksViewRepresentable: UIViewControllerRepresentable {
    var isEditing: Bool
    let coordinator: any MainCoordinator

    func makeUIViewController(context: Context) -> UIViewController {
        guard let managedObjectContext = AppDelegate.instance?.managedObjectContext else {
            fatalError("AppDelegate.instance or managedObjectContext not available")
        }
        let bookmarksVC = BookmarksTableViewController(managedObjectContext: managedObjectContext)
        bookmarksVC.coordinator = coordinator
        let wrapper = SwiftUICompatibleViewController(wrapping: bookmarksVC)
        wrapper.restorationIdentifier = "Bookmarks"
        return wrapper
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let wrapper = uiViewController as? SwiftUICompatibleViewController else { return }
        print("🔵 BookmarksViewRepresentable: Setting editing state to \(isEditing)")
        wrapper.setEditing(isEditing, animated: true)
    }
}

struct ThreadDestination: Hashable {
    let thread: AwfulThread
    let page: ThreadPage
    let author: User?
    let scrollFraction: CGFloat?
    
    init(thread: AwfulThread, page: ThreadPage, author: User?, scrollFraction: CGFloat? = nil) {
        self.thread = thread
        self.page = page
        self.author = author
        self.scrollFraction = scrollFraction
        print("🔵 ThreadDestination: Created for thread: \(thread.title ?? "Unknown"), page: \(page), scrollFraction: \(scrollFraction?.description ?? "none")")
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(thread)
        hasher.combine(page)
        hasher.combine(author)
        hasher.combine(scrollFraction)
    }
    
    static func == (lhs: ThreadDestination, rhs: ThreadDestination) -> Bool {
        return lhs.thread == rhs.thread &&
               lhs.page == rhs.page &&
               lhs.author == rhs.author &&
               lhs.scrollFraction == rhs.scrollFraction
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
        let wrapper = SwiftUICompatibleViewController(wrapping: messagesVC)
        wrapper.restorationIdentifier = "Messages"
        return wrapper
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let wrapper = uiViewController as? SwiftUICompatibleViewController else { return }
        print("🔵 MessagesViewRepresentable: Setting editing state to \(isEditing)")
        wrapper.setEditing(isEditing, animated: true)
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

struct SettingsViewRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        guard let managedObjectContext = AppDelegate.instance?.managedObjectContext else {
            fatalError("AppDelegate.instance or managedObjectContext not available")
        }
        let settingsVC = SettingsViewController(managedObjectContext: managedObjectContext)
        let wrapper = SwiftUICompatibleViewController(wrapping: settingsVC)
        wrapper.restorationIdentifier = "Settings"
        return wrapper
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
         // Theme changes are handled automatically by the wrapper's observer
    }
}

// MARK: - Detail Navigation Destinations

struct ThreadsViewRepresentable: UIViewControllerRepresentable {
    let forum: Forum
    let coordinator: any MainCoordinator
    @SwiftUI.Environment(\.theme) private var theme

    func makeUIViewController(context: Context) -> UIViewController {
        let threadsVC = ThreadsTableViewController(forum: forum)
        threadsVC.coordinator = coordinator
        let wrapper = SwiftUICompatibleViewController(wrapping: threadsVC)
        wrapper.restorationIdentifier = "Threads"
        return wrapper
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Theme changes are handled automatically by the wrapper's observer
    }
}

struct ThreadsViewWrapper: View {
    let forum: Forum
    let coordinator: any MainCoordinator
    @SwiftUI.Environment(\.theme) private var theme
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    private var navigationTintColor: Color {
        Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label)
    }
    
    var body: some View {
        ThreadsViewRepresentable(forum: forum, coordinator: coordinator)
            .navigationTitle(forum.name ?? "Threads")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // Navigate back using environment dismiss
                        dismiss()
                    }) {
                        Image("back")
                            .renderingMode(.template)
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(navigationTintColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        coordinator.presentComposeThread(for: forum)
                    }) {
                        Image("compose")
                            .renderingMode(.template)
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(navigationTintColor)
                }
            }
    }
}

struct PostsViewWrapper: View {
    let thread: AwfulThread
    let author: User?
    let page: ThreadPage
    let scrollFraction: CGFloat?
    var coordinator: (any MainCoordinator)?
    @StateObject private var viewModel = PostsViewModel()
    @SwiftUI.Environment(\.theme) private var theme
    @State private var title: String
    @FoilDefaultStorage(Settings.useSwiftUIPostsView) private var useSwiftUIPostsView
    
    private var navigationTintColor: Color {
        Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label)
    }
    
    init(thread: AwfulThread, author: User?, page: ThreadPage, coordinator: (any MainCoordinator)?, scrollFraction: CGFloat? = nil) {
        self.thread = thread
        self.author = author
        self.page = page
        self.scrollFraction = scrollFraction
        self.coordinator = coordinator
        _title = State(initialValue: thread.title ?? "")
    }
    
    var body: some View {
        Group {
            if useSwiftUIPostsView {
                // New SwiftUI posts view with fixed animation issues
                SwiftUIPostsPageView(
                    thread: thread,
                    author: author,
                    coordinator: coordinator,
                    scrollFraction: scrollFraction
                )
            } else {
                // Legacy UIKit posts view wrapped in SwiftUI
                legacyPostsView
            }
        }
    }
    
    private var legacyPostsView: some View {
        PostsViewControllerRepresentable(
            thread: thread,
            page: page,
            author: author,
            coordinator: coordinator,
            viewModel: viewModel
        )
        .refreshable {
            await viewModel.refresh()
        }
        .overlay(alignment: .top) {
            // Secondary, hideable top bar as overlay
            PostsTopBar(
                onParentForumTapped: { viewModel.goToParentForum() },
                onPreviousPostsTapped: { /* TODO */ },
                onScrollToEndTapped: { viewModel.scrollToBottom() },
                isVisible: viewModel.isTopBarVisible
            )
            .animation(.easeInOut(duration: 0.2), value: viewModel.isTopBarVisible)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(navigationTintColor)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewModel.newReply() }) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .overlay(alignment: .bottom) {
            PostsToolbarContainer(
                thread: thread,
                author: author,
                page: viewModel.currentPage ?? page, // Fall back to initial page if viewModel page is nil
                numberOfPages: viewModel.numberOfPages,
                isLoadingViewVisible: false, // This needs to be updated if we re-add the loading view
                onSettingsTapped: { viewModel.triggerSettings() },
                onBackTapped: { viewModel.goToPreviousPage() },
                onForwardTapped: { viewModel.goToNextPage() },
                onPageSelected: { page in
                    viewModel.loadPage(page)
                },
                onGoToLastPost: {
                    viewModel.goToLastPost()
                },
                onBookmarkTapped: { viewModel.triggerBookmark() },
                onCopyLinkTapped: { viewModel.triggerCopyLink() },
                onVoteTapped: { viewModel.triggerVote() },
                onYourPostsTapped: { viewModel.triggerYourPosts() }
            )
            .ignoresSafeArea(.container, edges: .bottom)
        }
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
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        coordinator.submitCurrentComposition()
                    }
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
            Sidebar(coordinator: coordinator)
        } detail: {
            NavigationStack(path: $coordinator.path) {
                DetailView()
                    .environmentObject(coordinator)
            }
            .unpopEnabled(coordinator: coordinator)
        }
        .tint(navigationTintColor)
    }
}

// MARK: - iPhone Main View
struct iPhoneMainView: View {
    @ObservedObject var coordinator: MainCoordinatorImpl
    @Binding var selectedTab: MainTab
    let hasFavoriteForums: Bool
    @SwiftUI.Environment(\.theme) private var theme
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    @State private var isEditingBookmarks = false
    @State private var isEditingMessages = false
    @State private var isEditingForums = false

    // Computed property for navigation tint color based on theme
    private var navigationTintColor: Color {
        Color(theme[uicolor: "navigationBarTextColor"] ?? .label)
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            CustomTabBarContainer(
                coordinator: coordinator,
                isInSidebar: false,
                selectedTab: $selectedTab,
                isEditingBookmarks: $isEditingBookmarks,
                isEditingMessages: $isEditingMessages,
                isEditingForums: $isEditingForums,
                hasFavoriteForums: hasFavoriteForums
            )
            .navigationTitle(selectedTab.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    leadingToolbarItems
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingToolbarItems
                }
            }
            .navigationDestination(for: Forum.self) { forum in
                ThreadsViewWrapper(forum: forum, coordinator: coordinator)
            }
            .navigationDestination(for: ThreadDestination.self) { destination in
                PostsViewWrapper(
                    thread: destination.thread,
                    author: destination.author,
                    page: destination.page,
                    coordinator: coordinator,
                    scrollFraction: destination.scrollFraction
                )
            }
        }
        .unpopEnabled(coordinator: coordinator)
        .tint(Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label))
        .accentColor(Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label))
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(false)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private var leadingToolbarItems: some View {
        switch selectedTab {
        case .forums:
            if canSendPrivateMessages {
                Button("Search") {
                    coordinator.presentSearch()
                }
            }
        case .messages:
            Button(isEditingMessages ? "Done" : "Edit") {
                print("🔵 iPhone: Messages edit button pressed, toggling from \(isEditingMessages) to \(!isEditingMessages)")
                isEditingMessages.toggle()
            }
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var trailingToolbarItems: some View {
        switch selectedTab {
        case .forums:
            if hasFavoriteForums {
                Button(isEditingForums ? "Done" : "Edit") {
                    print("🔵 iPhone: Forums edit button pressed, toggling from \(isEditingForums) to \(!isEditingForums)")
                    isEditingForums.toggle()
                }
            }
        case .bookmarks:
            Button(isEditingBookmarks ? "Done" : "Edit") {
                print("🔵 iPhone: Bookmarks edit button pressed, toggling from \(isEditingBookmarks) to \(!isEditingBookmarks)")
                isEditingBookmarks.toggle()
            }
        case .messages:
            Button(action: {
                coordinator.presentCompose(for: selectedTab)
            }) {
                Image("compose")
                    .renderingMode(.template)
            }
        default:
            EmptyView()
        }
    }
}

struct Sidebar: View {
    @ObservedObject var coordinator: MainCoordinatorImpl
    @State private var selectedTab: MainTab = .forums
    @State private var isEditingBookmarks = false
    @State private var isEditingMessages = false
    @State private var isEditingForums = false
    @State private var hasFavoriteForums = false
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    @SwiftUI.Environment(\.theme) private var theme
    
    // Computed property for navigation tint color based on theme
    private var navigationTintColor: Color {
        Color(theme[uicolor: "navigationBarTextColor"] ?? .label)
    }
    
    var body: some View {
        NavigationStack(path: $coordinator.sidebarPath) {
            CustomTabBarContainer(
                coordinator: coordinator,
                isInSidebar: true,
                selectedTab: $selectedTab,
                isEditingBookmarks: $isEditingBookmarks,
                isEditingMessages: $isEditingMessages,
                isEditingForums: $isEditingForums,
                hasFavoriteForums: hasFavoriteForums
            )
            .navigationDestination(for: Forum.self) { forum in
                ThreadsViewWrapper(forum: forum, coordinator: coordinator)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    leadingToolbarItems
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingToolbarItems
                }
            }
        }
        .navigationTitle(selectedTab.title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(navigationTintColor)
        .onAppear {
            checkFavoriteForums()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FavoriteForumsCountDidChange"))) { notification in
            if let count = notification.userInfo?["count"] as? Int {
                hasFavoriteForums = count > 0
            }
        }
    }
    
    @ViewBuilder
    private var leadingToolbarItems: some View {
        switch selectedTab {
        case .forums:
            if canSendPrivateMessages {
                Button("Search") {
                    coordinator.presentSearch()
                }
            }
        case .messages:
            Button(isEditingMessages ? "Done" : "Edit") {
                print("🔵 iPad: Messages edit button pressed, toggling from \(isEditingMessages) to \(!isEditingMessages)")
                isEditingMessages.toggle()
            }
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var trailingToolbarItems: some View {
        switch selectedTab {
        case .forums:
            if hasFavoriteForums {
                Button(isEditingForums ? "Done" : "Edit") {
                    print("🔵 iPad: Forums edit button pressed, toggling from \(isEditingForums) to \(!isEditingForums)")
                    isEditingForums.toggle()
                }
            }
        case .bookmarks:
            Button(isEditingBookmarks ? "Done" : "Edit") {
                print("🔵 iPad: Bookmarks edit button pressed, toggling from \(isEditingBookmarks) to \(!isEditingBookmarks)")
                isEditingBookmarks.toggle()
            }
        case .messages:
            Button(action: {
                coordinator.presentCompose(for: selectedTab)
            }) {
                Image("compose")
                    .renderingMode(.template)
            }
        default:
            EmptyView()
        }
    }
    
    private func checkFavoriteForums() {
        // Set up observer for favorite forums count changes
        guard let context = AppDelegate.instance?.managedObjectContext else {
            print("❌ AppDelegate.instance or managedObjectContext not available for checkFavoriteForums")
            return
        }
        
        let favoriteForumCountObserver = ManagedObjectCountObserver(
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
        hasFavoriteForums = favoriteForumCountObserver.count > 0
    }
}

// MARK: - Missing View Implementations

struct PrivateMessageViewWrapper: View {
    let message: PrivateMessage
    let coordinator: any MainCoordinator
    @SwiftUI.Environment(\.theme) private var theme
    
    private var navigationTintColor: Color {
        Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label)
    }
    
    var body: some View {
        MessageViewRepresentable(message: message, coordinator: coordinator)
            .navigationTitle(message.subject ?? "Private Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // TODO: Implement reply action
                    }) {
                        Image("compose")
                            .renderingMode(.template)
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(navigationTintColor)
                }
            }
    }
}
