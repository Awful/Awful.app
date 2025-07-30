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

// MARK: - Settings Manager

/// Centralized settings manager to prevent excessive view recreations
final class SettingsManager: ObservableObject {
    
    // MARK: - Core Settings
    
    var canSendPrivateMessages: Bool {
        get { UserDefaults.standard.bool(forKey: Settings.canSendPrivateMessages.key) }
        set { 
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: Settings.canSendPrivateMessages.key)
        }
    }
    
    var darkMode: Bool {
        get { UserDefaults.standard.bool(forKey: Settings.darkMode.key) }
        set { 
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: Settings.darkMode.key) 
        }
    }
    
    var enableHaptics: Bool {
        get { UserDefaults.standard.bool(forKey: Settings.enableHaptics.key) }
        set { 
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: Settings.enableHaptics.key) 
        }
    }
    
    var showThreadTags: Bool {
        get { UserDefaults.standard.bool(forKey: Settings.showThreadTags.key) }
        set { 
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: Settings.showThreadTags.key) 
        }
    }
    
    // MARK: - Optional Settings
    
    var userID: String? {
        get { UserDefaults.standard.string(forKey: Settings.userID.key) }
        set { 
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: Settings.userID.key) 
        }
    }
    
    var username: String? {
        get { UserDefaults.standard.string(forKey: Settings.username.key) }
        set { 
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: Settings.username.key) 
        }
    }
    
    // MARK: - Singleton
    
    static let shared = SettingsManager()
    
    private init() {
        // Private initializer to enforce singleton pattern
    }
}

// MARK: - Environment Key

struct SettingsManagerKey: EnvironmentKey {
    static let defaultValue = SettingsManager.shared
}

extension EnvironmentValues {
    var settingsManager: SettingsManager {
        get { self[SettingsManagerKey.self] }
        set { self[SettingsManagerKey.self] = newValue }
    }
}

// MARK: - Navigation Destination

struct ThreadDestination: Hashable, Identifiable {
    let thread: AwfulThread
    let author: User?
    let page: ThreadPage
    let scrollFraction: CGFloat?
    let jumpToPostID: String?
    
    var id: String {
        let pageString = String(describing: page)
        let authorString = author?.username ?? "none"
        return "thread-\(thread.threadID)-\(pageString)-\(authorString)"
    }
    
    init(thread: AwfulThread, author: User? = nil, page: ThreadPage = .nextUnread, 
         scrollFraction: CGFloat? = nil, jumpToPostID: String? = nil) {
        self.thread = thread
        self.author = author
        self.page = page
        self.scrollFraction = scrollFraction
        self.jumpToPostID = jumpToPostID
    }
}

struct PrivateMessageDestination: Hashable {
    let message: PrivateMessage
    
    init(message: PrivateMessage) {
        self.message = message
    }
}

struct ComposePrivateMessage: Hashable, Identifiable {
    var id: String { "compose-pm" }
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

// MARK: - Main Coordinator Protocol

protocol MainCoordinator: ObservableObject {
    var presentedSheet: PresentedSheet? { get set }
    var presentedPrivateMessageUser: IdentifiableUser? { get set }
    var isTabBarHidden: Bool { get set }
    var path: NavigationPath { get set }
    var sidebarPath: NavigationPath { get set }
    
    func navigateToForum(_ forum: Forum)
    func navigateToThread(_ thread: AwfulThread, page: ThreadPage, author: User?)
    func navigateToThread(_ thread: AwfulThread, page: ThreadPage, author: User?, jumpToPostID: String?)
    func navigateToPrivateMessage(_ message: PrivateMessage)
    func goBack()
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
    
    // State management methods
    func updateScrollPosition(for threadID: String, page: ThreadPage, author: User?, scrollFraction: CGFloat)
    func saveViewState(for threadID: String, state: [String: Any])
    func getViewState(for threadID: String) -> [String: Any]?
}

// MARK: - Main Coordinator Implementation

class MainCoordinatorImpl: MainCoordinator, ComposeTextViewControllerDelegate {
    @Published var presentedSheet: PresentedSheet?
    @Published var presentedPrivateMessageUser: IdentifiableUser?
    @Published var isTabBarHidden = false
    @Published var path = NavigationPath()
    @Published var sidebarPath = NavigationPath()
    
