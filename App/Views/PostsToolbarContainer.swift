import SwiftUI
import AwfulCore
import AwfulTheming
import AwfulSettings
import UIKit

/// Complete SwiftUI replacement for the posts view toolbar with all functionality
struct PostsToolbarContainer: View {
    // MARK: - Properties
    let thread: AwfulThread
    let author: User?
    let page: ThreadPage?
    let numberOfPages: Int
    let isLoadingViewVisible: Bool
    
    // MARK: - Action Callbacks
    let onSettingsTapped: () -> Void
    let onBackTapped: () -> Void
    let onForwardTapped: () -> Void
    let onPageSelected: (ThreadPage) -> Void
    let onGoToLastPost: () -> Void
    let onBookmarkTapped: () -> Void
    let onCopyLinkTapped: () -> Void
    let onVoteTapped: () -> Void
    let onYourPostsTapped: () -> Void
    
    // MARK: - State
    @SwiftUI.Environment(\.theme) private var theme
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    @State private var showingPagePicker = false
    
    // MARK: - Computed Properties
    private var currentPageNumber: Int {
        if case .specific(let pageNumber) = page {
            return pageNumber
        }
        return 1
    }
    
    private var currentPageText: String {
        if case .specific(let pageNumber) = page, numberOfPages > 0 {
            return "\(pageNumber) / \(numberOfPages)"
        } else {
            return ""
        }
    }
    
    private var isBackEnabled: Bool {
        switch page {
        case .specific(let pageNumber)?:
            return pageNumber > 1
        case .last?, .nextUnread?, nil:
            return false
        }
    }
    
