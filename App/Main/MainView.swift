import SwiftUI
import Combine
import AwfulCore
import AwfulTheming
import UIKit
import MRProgress

struct MainView: View {
    @State private var selectedTab: Tab = .forums
    @SwiftUI.Environment(\.theme) private var theme
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var routeObserver: NSObjectProtocol?
    
    private var fontDesign: Font.Design {
        theme[bool: "roundedFonts"] == true ? .rounded : .default
    }
    
    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }
    
    var body: some View {
        if sessionManager.isLoggedIn {
            loggedInView
        } else {
            LoginView()
        }
    }
    
    @ViewBuilder
    private var loggedInView: some View {
        Group {
            if isCompact {
                NavigationStack {
                    MainViewContent(selectedTab: $selectedTab)
                }
                .preferredColorScheme(theme["mode"] == "dark" ? .dark : .light)
                .fontDesign(fontDesign)
            } else {
                NavigationSplitView {
                    MainViewContent(selectedTab: $selectedTab)
                        .background(theme[color: "backgroundColor"] ?? Color(.systemGroupedBackground))
                } detail: {
                    Text("")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(theme[color: "backgroundColor"] ?? Color(.systemBackground))
                }
                .preferredColorScheme(theme["mode"] == "dark" ? .dark : .light)
                .fontDesign(fontDesign)
            }
        }
        .onAppear {
            setupRouteNotificationObserver()
        }
        .onDisappear {
            removeRouteNotificationObserver()
        }
    }
    
    private func setupRouteNotificationObserver() {
        routeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("AwfulRoute"),
            object: nil,
            queue: .main
        ) { notification in
            guard let route = notification.object as? AwfulRoute else { return }
            handleRoute(route)
        }
    }
    
    private func removeRouteNotificationObserver() {
        if let observer = routeObserver {
            NotificationCenter.default.removeObserver(observer)
            routeObserver = nil
        }
    }
    
    private func handleRoute(_ route: AwfulRoute) {
        // Handle routing for SwiftUI navigation system
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        switch route {
        case let .post(id: postID, updateSeen):
            handlePostRoute(postID: postID, updateSeen: updateSeen, window: window)
        default:
            // For other routes, fall back to the existing router
            let router = AwfulURLRouter(window: window)
            router.route(route)
        }
    }
    
    private func handlePostRoute(postID: String, updateSeen: AwfulRoute.UpdateSeen, window: UIWindow) {
        let managedObjectContext = AppDelegate.instance.managedObjectContext
        let key = PostKey(postID: postID)
        
        // Check if post already exists locally
        if let post = Post.existingObjectForKey(objectKey: key, in: managedObjectContext),
           let thread = post.thread,
           post.page > 0 {
            showPost(post: post, thread: thread, page: .specific(post.page), updateSeen: updateSeen, window: window)
            return
        }
        
        // Need to locate the post
        guard let rootView = window.rootViewController?.view else { return }
        guard let overlay = MRProgressOverlayView.showOverlayAdded(to: rootView, title: "Locating Post", mode: MRProgressOverlayViewMode.indeterminate, animated: true) else {
            return
        }
        overlay.tintColor = Theme.defaultTheme()["tintColor"]
        
        let updateLastRead = updateSeen == .seen
        
        Task { @MainActor in
            do {
                let (post, page) = try await ForumsClient.shared.locatePost(id: postID, updateLastReadPost: updateLastRead)
                overlay.dismiss(true) {
                    guard let thread = post.thread else { return }
                    self.showPost(post: post, thread: thread, page: page, updateSeen: updateSeen, window: window)
                }
            } catch {
                overlay.titleLabelText = "Post Not Found"
                overlay.mode = MRProgressOverlayViewMode.cross
                try? await Task.sleep(for: .seconds(3))
                overlay.dismiss(true)
            }
        }
    }
    
    private func showPost(post: Post, thread: AwfulThread, page: ThreadPage, updateSeen: AwfulRoute.UpdateSeen, window: UIWindow) {
        let postsVC = PostsPageViewController(thread: thread)
        let updateLastRead = updateSeen == .seen
        postsVC.loadPage(page, updatingCache: true, updatingLastReadPost: updateLastRead)
        postsVC.scrollPostToVisible(post)
        postsVC.restorationIdentifier = "Posts from URL"
        
        let navController = postsVC.enclosingNavigationController()
        postsVC.configureForDetailPresentation(navController)
        
        // Present if not already shown in detail pane
        if navController.parent == nil {
            window.rootViewController?.present(navController, animated: true)
        }
    }
    
    private func findSplitViewController(in viewController: UIViewController?) -> UISplitViewController? {
        guard let viewController = viewController else { return nil }
        
        if let splitVC = viewController as? UISplitViewController {
            return splitVC
        }
        
        // Check children
        for child in viewController.children {
            if let splitVC = findSplitViewController(in: child) {
                return splitVC
            }
        }
        
        // Check presented view controller
        if let presented = viewController.presentedViewController {
            return findSplitViewController(in: presented)
        }
        
        return nil
    }
}

