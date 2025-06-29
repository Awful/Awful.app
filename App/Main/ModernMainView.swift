import AwfulCore
import AwfulModelTypes
import AwfulSettings
import AwfulTheming
import SwiftUI
import Combine

// MARK: - Coordinator Protocol

protocol MainCoordinator: ObservableObject {
    var isDetailViewShowing: Bool { get set }
    var detailPath: NavigationPath { get set }
    var sidebarPath: NavigationPath { get set }
    func presentSearch()
    func handleEditAction(for tab: MainTab)
    func presentCompose(for tab: MainTab)
    func navigateToThread(_ thread: AwfulThread)
    func navigateToForum(_ forum: Forum)
    func navigateToPrivateMessage(_ message: PrivateMessage)
    func shouldHideTabBar(isInSidebar: Bool) -> Bool
}

// MARK: - Main Coordinator Implementation

class MainCoordinatorImpl: MainCoordinator, ComposeTextViewControllerDelegate {
    @Published var presentedSheet: PresentedSheet?
    @Published var isDetailViewShowing = false
    @Published var detailPath = NavigationPath()
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
        // Always navigate to thread in detail pane
        detailPath.append(thread)
        isDetailViewShowing = true
    }
    
    func navigateToForum(_ forum: Forum) {
        // Navigate to forum in sidebar (threads list)
        sidebarPath.append(forum)
        // Don't set isDetailViewShowing = true here, as we want to stay in sidebar
    }
    
    func navigateToPrivateMessage(_ message: PrivateMessage) {
        detailPath.append(message)
        isDetailViewShowing = true
    }
    
    func navigateToComposeMessage() {
        detailPath.append(ComposePrivateMessage())
        isDetailViewShowing = true
    }
    
    func shouldHideTabBar(isInSidebar: Bool) -> Bool {
        if isInSidebar {
            // On iPad sidebar, always show the tab bar
            return false
        } else {
            // On iPhone, hide the tab bar when showing detail view
            return isDetailViewShowing
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
            if detailPath.count > 0 {
                detailPath.removeLast() // pop from detail stack on iPad
            }
        }
    }
}