    private weak var currentComposeViewController: ComposeTextViewController?
    private let managedObjectContext: NSManagedObjectContext
    
    // State management storage
    private var threadScrollPositions: [String: (page: ThreadPage, author: User?, scrollFraction: CGFloat)] = [:]
    private var threadViewStates: [String: [String: Any]] = [:]
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }
    
    func navigateToForum(_ forum: Forum) {
        logger.info("📍 Navigating to forum: \(forum.name ?? "Unknown")")
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: Navigate in sidebar (which acts like iPhone)
            sidebarPath.append(forum)
        } else {
            // iPhone: Standard navigation
            path.append(forum)
        }
    }
    
    func navigateToThread(_ thread: AwfulThread, page: ThreadPage = .nextUnread, author: User? = nil) {
        logger.info("📍 Navigating to thread: \(thread.title ?? "Unknown")")
        
        let destination = ThreadDestination(
            thread: thread,
            author: author,
            page: page
        )
        
        // Always use main path for thread navigation (detail view on iPad)
        path.append(destination)
    }
    
    func navigateToThread(_ thread: AwfulThread, page: ThreadPage, author: User?, jumpToPostID: String?) {
        logger.info("📍 Navigating to thread with jumpToPostID: \(thread.title ?? "Unknown")")
        
        let destination = ThreadDestination(
            thread: thread,
            author: author,
            page: page,
            scrollFraction: nil,
            jumpToPostID: jumpToPostID
        )
        
        // Always use main path for thread navigation (detail view on iPad)
        path.append(destination)
    }
    
    func navigateToPrivateMessage(_ message: PrivateMessage) {
        logger.info("📍 Navigating to private message")
        // Implementation will depend on your private message navigation approach
        // For now, we'll use the existing presentedPrivateMessageUser approach
        if let fromUser = message.from {
            presentedPrivateMessageUser = IdentifiableUser(user: fromUser)
        }
    }
    
    func goBack() {
        logger.info("📍 Going back")
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func shouldHideTabBar(isInSidebar: Bool) -> Bool {
        return isTabBarHidden
    }
    
    // MARK: - URL Routing
    
    func navigateToTab(_ tab: MainTab) {
        logger.info("🔗 Navigating to tab: \(tab.rawValue)")
        NotificationCenter.default.post(name: Notification.Name("NavigateToTab"), object: tab.rawValue)
    }
    
    func navigateToForumWithID(_ forumID: String) -> Bool {
        logger.info("🔗 Navigating to forum ID: \(forumID)")
        
        let request: NSFetchRequest<Forum> = NSFetchRequest<Forum>(entityName: "Forum")
        request.predicate = NSPredicate(format: "forumID == %@", forumID)
        request.fetchLimit = 1
        
        do {
            let forums = try managedObjectContext.fetch(request)
            if let forum = forums.first {
                navigateToForum(forum)
                return true
            }
        } catch {
            logger.error("Failed to fetch forum with ID \(forumID): \(error)")
        }
        
        return false
    }
    
    func navigateToThreadWithID(_ threadID: String, page: ThreadPage = .nextUnread, author: User? = nil) -> Bool {
        logger.info("🔗 Navigating to thread ID: \(threadID)")
        
        let request: NSFetchRequest<AwfulThread> = NSFetchRequest<AwfulThread>(entityName: "Thread")
        request.predicate = NSPredicate(format: "threadID == %@", threadID)
        request.fetchLimit = 1
        
        do {
            let threads = try managedObjectContext.fetch(request)
            if let thread = threads.first {
                navigateToThread(thread, page: page, author: author)
                return true
            }
        } catch {
            logger.error("Failed to fetch thread with ID \(threadID): \(error)")
        }
        
        return false
    }
    
    func navigateToPostWithID(_ postID: String) -> Bool {
        logger.info("🔗 Navigating to post ID: \(postID)")
        // Implementation would fetch post and navigate to its thread
        return false
    }
    
    func navigateToMessageWithID(_ messageID: String) -> Bool {
        logger.info("🔗 Navigating to message ID: \(messageID)")
        // Implementation would navigate to messages tab and specific message
        return false
    }
    
    func presentUserProfile(userID: String) {
        logger.info("🔗 Presenting user profile: \(userID)")
        // Implementation would present user profile sheet
    }
    
    func presentRapSheet(userID: String) {
        logger.info("🔗 Presenting rap sheet: \(userID)")
        // Implementation would present rap sheet
    }
    
    func presentPrivateMessageComposer(for user: User) {
        logger.info("🔗 Presenting PM composer for: \(user.username ?? "Unknown")")
        presentedPrivateMessageUser = IdentifiableUser(user: user)
    }
    
    func presentReportPost(_ post: Post) {
        logger.info("🔗 Presenting report post: \(post.postID)")
        // Implementation would present report post sheet
    }
    
    func presentSharePost(_ post: Post) {
        logger.info("🔗 Presenting share post: \(post.postID)")
        // Implementation would present share sheet
    }
    
    // MARK: - State Management Methods
    
    func updateScrollPosition(for threadID: String, page: ThreadPage, author: User?, scrollFraction: CGFloat) {
        logger.info("💾 Updating scroll position for thread: \(threadID), page: \(String(describing: page)), scrollFraction: \(scrollFraction)")
        threadScrollPositions[threadID] = (page: page, author: author, scrollFraction: scrollFraction)
    }
    
    func saveViewState(for threadID: String, state: [String: Any]) {
        logger.info("💾 Saving view state for thread: \(threadID)")
        threadViewStates[threadID] = state
    }
    
    func getViewState(for threadID: String) -> [String: Any]? {
        logger.info("📱 Getting view state for thread: \(threadID)")
        return threadViewStates[threadID]
    }
    
    // MARK: - ComposeTextViewControllerDelegate
    
    func composeTextViewController(_ composeController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
        // Implementation for compose completion
        logger.info("🔗 Compose finished - success: \(success), keepDraft: \(shouldKeepDraft)")
    }
}