private struct MainViewContent: View {
    @Binding var selectedTab: Tab
    @SwiftUI.Environment(\.theme) private var theme
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isBookmarksEditing = false
    @State private var isMessagesEditing = false
    @State private var isForumsEditing = false
    @State private var forumsHasFavorites = false
    
    private var isPad: Bool {
        horizontalSizeClass == .regular
    }

    private var navigationBarColorScheme: ColorScheme? {
        if theme["statusBarBackground"] == "light" {
            return .light
        } else if theme["statusBarBackground"] == "dark" {
            return .dark
        }
        return nil
    }

    private var showLabels: Bool {
        theme[bool: "showRootTabBarLabel"] != false
    }

    private var selectedColor: Color {
        theme[color: "tabBarIconSelectedColor"] ?? .blue
    }

    private var iconColor: Color {
        theme[color: "tabBarIconColor"] ?? .gray
    }

    private var textColor: Color {
        theme[color: "tabBarTextColor"] ?? .gray
    }

    private var backgroundColor: Color {
        theme[color: "tabBarBackgroundColor"] ?? Color(.systemBackground)
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .forums:
                    Tab.forums.view(
                        isPad: isPad,
                        forumsIsEditing: $isForumsEditing,
                        forumsHasFavorites: $forumsHasFavorites
                    )
                case .bookmarks:
                    Tab.bookmarks.view(
                        isPad: isPad,
                        bookmarksIsEditing: $isBookmarksEditing
                    )
                case .messages:
                    Tab.messages.view(
                        isPad: isPad,
                        messagesIsEditing: $isMessagesEditing
                    )
                case .lepers:
                    Tab.lepers.view(isPad: isPad)
                case .settings:
                    Tab.settings.view(isPad: isPad)
                }
            }

            VStack(spacing: 0) {
                Divider()
                    .background(Color.gray.opacity(0))

                HStack(spacing: 0) {
                    ForEach(Tab.allCases) { tab in
                        Button(action: { 
                            selectedTab = tab 
                        }) {
                            VStack(spacing: showLabels ? 4 : 0) {
                                Image(tab.image)
                                    .renderingMode(.template)
                                    .foregroundColor(selectedTab == tab ? selectedColor : iconColor)
                                    .font(.system(size: 20))
                                    .padding(.vertical, showLabels ? 0 : 9)

                                if showLabels {
                                    Text(tab.title)
                                        .font(.caption)
                                        .foregroundColor(selectedTab == tab ? selectedColor : textColor)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, showLabels ? 8 : 0)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .frame(height: 50)
                .background(backgroundColor)
                .allowsHitTesting(true)
            }
        }
        .background(theme[color: "navigationBarTintColor"])
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme[color: "navigationBarTintColor"] ?? .blue, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(navigationBarColorScheme, for: .navigationBar)
        .tint(theme[color: "navigationBarTextColor"])
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(selectedTab.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme[color: "navigationBarTextColor"])
            }
            
            if selectedTab == .forums && forumsHasFavorites {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isForumsEditing ? "Done" : "Edit") {
                        isForumsEditing.toggle()
                    }
                    .foregroundColor(theme[color: "navigationBarTextColor"])
                }
            }
            
            if selectedTab == .bookmarks {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isBookmarksEditing ? "Done" : "Edit") {
                        isBookmarksEditing.toggle()
                    }
                    .foregroundColor(theme[color: "navigationBarTextColor"])
                }
            }
            
            if selectedTab == .messages {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isMessagesEditing ? "Done" : "Edit") {
                        isMessagesEditing.toggle()
                    }
                    .foregroundColor(theme[color: "navigationBarTextColor"])
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // We need to present the compose view controller
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first,
                           let rootVC = window.rootViewController {
                            let compose = MessageComposeViewController()
                            compose.restorationIdentifier = "New message"
                            let navController = compose.enclosingNavigationController()
                            
                            compose.configureForDetailPresentation(navController)
                            
                            // Present if not already shown in detail pane
                            if navController.parent == nil {
                                rootVC.present(navController, animated: true)
                            }
                        }
                    }) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(theme[color: "navigationBarTextColor"])
                    }
                }
            }
        }
    }
}

#Preview {
    MainView()
}
