import AwfulCore
import AwfulExtensions
import AwfulModelTypes
import AwfulSettings
import AwfulTheming
import SwiftUI
import Combine
import CoreData

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
}

// MARK: - Main Coordinator Implementation

class MainCoordinatorImpl: MainCoordinator, ComposeTextViewControllerDelegate {
    @Published var presentedSheet: PresentedSheet?
    @Published var isTabBarHidden = false
    @Published var path = NavigationPath()
    @Published var sidebarPath = NavigationPath()
    
    // Keep a reference to the current compose view controller for triggering actions
    private weak var currentComposeViewController: ComposeTextViewController?
    
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
        path.append(message)
        isTabBarHidden = true
    }
    
    func navigateToComposeMessage() {
        path.append(ComposePrivateMessage())
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
}

struct MainView: View {
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @SwiftUI.Environment(\.theme) private var theme
    @State private var selectedTab: MainTab = .forums
    @State private var themeObserver: AnyCancellable?
    @StateObject private var coordinator = MainCoordinatorImpl()
    @State private var isEditingBookmarks = false
    @State private var isEditingMessages = false
    @State private var isEditingForums = false
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
            AppDelegate.instance.mainCoordinator = coordinator
            configureGlobalAppearance(theme: theme)
            updateStatusBarStyle(theme: theme)
            observeThemeChanges()
            checkPrivateMessagePrivileges()
            checkFavoriteForums()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ThemeDidChange"))) { _ in
            configureGlobalAppearance(theme: theme)
            updateStatusBarStyle(theme: theme)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CanSendPrivateMessagesDidChange"))) { _ in
            checkPrivateMessagePrivileges()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("FavoriteForumsCountDidChange"))) { notification in
            if let count = notification.userInfo?["count"] as? Int {
                hasFavoriteForums = count > 0
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
    
    private func observeThemeChanges() {
        // Observe theme changes via NotificationCenter
        themeObserver = NotificationCenter.default
            .publisher(for: Notification.Name("ThemeDidChange"))
            .sink { _ in
                // The onReceive on the main view body will handle the update.
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
        let context = AppDelegate.instance.managedObjectContext
        
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
                let _ = print("🔵 DetailView: navigationDestination triggered for thread: \(destination.thread.title ?? "Unknown")")
                PostsViewWrapper(
                    thread: destination.thread,
                    author: destination.author,
                    page: destination.page,
                    coordinator: coordinator
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
        let forumsVC = ForumsTableViewController(managedObjectContext: AppDelegate.instance.managedObjectContext)
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
        let bookmarksVC = BookmarksTableViewController(managedObjectContext: AppDelegate.instance.managedObjectContext)
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
    
    init(thread: AwfulThread, page: ThreadPage, author: User?) {
        self.thread = thread
        self.page = page
        self.author = author
        print("🔵 ThreadDestination: Created for thread: \(thread.title ?? "Unknown"), page: \(page)")
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(thread)
        hasher.combine(page)
        hasher.combine(author)
    }
    
    static func == (lhs: ThreadDestination, rhs: ThreadDestination) -> Bool {
        return lhs.thread == rhs.thread &&
               lhs.page == rhs.page &&
               lhs.author == rhs.author
    }
}

struct MessagesViewRepresentable: UIViewControllerRepresentable {
    var isEditing: Bool
    let coordinator: any MainCoordinator

    func makeUIViewController(context: Context) -> UIViewController {
        let messagesVC = MessageListViewController(managedObjectContext: AppDelegate.instance.managedObjectContext)
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
        let settingsVC = SettingsViewController(managedObjectContext: AppDelegate.instance.managedObjectContext)
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
    var coordinator: (any MainCoordinator)?
    @StateObject private var viewModel = PostsViewModel()
    @SwiftUI.Environment(\.theme) private var theme
    @State private var title: String
    @FoilDefaultStorage(Settings.useSwiftUIPostsView) private var useSwiftUIPostsView
    
    private var navigationTintColor: Color {
        Color(theme[uicolor: "navigationBarTextColor"] ?? UIColor.label)
    }
    
    init(thread: AwfulThread, author: User?, page: ThreadPage, coordinator: (any MainCoordinator)?) {
        self.thread = thread
        self.author = author
        self.page = page
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
                    coordinator: coordinator
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
        
        // Update the status bar style by creating a custom view controller wrapper
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    // Check if we already have our custom wrapper
                    if let statusBarController = window.rootViewController as? StatusBarStyleViewController {
                        statusBarController.updateStatusBarStyle(lightContent: lightContent)
                    } else if let rootViewController = window.rootViewController {
                        // Replace the root view controller with our wrapper
                        let statusBarController = StatusBarStyleViewController(wrapping: rootViewController)
                        statusBarController.updateStatusBarStyle(lightContent: lightContent)
                        window.rootViewController = statusBarController
                    }
                }
            }
        }
    }
}

class StatusBarStyleViewController: UIViewController {
    private var shouldUseLightContent = false
    private let wrappedViewController: UIViewController
    
    init(wrapping viewController: UIViewController) {
        self.wrappedViewController = viewController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return shouldUseLightContent ? .lightContent : .darkContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add the wrapped view controller as a child
        addChild(wrappedViewController)
        view.addSubview(wrappedViewController.view)
        wrappedViewController.view.frame = view.bounds
        wrappedViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wrappedViewController.didMove(toParent: self)
        
        // Set initial status bar style based on current theme
        let theme = Theme.defaultTheme()
        let statusBarBackground = theme[string: "statusBarBackground"] ?? "dark"
        updateStatusBarStyle(lightContent: statusBarBackground == "dark")
    }
    
    func updateStatusBarStyle(lightContent: Bool) {
        shouldUseLightContent = lightContent
        setNeedsStatusBarAppearanceUpdate()
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
        
        // Set up observer for theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: Notification.Name("ThemeDidChange"),
            object: nil
        )
        
        // Initial background setup
        wrappedViewController.maintainSwiftUICompatibleBackground()
    }
    
    @objc private func themeDidChange() {
        // Call the wrapped view controller's theme change method
        if let themeable = wrappedViewController as? Themeable {
            themeable.themeDidChange()
        }
        
        // Then override with clear backgrounds to maintain SwiftUI compatibility
        Task<Void, Never>.detached(priority: .userInitiated) { @MainActor [weak self] in
            self?.wrappedViewController.maintainSwiftUICompatibleBackground()
        }
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
                    coordinator: coordinator
                )
            }
        }
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
        let context = AppDelegate.instance.managedObjectContext
        
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