// MARK: - Main View

struct MainView: View {
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @SwiftUI.Environment(\.theme) private var theme
    @SwiftUI.Environment(\.settingsManager) private var settingsManager
    
    @StateObject private var tabManager = TabManager()
    @StateObject private var coordinator: MainCoordinatorImpl = {
        guard let appDelegate = AppDelegate.instance else {
            fatalError("AppDelegate.instance not available during coordinator initialization")
        }
        return MainCoordinatorImpl(managedObjectContext: appDelegate.managedObjectContext)
    }()
    
    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .environment(\.settingsManager, SettingsManager.shared)
        .sheet(item: $coordinator.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        .sheet(item: $coordinator.presentedPrivateMessageUser) { user in
            privateMessageSheetContent(for: user)
        }
        .onAppear {
            guard let appDelegate = AppDelegate.instance else { return }
            appDelegate.mainCoordinator = coordinator
            
            configureGlobalAppearance(theme: theme)
            updateStatusBarStyle(theme: theme)
            checkPrivateMessagePrivileges()
            
        }
        .onChange(of: theme) { newTheme in
            configureGlobalAppearance(theme: newTheme)
            updateStatusBarStyle(theme: newTheme)
            
        }
        .preferredColorScheme(theme[string: "statusBarBackground"] == "dark" ? .dark : .light)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CanSendPrivateMessagesDidChange"))) { _ in
            checkPrivateMessagePrivileges()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToTab"))) { notification in
            if let tab = notification.object as? MainTab {
                tabManager.selectTab(tab)
            }
        }
    }
    
    @ViewBuilder
    private var iPadLayout: some View {
        NavigationSplitView {
            // Sidebar: Full iPhone navigation experience
            NavigationStack(path: $coordinator.sidebarPath) {
                TabView(selection: Binding(
                    get: { tabManager.selectedTab },
                    set: { tabManager.selectTab($0) }
                )) {
                    let showLabels = theme[bool: "showRootTabBarLabel"] ?? true
                    
                    ForEach(MainTab.allCases(canSendPrivateMessages: settingsManager.canSendPrivateMessages)) { tab in
                        TabContentView(tab: tab, coordinator: coordinator, isEditing: false)
                            .tabItem {
                                let isSelected = tabManager.selectedTab == tab
                                
                                VStack(spacing: 4) {
                                    if !showLabels {
                                        Spacer()
                                    }
                                    
                                    if let tabBarImage = isSelected ? tab.selectedTabBarImage : tab.tabBarImage {
                                        Image(tabBarImage).renderingMode(.template)
                                    } else {
                                        Image(systemName: tab.systemImage)
                                    }
                                    
                                    if showLabels {
                                        Text(tab.title)
                                            .font(.caption2)
                                    } else {
                                        Spacer()
                                    }
                                }
                            }
                            .tag(tab)
                            .id("\(tab.id)-\(showLabels ? "labeled" : "unlabeled")")
                    }
                }
                .tint(Color(theme[uicolor: "tabBarIconSelectedColor"] ?? UIColor.systemBlue))
                .tabViewStyle(.automatic)
                .padding(2) // Fix for TabView clipping issue in NavigationSplitView sidebar
                .padding(.bottom, (theme[bool: "showRootTabBarLabel"] ?? true) ? 0 : 0.1) // Force layout recalculation
                .navigationBarHidden(true)
                .navigationDestination(for: Forum.self) { forum in
                    let _ = print("🎯 NavigationDestination for Forum triggered: \(forum.name ?? "unnamed")")
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
                .navigationDestination(for: PrivateMessageDestination.self) { destination in
                    SwiftUIMessageView(
                        message: destination.message,
                        managedObjectContext: AppDelegate.instance?.managedObjectContext ?? NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType),
                        coordinator: coordinator
                    )
                }
            }
            .toolbarBackground(theme[color: "navigationBarTintColor"] ?? .clear, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                // Configure sidebar-specific navigation bar appearance for compact height
                if UIDevice.current.userInterfaceIdiom == .pad {
                    configureSidebarNavigationBar()
                }
            }
        } detail: {
            // Detail: Thread and message content
            NavigationStack(path: $coordinator.path) {
                Text("Select a thread to view posts")
                    .foregroundColor(.secondary)
            }
            .toolbarBackground(theme[color: "navigationBarTintColor"] ?? .clear, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: ThreadDestination.self) { destination in
                PostsViewWrapper(
                    thread: destination.thread,
                    page: destination.page,
                    managedObjectContext: AppDelegate.instance?.managedObjectContext ?? NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType),
                    coordinator: coordinator
                )
            }
            .navigationDestination(for: PrivateMessageDestination.self) { destination in
                SwiftUIMessageView(
                    message: destination.message,
                    managedObjectContext: AppDelegate.instance?.managedObjectContext ?? NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType),
                    coordinator: coordinator
                )
            }
        }
        .tint(Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label))
        .environmentObject(coordinator)
    }
    
    @ViewBuilder
    private var iPhoneLayout: some View {
        NavigationStack(path: $coordinator.path) {
            TabView(selection: Binding(
                get: { tabManager.selectedTab },
                set: { tabManager.selectTab($0) }
            )) {
                let showLabels = theme[bool: "showRootTabBarLabel"] ?? true
                
                ForEach(MainTab.allCases(canSendPrivateMessages: settingsManager.canSendPrivateMessages)) { tab in
                    TabContentView(tab: tab, coordinator: coordinator, isEditing: false)
                        .tabItem {
                            let isSelected = tabManager.selectedTab == tab
                            
                            VStack(spacing: 4) {
                                if !showLabels {
                                    Spacer()
                                }
                                
                                if let tabBarImage = isSelected ? tab.selectedTabBarImage : tab.tabBarImage {
                                    Image(tabBarImage).renderingMode(.template)
                                } else {
                                    Image(systemName: tab.systemImage)
                                }
                                
                                if showLabels {
                                    Text(tab.title)
                                        .font(.caption2)
                                } else {
                                    Spacer()
                                }
                            }
                        }
                        .tag(tab)
                        .id("\(tab.id)-\(showLabels ? "labeled" : "unlabeled")")
                }
            }
            .tint(Color(theme[uicolor: "tabBarIconSelectedColor"] ?? UIColor.systemBlue))
            .tabViewStyle(.automatic)
            .padding(.bottom, (theme[bool: "showRootTabBarLabel"] ?? true) ? 0 : 0.1) // Force layout recalculation
            .navigationDestination(for: Forum.self) { forum in
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
            .navigationDestination(for: ThreadDestination.self) { destination in
                PostsViewWrapper(
                    thread: destination.thread,
                    page: destination.page,
                    managedObjectContext: AppDelegate.instance?.managedObjectContext ?? NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType),
                    coordinator: coordinator
                )
            }
            .navigationDestination(for: PrivateMessageDestination.self) { destination in
                SwiftUIMessageView(
                    message: destination.message,
                    managedObjectContext: AppDelegate.instance?.managedObjectContext ?? NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType),
                    coordinator: coordinator
                )
            }
        }
        .environmentObject(coordinator)
    }
    
    @ViewBuilder
    private func sheetContent(for sheet: PresentedSheet) -> some View {
        switch sheet {
        case .search:
            SearchHostingControllerWrapper()
        case .compose(_):
            MessageComposeViewRepresentable(coordinator: coordinator, isPresentedInSheet: true)
        }
    }
    
    @ViewBuilder
    private func privateMessageSheetContent(for identifiableUser: IdentifiableUser) -> some View {
        let composeVC = MessageComposeViewController(recipient: identifiableUser.user)
        
        MessageComposeView(
            messageComposeViewController: composeVC,
            onDismiss: {
                coordinator.presentedPrivateMessageUser = nil
            }
        )
        .environment(\.theme, theme)
    }
    
    private func updateStatusBarStyle(theme: Theme) {
        let statusBarBackground = theme[string: "statusBarBackground"] ?? "dark"
        let shouldUseLightContent = statusBarBackground == "dark"
        
        StatusBarStyleManager.shared.updateStyle(lightContent: shouldUseLightContent)
    }
    
    private func configureGlobalAppearance(theme: Theme) {
        // Configure navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = theme[uicolor: "navigationBarTintColor"] ?? UIColor.systemBackground
        navAppearance.shadowColor = theme[uicolor: "bottomBarTopBorderColor"]
        
        let textColor = theme[uicolor: "navigationBarTextColor"] ?? UIColor.label
        navAppearance.titleTextAttributes = [
            .foregroundColor: textColor,
            .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)
        ]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = textColor
        
        // Additional configuration for NavigationSplitView compatibility
        navAppearance.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: textColor]
        navAppearance.doneButtonAppearance.normal.titleTextAttributes = [.foregroundColor: textColor]
        navAppearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: textColor]
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = theme[uicolor: "tabBarBackgroundColor"]
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    
    
    
    private func checkPrivateMessagePrivileges() {
        // Check if user can send private messages and update settings
        SettingsManager.shared.canSendPrivateMessages = true // Simplified for now
    }
    
    private func configureSidebarNavigationBar() {
        // Create compact navigation bar appearance for sidebar
        let compactAppearance = UINavigationBarAppearance()
        compactAppearance.configureWithOpaqueBackground()
        compactAppearance.backgroundColor = theme[uicolor: "navigationBarTintColor"] ?? UIColor.systemBackground
        compactAppearance.shadowColor = theme[uicolor: "bottomBarTopBorderColor"]
        
        let textColor = theme[uicolor: "navigationBarTextColor"] ?? UIColor.label
        
        // Reduce title font size and margins for compactness (50% height reduction)
        compactAppearance.titleTextAttributes = [
            .foregroundColor: textColor,
            .font: UIFont.systemFont(ofSize: 14, weight: .medium)
        ]
        
        // Configure button appearances
        compactAppearance.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: textColor]
        compactAppearance.doneButtonAppearance.normal.titleTextAttributes = [.foregroundColor: textColor]
        compactAppearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: textColor]
        
        // Apply to sidebar navigation bar
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let splitViewController = window.rootViewController as? UISplitViewController,
                  let sidebarNavController = splitViewController.viewController(for: .primary) as? UINavigationController else {
                return
            }
            
            sidebarNavController.navigationBar.compactAppearance = compactAppearance
            sidebarNavController.navigationBar.standardAppearance = compactAppearance
            sidebarNavController.navigationBar.scrollEdgeAppearance = compactAppearance
            
            // Make the navigation bar more compact by adjusting height
            sidebarNavController.navigationBar.prefersLargeTitles = false
            sidebarNavController.navigationBar.tintColor = textColor
            
            // Additional height reduction approach
            sidebarNavController.navigationBar.compactScrollEdgeAppearance = compactAppearance
        }
    }
}