struct ModernMainView: View {
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: MainTab = .forums
    @State private var themeObserver: AnyCancellable?
    @StateObject private var coordinator = MainCoordinatorImpl()
    @State private var navigationTintColor = Color.blue // Initialize with default, update in onAppear
    @State private var isEditingBookmarks = false
    @State private var isEditingMessages = false
    @State private var isEditingForums = false
    @State private var hasFavoriteForums = false
    
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    
    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad: Use NavigationSplitView with CustomTabBarContainer in sidebar
            NavigationSplitView {
                NavigationStack(path: $coordinator.sidebarPath) {
                    CustomTabBarContainer(
                        coordinator: coordinator, 
                        isInSidebar: true, 
                        selectedTab: $selectedTab, 
                        isEditingBookmarks: isEditingBookmarks,
                        isEditingMessages: isEditingMessages,
                        isEditingForums: isEditingForums,
                        hasFavoriteForums: hasFavoriteForums
                    )
                        .navigationTitle(selectedTab.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItemGroup(placement: .navigationBarLeading) {
                                leadingToolbarItems(for: selectedTab, coordinator: coordinator)
                            }
                            ToolbarItemGroup(placement: .navigationBarTrailing) {
                                trailingToolbarItems(for: selectedTab, coordinator: coordinator)
                            }
                        }
                        .navigationDestination(for: Forum.self) { forum in
                            ThreadsViewRepresentable(forum: forum, coordinator: coordinator)
                        }
                }
            } detail: {
                NavigationStack(path: $coordinator.detailPath) {
                    DetailView(selectedTab: selectedTab, coordinator: coordinator)
                }
            }
            .tint(navigationTintColor)
            .onAppear {
                configureGlobalAppearance()
                observeThemeChanges()
                checkPrivateMessagePrivileges()
                checkFavoriteForums()
                updateNavigationTintColor()
            }
            .sheet(item: $coordinator.presentedSheet) { sheet in
                sheetContent(for: sheet)
            }
            .background(StatusBarStyleController())
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CanSendPrivateMessagesDidChange"))) { _ in
                // Use Task to avoid publishing changes during view updates
                Task { @MainActor in
                    // Force view refresh by updating a computed property dependency
                    checkPrivateMessagePrivileges()
                }
            }
        } else {
            // iPhone: Use custom tab bar implementation
            CustomTabBarContainer(
                coordinator: coordinator, 
                isInSidebar: false,
                isEditingBookmarks: false,
                isEditingMessages: false,
                isEditingForums: false,
                hasFavoriteForums: hasFavoriteForums
            )
                .tint(navigationTintColor)
                .onAppear {
                    configureGlobalAppearance()
                    observeThemeChanges()
                    checkPrivateMessagePrivileges()
                    checkFavoriteForums()
                    updateNavigationTintColor()
                }
                .background(StatusBarStyleController())
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CanSendPrivateMessagesDidChange"))) { _ in
                    // Use Task to avoid publishing changes during view updates
                    Task { @MainActor in
                        // Force view refresh by updating a computed property dependency
                        checkPrivateMessagePrivileges()
                    }
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
    private func leadingToolbarItems(for tab: MainTab, coordinator: any MainCoordinator) -> some View {
        switch tab {
        case .forums:
            if canSendPrivateMessages {
                Button("Search") {
                    coordinator.presentSearch()
                }
                .foregroundColor(navigationTintColor)
            }
        case .messages:
            Button(isEditingMessages ? "Done" : "Edit") {
                isEditingMessages.toggle()
            }
            .foregroundColor(navigationTintColor)
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func trailingToolbarItems(for tab: MainTab, coordinator: any MainCoordinator) -> some View {
        switch tab {
        case .forums:
            if hasFavoriteForums {
                Button(isEditingForums ? "Done" : "Edit") {
                    isEditingForums.toggle()
                }
                .foregroundColor(navigationTintColor)
            }
        case .bookmarks:
            Button(isEditingBookmarks ? "Done" : "Edit") {
                isEditingBookmarks.toggle()
            }
            .foregroundColor(navigationTintColor)
        case .messages:
            Button(action: { coordinator.presentCompose(for: tab) }) {
                Image("compose")
                    .renderingMode(.template)
            }
            .foregroundColor(navigationTintColor)
        default:
            EmptyView()
        }
    }
    
    private func observeThemeChanges() {
        // Observe theme changes via NotificationCenter
        themeObserver = NotificationCenter.default
            .publisher(for: Notification.Name("ThemeDidChange"))
            .sink { _ in
                // Use Task to avoid publishing changes during view updates
                Task { @MainActor in
                    configureGlobalAppearance()
                    updateNavigationTintColor()
                }
            }
    }
    
    private func updateNavigationTintColor() {
        let theme = Theme.defaultTheme()
        navigationTintColor = Color(theme[uicolor: "navigationBarTextColor"]!)
    }
    
    private func configureGlobalAppearance() {
        let theme = Theme.defaultTheme()
        
        // Configure navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = theme[uicolor: "navigationBarTintColor"]
        navAppearance.shadowColor = theme[uicolor: "navigationBarSeparatorColor"]
        
        let textColor = theme[uicolor: "navigationBarTextColor"]!
        navAppearance.titleTextAttributes = [
            .foregroundColor: textColor,
            .font: UIFont.preferredFontForTextStyle(.body, fontName: nil, sizeAdjustment: 0, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: textColor,
            .font: UIFont.preferredFontForTextStyle(.largeTitle, fontName: nil, sizeAdjustment: 0, weight: .semibold)
        ]
        
        // Configure back button to use arrow image instead of text
        navAppearance.setBackIndicatorImage(UIImage(named: "back"), transitionMaskImage: UIImage(named: "back"))
        navAppearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        navAppearance.backButtonAppearance.highlighted.titleTextAttributes = [.foregroundColor: UIColor.clear]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = textColor
        UINavigationBar.appearance().isTranslucent = false
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        if theme[bool: "tabBarIsTranslucent"] == true {
            tabBarAppearance.configureWithDefaultBackground()
        } else {
            tabBarAppearance.configureWithOpaqueBackground()
        }
        tabBarAppearance.backgroundColor = theme[uicolor: "tabBarBackgroundColor"]
        tabBarAppearance.shadowImage = nil
        tabBarAppearance.shadowColor = nil
        
        // Remove any top insets/padding from tab bar
        tabBarAppearance.stackedLayoutAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 10)
        tabBarAppearance.stackedLayoutAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 10)
        
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.selected.iconColor = theme[uicolor: "tabBarIconSelectedColor"]!
        itemAppearance.normal.iconColor = theme[uicolor: "tabBarIconNormalColor"]!
        
        // Handle tab bar labels based on theme setting
        if theme[bool: "showRootTabBarLabel"] == false {
            // Hide labels by making them transparent and adjusting icon position
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.clear]
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        } else {
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: theme[uicolor: "tabBarIconSelectedColor"]!]
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: theme[uicolor: "tabBarIconNormalColor"]!]
        }
        
        tabBarAppearance.inlineLayoutAppearance = itemAppearance
        tabBarAppearance.stackedLayoutAppearance = itemAppearance
        tabBarAppearance.compactInlineLayoutAppearance = itemAppearance
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = theme[uicolor: "tabBarIconSelectedColor"]
        UITabBar.appearance().isTranslucent = theme[bool: "tabBarIsTranslucent"] ?? true
        
        // Force update of existing tab bars and navigation bars using modern API
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                for view in window.subviews {
                    view.removeFromSuperview()
                    window.addSubview(view)
                }
            }
        }
    }
    
    private func checkPrivateMessagePrivileges() {
        // Only check if we're logged in and don't already have PM privileges
        guard ForumsClient.shared.isLoggedIn && !canSendPrivateMessages else { return }
        
        Task {
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
        // Check if there are any favorite forums
        let context = AppDelegate.instance.managedObjectContext
        let fetchRequest = ForumMetadata.makeFetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == YES", #keyPath(ForumMetadata.favorite))
        
        do {
            let count = try context.count(for: fetchRequest)
            hasFavoriteForums = count > 0
        } catch {
            print("⚠️ Failed to check favorite forums: \(error)")
            hasFavoriteForums = false
        }
    }
}

