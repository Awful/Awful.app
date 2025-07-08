import SwiftUI
import AwfulCore
import AwfulTheming
import AwfulSettings

/// SwiftUI replacement for the thread actions menu
struct PostsActionsMenu: View {
    let thread: AwfulThread
    let author: User?
    
    let onBookmarkTapped: () -> Void
    let onCopyLinkTapped: () -> Void
    let onVoteTapped: () -> Void
    let onYourPostsTapped: () -> Void
    
    @SwiftUI.Environment(\.theme) private var theme
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    
    var body: some View {
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
    
    private var toolbarTextColor: Color {
        Color(theme[uicolor: "toolbarTextColor"] ?? UIColor.systemBlue)
    }
}

/// Standalone actions menu button for use in toolbars
struct PostsActionsMenuButton: View {
    let thread: AwfulThread
    let author: User?
    
    let onBookmarkTapped: () -> Void
    let onCopyLinkTapped: () -> Void
    let onVoteTapped: () -> Void
    let onYourPostsTapped: () -> Void
    
    @SwiftUI.Environment(\.theme) private var theme
    
    var body: some View {
        PostsActionsMenu(
            thread: thread,
            author: author,
            onBookmarkTapped: onBookmarkTapped,
            onCopyLinkTapped: onCopyLinkTapped,
            onVoteTapped: onVoteTapped,
            onYourPostsTapped: onYourPostsTapped
        )
    }
}

#Preview {
    let thread = AwfulThread()
    thread.title = "Sample Thread"
    thread.bookmarked = false
    
    return HStack {
        PostsActionsMenu(
            thread: thread,
            author: nil,
            onBookmarkTapped: { print("Bookmark tapped") },
            onCopyLinkTapped: { print("Copy link tapped") },
            onVoteTapped: { print("Vote tapped") },
            onYourPostsTapped: { print("Your posts tapped") }
        )
        
        Spacer()
        
        // Show bookmarked state
        PostsActionsMenu(
            thread: {
                let bookmarkedThread = AwfulThread()
                bookmarkedThread.title = "Bookmarked Thread"
                bookmarkedThread.bookmarked = true
                return bookmarkedThread
            }(),
            author: nil,
            onBookmarkTapped: { print("Remove bookmark tapped") },
            onCopyLinkTapped: { print("Copy link tapped") },
            onVoteTapped: { print("Vote tapped") },
            onYourPostsTapped: { print("Your posts tapped") }
        )
    }
    .padding()
    .environment(\.theme, Theme.defaultTheme())
} 