// MARK: - Supporting Types

struct IdentifiableUser: Identifiable {
    let id = UUID()
    let user: User
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
    
    var tabBarImage: String? {
        switch self {
        case .forums: return "forum-list"
        case .bookmarks: return "bookmarks"
        case .messages: return "pm-icon"
        case .lepers: return "lepers"
        case .settings: return "cog"
        }
    }
    
    var selectedTabBarImage: String? {
        switch self {
        case .forums: return "forum-list-filled"
        case .bookmarks: return "bookmarks-filled"
        case .messages: return "pm-icon-filled"
        case .lepers: return "lepers-filled"
        case .settings: return "cog-filled"
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

struct TabContentView: View, Equatable {
    let tab: MainTab
    let coordinator: any MainCoordinator
    let isEditing: Bool
    @SwiftUI.Environment(\.settingsManager) private var settingsManager
    @SwiftUI.Environment(\.theme) private var theme
    
    static func == (lhs: TabContentView, rhs: TabContentView) -> Bool {
        return lhs.tab == rhs.tab && lhs.isEditing == rhs.isEditing
    }

    var body: some View {
        contentView
            .background(theme[color: "backgroundColor"]!)
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch tab {
        case .forums:
            if let managedObjectContext = AppDelegate.instance?.managedObjectContext {
                SwiftUIForumsView(managedObjectContext: managedObjectContext, coordinator: coordinator, isEditing: isEditing)
            } else {
                Text("Error: Context not available").foregroundColor(.red)
            }
        case .bookmarks:
            if let managedObjectContext = AppDelegate.instance?.managedObjectContext {
                SwiftUIBookmarksView(managedObjectContext: managedObjectContext, coordinator: coordinator)
            } else {
                Text("Error: Context not available").foregroundColor(.red)
            }
        case .messages:
            if let managedObjectContext = AppDelegate.instance?.managedObjectContext {
                SwiftUIMessageListView(managedObjectContext: managedObjectContext, coordinator: coordinator)
            } else {
                Text("Error: Context not available").foregroundColor(.red)
            }
        case .lepers:
            VStack(spacing: 0) {
                NavigationHeaderView(title: "Leper's Colony")
                
                RapSheetViewWrapper(user: nil)
            }
        case .settings:
            if let managedObjectContext = AppDelegate.instance?.managedObjectContext {
                VStack(spacing: 0) {
                    NavigationHeaderView(title: "Settings")
                    
                    SettingsContainerView(
                        appIconDataSource: makeAppIconDataSource(),
                        currentUser: getCurrentUser(managedObjectContext: managedObjectContext),
                        emptyCache: { emptyCache() },
                        goToAwfulThread: { goToAwfulThread() },
                        hasRegularSizeClassInLandscape: UIDevice.current.userInterfaceIdiom == .pad || UIScreen.main.scale > 2,
                        isMac: ProcessInfo.processInfo.isMacCatalystApp,
                        isPad: UIDevice.current.userInterfaceIdiom == .pad,
                        logOut: { AppDelegate.instance.logOut() },
                        managedObjectContext: managedObjectContext
                    )
                }
            } else {
                Text("Error: Context not available").foregroundColor(.red)
            }
        }
    }
}

// MARK: - Tab Manager

class TabManager: ObservableObject {
    @Published var selectedTab: MainTab = .forums
    
    func selectTab(_ tab: MainTab) {
        selectedTab = tab
    }
}

// MARK: - Status Bar Style Manager

class StatusBarStyleManager: ObservableObject {
    static let shared = StatusBarStyleManager()
    
    func updateStyle(lightContent: Bool) {
        // Implementation for status bar style updates
    }
}

// MARK: - View Wrappers

struct SearchHostingControllerWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        // Return search controller
        return UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update if needed
    }
}

struct MessageComposeViewRepresentable: UIViewControllerRepresentable {
    let coordinator: MainCoordinatorImpl
    let isPresentedInSheet: Bool
    