// MARK: - Custom Tab Bar Implementation

private struct CustomTabBarContainer: View {
    @State private var internalSelectedTab: MainTab = .forums
    @State private var isEditingBookmarksLocal = false // For iPhone editing state
    @State private var isEditingMessagesLocal = false // For iPhone editing state
    @State private var isEditingForumsLocal = false // For iPhone editing state
    @ObservedObject var coordinator: MainCoordinatorImpl
    @FoilDefaultStorage(Settings.canSendPrivateMessages) private var canSendPrivateMessages
    let isInSidebar: Bool
    let externalSelectedTab: Binding<MainTab>?
    let isEditingBookmarks: Bool
    let isEditingMessages: Bool
    let isEditingForums: Bool
    let hasFavoriteForums: Bool
    
    // Get the current selected tab value
    private var selectedTabValue: MainTab {
        externalSelectedTab?.wrappedValue ?? internalSelectedTab
    }
    
    // Create a binding that works with both internal and external state
    private var selectedTabBinding: Binding<MainTab> {
        if let external = externalSelectedTab {
            return external
        } else {
            return $internalSelectedTab
        }
    }
    
    init(coordinator: MainCoordinatorImpl, isInSidebar: Bool, selectedTab: Binding<MainTab>? = nil, isEditingBookmarks: Bool, isEditingMessages: Bool, isEditingForums: Bool, hasFavoriteForums: Bool) {
        self.coordinator = coordinator
        self.isInSidebar = isInSidebar
        self.externalSelectedTab = selectedTab
        self.isEditingBookmarks = isEditingBookmarks
        self.isEditingMessages = isEditingMessages
        self.isEditingForums = isEditingForums
        self.hasFavoriteForums = hasFavoriteForums
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(MainTab.allCases(canSendPrivateMessages: canSendPrivateMessages)) { tab in
                    if isInSidebar {
                        // iPad: Use shared navigation, no individual NavigationStack
                        TabContentView(tab: tab, coordinator: coordinator, isEditing: getEditingState(for: tab))
                            .opacity(selectedTabValue == tab ? 1 : 0)
                    } else {
                        // iPhone: Each tab has its own NavigationStack and toolbar
                        NavigationStack {
                            TabContentView(tab: tab, coordinator: coordinator, isEditing: getEditingStateLocal(for: tab))
                                .navigationTitle(tab.title)
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItemGroup(placement: .navigationBarLeading) {
                                        leadingToolbarItemsLocal(for: tab, coordinator: coordinator)
                                    }
                                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                                        trailingToolbarItemsLocal(for: tab, coordinator: coordinator)
                                    }
                                }
                        }
                        .opacity(selectedTabValue == tab ? 1 : 0)
                    }
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
    