    private var isForwardEnabled: Bool {
        switch page {
        case .specific(let pageNumber)?:
            return pageNumber < numberOfPages
        case .last?, .nextUnread?, nil:
            return false
        }
    }
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 0) {
            // Settings button
            Button(action: {
                if enableHaptics {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                onSettingsTapped()
            }) {
                Image("page-settings")
                    .renderingMode(.template)
                    .foregroundColor(toolbarTextColor)
            }
            .accessibilityLabel("Settings")
            
            Spacer()
            
            // Navigation controls
            HStack(spacing: 12) {
                // Back button
                Button(action: {
                    if enableHaptics {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    onBackTapped()
                }) {
                    Image("arrowleft")
                        .renderingMode(.template)
                        .foregroundColor(isBackEnabled ? toolbarTextColor : disabledToolbarTextColor)
                }
                .disabled(!isBackEnabled)
                .accessibilityLabel("Previous page")
                
                // Current page picker
                Button(action: {
                    // Only block if we have no page information yet
                    guard numberOfPages > 0 else { return }
                    if enableHaptics {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    showingPagePicker = true
                }) {
                    PageNumberView(page: page, numberOfPages: numberOfPages)
                        .foregroundColor(toolbarTextColor)
                        .frame(minWidth: 60)
                }
                .disabled(numberOfPages <= 0)
                .accessibilityLabel(currentPageAccessibilityLabel)
                .accessibilityHint("Opens page picker")
                .popover(isPresented: $showingPagePicker) {
                    if #available(iOS 16.4, *) {
                        PostsPagePicker(
                            thread: thread,
                            numberOfPages: numberOfPages,
                            currentPage: currentPageNumber,
                            onPageSelected: onPageSelected,
                            onGoToLastPost: onGoToLastPost
                        )
                        .presentationCompactAdaptation(.popover)
                    } else {
                        PostsPagePicker(
                            thread: thread,
                            numberOfPages: numberOfPages,
                            currentPage: currentPageNumber,
                            onPageSelected: onPageSelected,
                            onGoToLastPost: onGoToLastPost
                        )
                    }
                }
                
                // Forward button
                Button(action: {
                    if enableHaptics {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    onForwardTapped()
                }) {
                    Image("arrowright")
                        .renderingMode(.template)
                        .foregroundColor(isForwardEnabled ? toolbarTextColor : disabledToolbarTextColor)
                }
                .disabled(!isForwardEnabled)
                .accessibilityLabel("Next page")
            }
            
            Spacer()
            
            // Actions/hamburger menu
            Menu {
                // Bookmark
                Button(action: {
                    if enableHaptics {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    onBookmarkTapped()
                }) {
                    Label(
                        thread.bookmarked ? "Remove Bookmark" : "Bookmark Thread",
                        image: thread.bookmarked ? "remove-bookmark" : "add-bookmark"
                    )
                }
                .foregroundColor(thread.bookmarked ? .red : .primary)
                
                // Copy link
                Button(action: {
                    if enableHaptics {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    onCopyLinkTapped()
                }) {
                    Label("Copy link", image: "copy-url")
                }
                
                // Vote
                Button(action: {
                    if enableHaptics {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    onVoteTapped()
                }) {
                    Label("Vote", image: "vote")
                }
                
                // Your posts
                Button(action: {
                    if enableHaptics {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    onYourPostsTapped()
                }) {
                    Label("Your posts", image: "single-users-posts")
                }
            } label: {
                Image("steamed-ham")
                    .renderingMode(.template)
                    .foregroundColor(toolbarTextColor)
            }
            .accessibilityLabel("Menu")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 44) // Ensure minimum toolbar height
        .background(toolbarBackgroundColor, ignoresSafeAreaEdges: .bottom)
        .overlay(
            // Top border
            Rectangle()
                .fill(topBorderColor)
                .frame(height: 1.0 / UIScreen.main.scale)
                .frame(maxHeight: .infinity, alignment: .top)
        )
        .toolbarBackground(toolbarBackgroundColor, for: .bottomBar)
        .toolbarBackground(.visible, for: .bottomBar)
        .onReceive(NotificationCenter.default.publisher(for: .threadBookmarkDidChange)) { notification in
            // Force view refresh when bookmark state changes
            if let notificationThread = notification.object as? AwfulThread,
               notificationThread.objectID == thread.objectID {
                // The toolbar will automatically update since thread.bookmarked is observed
            }
        }
    }
    
    // MARK: - Helper Properties
    private var currentPageAccessibilityLabel: String {
        if case .specific(let pageNumber) = page, numberOfPages > 0 {
            return "Page \(pageNumber) of \(numberOfPages)"
        } else {
            return ""
        }
    }
    
    private var toolbarTextColor: Color {
        theme[color: "toolbarTextColor"] ?? .blue
    }
    
    private var disabledToolbarTextColor: Color {
        toolbarTextColor.opacity(0.5)
    }
    
    private var toolbarBackgroundColor: Color {
        theme[color: "tabBarBackgroundColor"] ?? Color(.systemBackground)
    }
    
    private var topBorderColor: Color {
        theme[color: "tabBarBackgroundColor"] ?? Color(.separator)
    }
}

// MARK: - Convenience Initializer
extension PostsToolbarContainer {
    /// Convenience initializer that takes a PostsPageViewController and extracts the necessary callbacks
    static func fromViewController(
        _ viewController: PostsPageViewController,
        isLoadingViewVisible: Bool = false
    ) -> PostsToolbarContainer {
        return PostsToolbarContainer(
            thread: viewController.thread,
            author: viewController.authorUser,
            page: viewController.page,
            numberOfPages: viewController.numberOfPages,
            isLoadingViewVisible: isLoadingViewVisible,
            onSettingsTapped: {
                viewController.triggerSettings()
            },
            onBackTapped: {
                guard case .specific(let pageNumber) = viewController.page, pageNumber > 1 else { return }
                viewController.loadPage(.specific(pageNumber - 1), updatingCache: true, updatingLastReadPost: true)
            },
            onForwardTapped: {
                guard case .specific(let pageNumber) = viewController.page, 
                      pageNumber < viewController.numberOfPages, 
                      pageNumber > 0 else { return }
                viewController.loadPage(.specific(pageNumber + 1), updatingCache: true, updatingLastReadPost: true)
            },
            onPageSelected: { page in
                viewController.loadPage(page, updatingCache: true, updatingLastReadPost: true)
            },
            onGoToLastPost: {
                viewController.goToLastPost()
            },
            onBookmarkTapped: {
                viewController.triggerBookmark()
            },
            onCopyLinkTapped: {
                viewController.triggerCopyLink()
            },
            onVoteTapped: {
                viewController.triggerVote()
            },
            onYourPostsTapped: {
                viewController.triggerYourPosts()
            }
        )
    }
}

// MARK: - Preview
#Preview {
    let thread = AwfulThread()
    thread.title = "Sample Thread"
    thread.bookmarked = false
    
    return PostsToolbarContainer(
        thread: thread,
        author: nil,
        page: .specific(5),
        numberOfPages: 10,
        isLoadingViewVisible: false,
        onSettingsTapped: { print("Settings tapped") },
        onBackTapped: { print("Back tapped") },
        onForwardTapped: { print("Forward tapped") },
        onPageSelected: { page in print("Page selected: \(page)") },
        onGoToLastPost: { print("Go to last post") },
        onBookmarkTapped: { print("Bookmark tapped") },
        onCopyLinkTapped: { print("Copy link tapped") },
        onVoteTapped: { print("Vote tapped") },
        onYourPostsTapped: { print("Your posts tapped") }
    )
    .environment(\.theme, Theme.defaultTheme())
}

// MARK: - Page Number View
private struct PageNumberView: View {
    let page: ThreadPage?
    let numberOfPages: Int
    @SwiftUI.Environment(\.theme) private var theme
    
    // Number formatter that doesn't use grouping separators (no commas)
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    var body: some View {
        if case .specific(let pageNumber) = page, numberOfPages > 0 {
            // Display page numbers side by side with "/" like in the mockup
            Text(formattedPageText(pageNumber, numberOfPages))
                .font(.body.weight(.medium))
        } else {
            // Fallback for non-specific pages or when total is unknown
            Text(currentPageText)
                .font(.body.weight(.medium))
        }
    }

    private var currentPageText: String {
        if case .specific(let pageNumber) = page, numberOfPages > 0 {
            return formattedPageText(pageNumber, numberOfPages)
        } else {
            return ""
        }
    }
    
    private func formattedPageText(_ pageNumber: Int, _ totalPages: Int) -> String {
        let pageStr = Self.numberFormatter.string(from: NSNumber(value: pageNumber)) ?? "\(pageNumber)"
        let totalStr = Self.numberFormatter.string(from: NSNumber(value: totalPages)) ?? "\(totalPages)"
        return "\(pageStr) / \(totalStr)"
    }
} 