    func makeUIViewController(context: Context) -> UIViewController {
        // Return compose controller
        return UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update if needed
    }
}

struct MessageComposeView: UIViewControllerRepresentable {
    let messageComposeViewController: MessageComposeViewController
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> MessageComposeViewController {
        return messageComposeViewController
    }
    
    func updateUIViewController(_ uiViewController: MessageComposeViewController, context: Context) {
        // Update if needed
    }
}

struct PostsViewWrapper: View {
    let thread: AwfulThread
    let page: ThreadPage
    let managedObjectContext: NSManagedObjectContext
    let coordinator: MainCoordinatorImpl
    
    var body: some View {
        SwiftUIPostsPageView(
            thread: thread,
            author: nil,
            page: page,
            coordinator: coordinator
        )
    }
}

struct RapSheetViewWrapper: UIViewControllerRepresentable {
    let user: User?
    
    func makeUIViewController(context: Context) -> RapSheetViewController {
        return RapSheetViewController(user: user)
    }
    
    func updateUIViewController(_ uiViewController: RapSheetViewController, context: Context) {
        // Update if needed
    }
}

// MARK: - Settings Support Functions

/// See the `README.md` section "Alternate App Icons" for more info.
private let appIcons: [AppIconDataSource.AppIcon] = [
    .init(accessibilityLabel: String(localized: "rated_five", bundle: .module), imageName: "rated_five"),
    .init(accessibilityLabel: String(localized: "rated_five_pride", bundle: .module), imageName: "rated_five_pride"),
    .init(accessibilityLabel: String(localized: "rated_five_trans", bundle: .module), imageName: "rated_five_trans"),
    .init(accessibilityLabel: String(localized: "v", bundle: .module), imageName: "v"),
    .init(accessibilityLabel: String(localized: "ghost_blue", bundle: .module), imageName: "ghost_blue"),
    .init(accessibilityLabel: String(localized: "froggo", bundle: .module), imageName: "froggo"),
    .init(accessibilityLabel: String(localized: "froggo_purple", bundle: .module), imageName: "froggo_purple"),
    .init(accessibilityLabel: String(localized: "staredog", bundle: .module), imageName: "staredog"),
    .init(accessibilityLabel: String(localized: "staredog_tongue", bundle: .module), imageName: "staredog_tongue"),
    .init(accessibilityLabel: String(localized: "five", bundle: .module), imageName: "five"),
    .init(accessibilityLabel: String(localized: "greenface", bundle: .module), imageName: "greenface"),
    .init(accessibilityLabel: String(localized: "riker", bundle: .module), imageName: "riker"),
    .init(accessibilityLabel: String(localized: "smith", bundle: .module), imageName: "smith"),
]

@MainActor private func makeAppIconDataSource() -> AppIconDataSource {
    let selectedIconName = UIApplication.shared.alternateIconName
    let selected = appIcons.first { "\($0.imageName)_appicon" == selectedIconName } ?? appIcons.first!
    return AppIconDataSource(
        appIcons: appIcons,
        imageLoader: { Image("\($0.imageName)_appicon_preview", bundle: .main) },
        selected: selected,
        setter: {
            let iconName = $0 == appIcons.first ? nil : "\($0.imageName)_appicon"
            try await UIApplication.shared.setAlternateIconName(iconName)
        }
    )
}

private func getCurrentUser(managedObjectContext: NSManagedObjectContext) -> User? {
    managedObjectContext.performAndWait {
        guard let userID = UserDefaults.standard.value(for: Settings.userID) else {
            return nil
        }
        return User.objectForKey(objectKey: UserKey(
            userID: userID,
            username: UserDefaults.standard.value(for: Settings.username)
        ), in: managedObjectContext)
    }
}

private func emptyCache() {
    let usageBefore = Measurement(value: Double(URLCache.shared.currentDiskUsage), unit: UnitInformationStorage.bytes)
    AppDelegate.instance.emptyCache()
    let usageAfter = Measurement(value: Double(URLCache.shared.currentDiskUsage), unit: UnitInformationStorage.bytes)
    let delta = (usageBefore - usageAfter).converted(to: .megabytes)
    
    // For SwiftUI context, we could consider showing a toast or alert here
    // For now, just log the action
    logger.info("Cache cleared: \(delta.formatted())")
}

private func goToAwfulThread() {
    AppDelegate.instance.open(route: .threadPage(threadID: "3837546", page: .nextUnread, .seen))
}
