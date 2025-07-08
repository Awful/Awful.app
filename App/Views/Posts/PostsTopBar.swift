import SwiftUI
import AwfulCore
import AwfulTheming
import AwfulSettings

/// SwiftUI replacement for PostsPageTopBar
struct PostsTopBar: View {
    // MARK: - Properties
    let onParentForumTapped: (() -> Void)?
    let onPreviousPostsTapped: (() -> Void)?
    let onScrollToEndTapped: (() -> Void)?
    let isVisible: Bool
    
    // MARK: - Environment and Settings
    @SwiftUI.Environment(\.theme) private var theme
    @FoilDefaultStorage(Settings.enableHaptics) private var enableHaptics
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Parent Forum Button
                Button(action: {
                    if enableHaptics {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    onParentForumTapped?()
                }) {
                    Text(LocalizedString("posts-page.parent-forum-button.title"))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(buttonTextColor)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(buttonBackgroundColor)
                        .contentShape(Rectangle())
                }
                .disabled(onParentForumTapped == nil)
                .accessibilityLabel(LocalizedString("posts-page.parent-forum-button.accessibility-label"))
                .accessibilityHint(LocalizedString("posts-page.parent-forum-button.accessibility-hint"))
                
                // Separator
                Rectangle()
                    .fill(separatorColor)
                    .frame(width: separatorWidth)
                
                // Previous Posts Button
                Button(action: {
                    if enableHaptics {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    onPreviousPostsTapped?()
                }) {
                    Text(LocalizedString("posts-page.previous-posts-button.title"))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(buttonTextColor)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(buttonBackgroundColor)
                        .contentShape(Rectangle())
                }
                .disabled(onPreviousPostsTapped == nil)
                .accessibilityLabel(LocalizedString("posts-page.previous-posts-button.accessibility-label"))
                
                // Separator
                Rectangle()
                    .fill(separatorColor)
                    .frame(width: separatorWidth)
                
                // Scroll to End Button
                Button(action: {
                    if enableHaptics {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    onScrollToEndTapped?()
                }) {
                    Text(LocalizedString("posts-page.scroll-to-end-button.title"))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(buttonTextColor)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(buttonBackgroundColor)
                        .contentShape(Rectangle())
                }
                .disabled(onScrollToEndTapped == nil)
                .accessibilityLabel(LocalizedString("posts-page.scroll-to-end-button.accessibility-label"))
            }
            .background(topBarBackgroundColor)
            
            // Bottom border
            Rectangle()
                .fill(bottomBorderColor)
                .frame(height: separatorWidth)
        }
        .frame(height: 44)
    }
    
    // MARK: - Computed Properties
    private var topBarBackgroundColor: Color {
        theme[color: "postsTopBarBackgroundColor"] ?? Color(.systemBackground)
    }
    
    private var buttonBackgroundColor: Color {
        theme[color: "postsTopBarBackgroundColor"] ?? Color(.systemBackground)
    }
    
    private var buttonTextColor: Color {
        theme[color: "postsTopBarTextColor"] ?? Color(.label)
    }
    
    private var bottomBorderColor: Color {
        theme[color: "topBarBottomBorderColor"] ?? Color(.separator)
    }
    
    private var separatorColor: Color {
        bottomBorderColor
    }
    
    private var separatorWidth: CGFloat {
        1.0 / max(UIScreen.main.scale, 1.0)
    }
}

// MARK: - Preview
#Preview {
    PostsTopBar(
        onParentForumTapped: {},
        onPreviousPostsTapped: {},
        onScrollToEndTapped: {},
        isVisible: true
    )
    .environment(\.theme, Theme.defaultTheme())
} 