import SwiftUI
import AwfulCore
import AwfulSettings
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CustomAwfulNavigation")

/// Custom navigation system specifically for Awful app navigation flows
@MainActor
class AwfulNavigationController: ObservableObject {
    @Published private(set) var navigationStack: [AwfulNavigationDestination] = [.forumsList]
    @Published private(set) var currentIndex: Int = 0
    
    /// Navigate to a forum (threads list)
    func navigateToForum(_ forum: Forum) {
        logger.info("📍 Navigating to forum: \(forum.name ?? "Unknown")")
        withAnimation(.easeInOut(duration: 0.3)) {
            clearForwardHistory()
            let destination = AwfulNavigationDestination.forum(forum)
            self.navigationStack.append(destination)
            self.currentIndex = self.navigationStack.count - 1
        }
    }
    
    /// Navigate to a thread (posts view)
    func navigateToThread(_ thread: AwfulThread, page: ThreadPage = .nextUnread) {
        logger.info("📍 Navigating to thread: \(thread.title ?? "Unknown")")
        withAnimation(.easeInOut(duration: 0.3)) {
            clearForwardHistory()
            let destination = AwfulNavigationDestination.thread(ThreadDestination(
                thread: thread,
                page: page,
                author: nil,
                scrollFraction: nil,
                jumpToPostID: nil
            ))
            self.navigationStack.append(destination)
            self.currentIndex = self.navigationStack.count - 1
        }
    }
    
    /// Go back one step
    func goBack() -> Bool {
        guard self.currentIndex > 0 else {
            logger.info("📍 Cannot go back - already at root")
            return false
        }
        logger.info("📍 Going back from index \(self.currentIndex) to \(self.currentIndex - 1)")
        withAnimation(.easeInOut(duration: 0.3)) {
            self.currentIndex -= 1
        }
        return true
    }
    
    /// Go forward one step (unpop)
    func goForward() -> Bool {
        guard self.currentIndex < self.navigationStack.count - 1 else {
            logger.info("📍 Cannot go forward - no forward history")
            return false
        }
        logger.info("📍 Going forward from index \(self.currentIndex) to \(self.currentIndex + 1)")
        self.currentIndex += 1
        return true
    }
    
    /// Clear forward history when navigating to a new destination
    private func clearForwardHistory() {
        let originalCount = self.navigationStack.count
        self.navigationStack = Array(self.navigationStack.prefix(self.currentIndex + 1))
        if self.navigationStack.count != originalCount {
            logger.info("📍 Cleared forward history, stack reduced from \(originalCount) to \(self.navigationStack.count)")
        }
    }
    
    /// Get current destination
    var currentDestination: AwfulNavigationDestination? {
        guard self.currentIndex >= 0 && self.currentIndex < self.navigationStack.count else { return nil }
        return self.navigationStack[self.currentIndex]
    }
    
    /// Navigation state properties
    var canGoBack: Bool { self.currentIndex > 0 }
    var canGoForward: Bool { self.currentIndex < self.navigationStack.count - 1 }
    var isAtRoot: Bool { self.currentIndex == 0 }
    
    /// Reset to root (forums list)
    func resetToRoot() {
        logger.info("📍 Resetting to root")
        withAnimation(.easeInOut(duration: 0.3)) {
            self.navigationStack = [.forumsList]
            self.currentIndex = 0
        }
    }
}

/// Navigation destinations for the Awful app
enum AwfulNavigationDestination: Hashable, Identifiable {
    case forumsList
    case forum(Forum)
    case thread(ThreadDestination)
    
    var id: String {
        switch self {
        case .forumsList:
            return "forums-list"
        case .forum(let forum):
            return "forum-\(forum.forumID)"
        case .thread(let threadDest):
            return "thread-\(threadDest.thread.threadID)-\(threadDest.page)"
        }
    }
}

/// Main navigation view that handles the custom stack
struct AwfulNavigationView: View {
    @StateObject private var navigationController = AwfulNavigationController()
    @SwiftUI.Environment(\.horizontalSizeClass) var horizontalSizeClass
    let coordinator: (any MainCoordinator)?
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad: Use split view
                iPadNavigationView()
            } else {
                // iPhone: Use custom stack navigation
                iPhoneNavigationView()
            }
        }
        .environmentObject(navigationController)
    }
    
    @ViewBuilder
    private func iPadNavigationView() -> some View {
        NavigationSplitView {
            SwiftUIForumsView(managedObjectContext: AppDelegate.instance.managedObjectContext)
        } detail: {
            if let destination = navigationController.currentDestination {
                destinationView(for: destination)
            } else {
                Text("Select a forum")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            // Initialize with forums as root
            // navigationController.resetToRoot()
        }
    }
    
    @ViewBuilder
    private func iPhoneNavigationView() -> some View {
        ZStack {
            // Current view based on navigation state
            if let destination = navigationController.currentDestination {
                destinationView(for: destination)
            } else {
                // Root view - Forums
                SwiftUIForumsView(managedObjectContext: AppDelegate.instance.managedObjectContext)
            }
        }
        .gesture(
            // Custom swipe gestures for navigation
            DragGesture()
                .onEnded { value in
                    handleNavigationSwipe(value)
                }
        )
        .animation(.easeInOut(duration: 0.3), value: navigationController.currentIndex)
    }
    
    @ViewBuilder
    private func destinationView(for destination: AwfulNavigationDestination) -> some View {
        switch destination {
        case .forumsList:
            SwiftUIForumsView(managedObjectContext: AppDelegate.instance.managedObjectContext)
        case .forum(let forum):
            Group {
                if let coordinator = coordinator {
                    SwiftUIThreadsView(forum: forum, managedObjectContext: AppDelegate.instance.managedObjectContext, coordinator: coordinator)
                } else {
                    Text("Loading...")
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            
        case .thread(let threadDest):
            Group {
                if let coordinator = coordinator {
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
                } else {
                    Text("Loading...")
                }
            }
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
            if navigationController.canGoBack {
                logger.info("🔄 Swipe back gesture detected")
                _ = navigationController.goBack()
            }
        } else if value.translation.width < -threshold && value.velocity.width < -velocityThreshold {
            // Swipe left - go forward (unpop)
            if navigationController.canGoForward {
                logger.info("🔄 Swipe forward gesture detected")
                _ = navigationController.goForward()
            }
        }
    }
}