    @ViewBuilder
    private func leadingToolbarItemsLocal(for tab: MainTab, coordinator: any MainCoordinator) -> some View {
        switch tab {
        case .forums:
            if canSendPrivateMessages {
                Button("Search") {
                    coordinator.presentSearch()
                }
            }
        case .messages:
            Button(isEditingMessagesLocal ? "Done" : "Edit") {
                isEditingMessagesLocal.toggle()
            }
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func trailingToolbarItemsLocal(for tab: MainTab, coordinator: any MainCoordinator) -> some View {
        switch tab {
        case .forums:
            if hasFavoriteForums {
                Button(isEditingForumsLocal ? "Done" : "Edit") {
                    isEditingForumsLocal.toggle()
                }
            }
        case .bookmarks:
            Button(isEditingBookmarksLocal ? "Done" : "Edit") {
                isEditingBookmarksLocal.toggle()
            }
        case .messages:
            Button(action: { coordinator.presentCompose(for: tab) }) {
                Image("compose")
                    .renderingMode(.template)
            }
        default:
            EmptyView()
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
    
    private func getEditingStateLocal(for tab: MainTab) -> Bool {
        switch tab {
        case .forums:
            return isEditingForumsLocal
        case .bookmarks:
            return isEditingBookmarksLocal
        case .messages:
            return isEditingMessagesLocal
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
                .foregroundColor(theme[color: "bottomBarTopBorderColor"] ?? .clear)
            
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

struct DetailView: View {
    let selectedTab: MainTab
    let coordinator: any MainCoordinator
    @SwiftUI.Environment(\.theme) private var theme
    
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
        .background(theme[color: "backgroundColor"]!)
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: AwfulThread.self) { thread in
            PostsViewRepresentable(thread: thread, coordinator: coordinator)
        }
        .navigationDestination(for: PrivateMessage.self) { message in
            MessageViewRepresentable(message: message, coordinator: coordinator)
        }
        .navigationDestination(for: ComposePrivateMessage.self) { _ in
            if let coordinator = coordinator as? MainCoordinatorImpl {
                MessageComposeDetailView(coordinator: coordinator)
            } else {
                EmptyView()
            }
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
        wrapper.setEditing(isEditing, animated: true)
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

struct PostsViewRepresentable: UIViewControllerRepresentable {
    let thread: AwfulThread
    let coordinator: any MainCoordinator

    func makeUIViewController(context: Context) -> UIViewController {
        let postsVC = PostsPageViewController(thread: thread)
        // Load the appropriate page when the view controller is created
        let targetPage = thread.beenSeen ? ThreadPage.nextUnread : .first
        postsVC.loadPage(targetPage, updatingCache: true, updatingLastReadPost: true)
        let wrapper = SwiftUICompatibleViewController(wrapping: postsVC)
        wrapper.restorationIdentifier = "Posts"
        return wrapper
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Theme changes are handled automatically by the wrapper's observer
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

struct StatusBarStyleController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> StatusBarStyleControllerViewController {
        StatusBarStyleControllerViewController()
    }
    
    func updateUIViewController(_ uiViewController: StatusBarStyleControllerViewController, context: Context) {
        uiViewController.updateStatusBarStyle()
    }
}

class StatusBarStyleControllerViewController: UIViewController {
    private var isDarkContentBackground = false
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return isDarkContentBackground ? .lightContent : .darkContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateStatusBarStyle()
    }
    
    func updateStatusBarStyle() {
        let theme = Theme.defaultTheme()
        let statusBarBackground = theme[string: "statusBarBackground"] ?? "dark"
        
        isDarkContentBackground = statusBarBackground == "dark"
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
        Task { @MainActor [weak self] in
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
        super.setEditing(editing, animated: animated)
        wrappedViewController.setEditing(editing, animated: animated)
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
        let theme = Theme.defaultTheme()
        navigationTintColor = Color(theme[uicolor: "navigationBarTextColor"]!)
    }
}
